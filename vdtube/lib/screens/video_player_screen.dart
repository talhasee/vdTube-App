import 'dart:async';
import 'dart:convert';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vdtube/constants/constants.dart';
import 'package:vdtube/utils/widgets/comments.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:intl/intl.dart';

const BASE_URL = Constants.baseUrl;
var logger = Constants.logger;

class VideoPlayerScreen extends StatefulWidget {
  final String videoId;

  const VideoPlayerScreen({super.key, required this.videoId});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  // Secure storage Instance
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();

  // Video Player Controller
  late VideoPlayerController _videoPlayerController;
  late ChewieController _chewieController;

  late ConfettiController _confettiController;
  bool _isVideoInitialized = false;
  bool _isChewieInitialized = false; // Track if ChewieController is initialized
  bool _isDescriptionExpanded = false; //To manage description expansion
  Timer? debounce;
  String avatarUrl = "";
  String? username = "";
  String channelId =
      ""; //Its same as user ID but its of the user whose has uploaded the video
  bool subscribedStatus = false;
  int subscribersCount = 0;

  // Likes temporary Data storing locally
  bool isLiked = true;
  int likesCount = 0;

  @override
  void initState() {
    super.initState();
    // Initialize the confetti controller
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 1));
  }

  // Fetch Access Token
  Future<String?> getAccessToken() async {
    return await secureStorage.read(key: 'accessToken');
  }

  // Fetch Refresh Token
  Future<String?> getRefreshToken() async {
    return await secureStorage.read(key: 'refreshToken');
  }

  //Handle Liking
  void handleLike(bool isLiked) {
    //Cancle exisitng debounce timer
    debounce?.cancel();

    //Starting a new debouncing timer
    debounce = Timer(
        const Duration(milliseconds: 5000), () => sendLikeToServer(isLiked));

    if (mounted) {
      setState(() {
        this.isLiked = !isLiked;
        if (isLiked) {
          likesCount--;
        } else {
          likesCount++;
        }
        logger.d('isLiked - $isLiked.........likesCount - $likesCount');
      });
    }
  }

  //Toggle subscription
  Future<void> toggleSubscription(bool isSubscribed) async {
    String? accessToken = await getAccessToken();
    String? refreshToken = await getRefreshToken();

    var headers = {
      'Cookie': 'accessToken=$accessToken; refreshToken=$refreshToken',
    };

    final url = Uri.parse('$BASE_URL/subscriptions/ch/$channelId');

    try {
      final response = await http.post(url, headers: headers);

      if (response.statusCode == 200) {
        logger.d(
            'Successfully updated the subscribed status to ----$isSubscribed----');
      } else {
        logger.d(
            'Failed to updated the subscribed status to ----${response.reasonPhrase}----');
      }
    } catch (e) {
      logger.e('Error while updating subscribed status - $e');
    }
  }

  //Api Call to register the like
  Future<void> sendLikeToServer(bool isLiked) async {
    final url = '$BASE_URL/like/toggle/v/${widget.videoId}';

    String? accessToken = await getAccessToken();
    String? refreshToken = await getRefreshToken();

    var headers = {
      'Cookie': 'accessToken=$accessToken; refreshToken=$refreshToken',
    };

    try {
      final response = await http.post(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        logger.d('Successfully updated the like status to--- $isLiked----');
      } else {
        logger.d('Failed to update the like: ${response.reasonPhrase}');
      }
    } catch (e) {
      logger.d('Error sending the like to server: $e');
    }
  }

  Future<Map<String, dynamic>> fetchVideoDetails() async {
    final url = '$BASE_URL/video/v/${widget.videoId}';

    String? accessToken = await getAccessToken();
    String? refreshToken = await getRefreshToken();

    var headers = {
      'Cookie': 'accessToken=$accessToken; refreshToken=$refreshToken',
    };

    try {
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        logger.d("RESPONSE - ${response.body}");

        final responseData = json.decode(response.body);
        if (responseData['data'] is List && responseData['data'].isNotEmpty) {
          isLiked = responseData['data'][0]['isLiked'];
          likesCount = responseData['data'][0]['likesCount'];

          final owner = responseData['data'][0]['owner'];
          // if (mounted) {
          // setState(() {
          avatarUrl = owner['avatar'];
          username = owner['userName'];
          subscribersCount = owner['subscribersCount'];
          channelId = owner['_id'];
          subscribedStatus = owner['isSubscribed'];
          // });
          // }

          return responseData['data'][0]; // Return first video object
        } else {
          throw Exception('Invalid video data');
        }
      } else {
        throw Exception(
            'Failed to load video details: ${response.reasonPhrase}');
      }
    } catch (e) {
      throw Exception('Error fetching video details: $e');
    }
  }

  Future<void> initializeVideoPlayer(String videoUrl) async {
    if (!mounted)
      return; // Ensure widget is still mounted before making changes

    // Check if the URL starts with "http" and append "s" if needed to make it "https"
    if (videoUrl.startsWith('http://')) {
      videoUrl = 'https${videoUrl.substring(4)}';
      logger.d('VIDEO URL - $videoUrl');
    }

    _videoPlayerController =
        VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    await _videoPlayerController.initialize();

    if (!mounted)
      return; // Ensure widget is still mounted before calling setState

    if (mounted) {
      setState(() {
        _chewieController = ChewieController(
          videoPlayerController: _videoPlayerController,
          autoPlay: true,
          looping: false,
          allowFullScreen: true,
          allowMuting: true,
          allowPlaybackSpeedChanging: true,
          placeholder: Center(
            child: LoadingAnimationWidget.threeRotatingDots(
                color: Colors.red, size: 50),
          ),
          errorBuilder: (context, errorMessage) {
            return Center(
              child: Text('Error playing video: $errorMessage'),
            );
          },
        );
        _isVideoInitialized = true;
        _isChewieInitialized = true;
      });
    }
  }

  String formatDate(String dateStr) {
    DateTime date = DateTime.parse(dateStr);
    return DateFormat('yyyy-MM-dd').format(date); //Format Date
  }

  @override
  void dispose() {
    //Dispose the debounce timer
    debounce?.cancel();

    // Dispose the VideoPlayerController to free resources

    if (_isVideoInitialized) {
      _videoPlayerController.dispose();
    }
    if (_isChewieInitialized) {
      _chewieController.dispose();
    }
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Player'),
        backgroundColor: Colors.redAccent,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: fetchVideoDetails(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: LoadingAnimationWidget.threeRotatingDots(
                  color: Colors.red, size: 50),
            );
          } else if (snapshot.hasError) {
            return Center(
                child: Text(
                    'Video not found: Go back and do pull-up refresh ${snapshot.error}'));
          } else if (snapshot.hasData) {
            final videoData = snapshot.data!;
            String videoUrl = videoData['videoFile'] ?? '';
            String createdAt = videoData['createdAt'] ?? '';
            String formattedDate = formatDate(createdAt);
            String description = videoData['description'] ?? '';

            if (videoUrl.isNotEmpty && !_isVideoInitialized) {
              initializeVideoPlayer(
                  videoUrl); // Initialize video player only once
            }

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Video Player Section
                  if (_isChewieInitialized &&
                      _videoPlayerController.value.isInitialized)
                    // Wrap Chewie widget inside an Expanded widget
                    SizedBox(
                      height: 250, // Fixed height for video player
                      child: Chewie(controller: _chewieController),
                    )
                  else
                    Center(
                        child: LoadingAnimationWidget.threeRotatingDots(
                            color: Colors.red, size: 50)),

                  const SizedBox(height: 10),

                  // Video Title
                  Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            videoData['title'] ?? 'No Title',
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),

                          //Likes Details
                          StatefulBuilder(
                            builder:
                                (BuildContext context, StateSetter setState) {
                              return Row(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      // Like handling logic
                                      // handleLike(isLiked);
                                      debounce?.cancel();

                                      //Starting a new debouncing timer
                                      debounce = Timer(
                                          const Duration(milliseconds: 750),
                                          () => sendLikeToServer(isLiked));
                                      if (mounted) {
                                        setState(() {
                                          if (isLiked) {
                                            likesCount = (likesCount - 1) > 0
                                                ? likesCount - 1
                                                : 0;
                                          } else {
                                            likesCount++;
                                          }
                                          isLiked = !isLiked;

                                          logger.d(
                                              'isLiked - $isLiked.........likesCount - $likesCount');
                                        });
                                      }
                                    },
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.thumb_up,
                                          color: isLiked
                                              ? Colors.blue
                                              : Colors.white,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$likesCount', // Show the likes count
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      )),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Text(
                        'Created At - $formattedDate',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // View Count
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text('${videoData['views'] ?? 0} views'),
                  ),

                  // Description Section with StatefulBuilder
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: StatefulBuilder(
                      builder: (context, setState) {
                        return GestureDetector(
                          onTap: () {
                            if (mounted) {
                              setState(() {
                                _isDescriptionExpanded =
                                    !_isDescriptionExpanded;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Description',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                                if (_isDescriptionExpanded)
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      description,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                if (!_isDescriptionExpanded)
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      description.length > 100
                                          ? '${description.substring(0, 100)}...'
                                          : description,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const Divider(),

                  //User Profile and subscribe button
                  // Inside your build method, modify the User Profile section like this:
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: StatefulBuilder(  // Wrap the entire container with StatefulBuilder
                      builder: (context, setState) {
                        return Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  if (_isVideoInitialized) {
                                    _videoPlayerController.pause();
                                  }
                                  Navigator.pushNamed(
                                    context,
                                    '/channelVideos',
                                    arguments: {
                                      'userId': channelId,
                                      'username': username 
                                    },
                                  );
                                },
                                child: CircleAvatar(
                                  radius: 30,
                                  backgroundImage: NetworkImage(avatarUrl.isNotEmpty
                                      ? avatarUrl
                                      : 'https://dummyimage.com/60x60/000/fff'),
                                ),
                              ),
                              const SizedBox(width: 8),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$username',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Subscribers: $subscribersCount',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),

                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  ConfettiWidget(
                                    confettiController: _confettiController,
                                    blastDirectionality: BlastDirectionality.explosive,
                                    shouldLoop: false,
                                    colors: [Colors.blue, Colors.green, Colors.red, Colors.yellow],
                                    maxBlastForce: 2.5,
                                    minBlastForce: 1,
                                    emissionFrequency: 0.02,
                                    numberOfParticles: 100,
                                    minimumSize: Size(1, 3),
                                    maximumSize: Size(4, 4.5),
                                  ),

                                  TextButton(
                                    onPressed: () {
                                      if (!subscribedStatus) {
                                        _confettiController.play();
                                      }

                                      debounce?.cancel();
                                      debounce = Timer(
                                        const Duration(milliseconds: 500),
                                        () => toggleSubscription(subscribedStatus)
                                      );
                                      
                                      setState(() {  // Use the setState from StatefulBuilder
                                        if(subscribedStatus && subscribersCount > 0) {
                                          subscribersCount--;
                                        } else {
                                          subscribersCount++;
                                        }
                                        subscribedStatus = !subscribedStatus;
                                      });
                                    },
                                    style: TextButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20.0),
                                      ),
                                      padding: EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
                                    ),
                                    child: Text(
                                      subscribedStatus ? 'SUBSCRIBED' : 'SUBSCRIBE',
                                      style: TextStyle(
                                        color: subscribedStatus ? Colors.green : Colors.blue,
                                        fontWeight: FontWeight.bold
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: const Text('Comments',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  CommentsWidget(
                      videoId: widget.videoId), // Replace with actual videoId
                ],
              ),
            );
          } else {
            return const Center(child: Text('No Data Available'));
          }
        },
      ),
    );
  }
}
