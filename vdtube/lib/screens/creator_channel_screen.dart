import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vdtube/utils/widgets/video_card.dart';
import 'package:vdtube/constants/constants.dart';
import 'package:http/http.dart' as http;
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:vdtube/utils/widgets/drawer.dart';

const BASE_URL = Constants.baseUrl;
var logger = Constants.logger;

class CreatorChannelScreen extends StatefulWidget {
  final String userId;
  final String username;

  const CreatorChannelScreen(
      {super.key, required this.userId, required this.username});

  @override
  State<StatefulWidget> createState() => _CreatorChannelScreen();
}

class _CreatorChannelScreen extends State<CreatorChannelScreen> {
  List<dynamic> videos = []; // Store fetched videos
  int currentPage = 1; // Start with the first page
  int totalPages = 1; // Total pages from the API response
  bool isLoading = false; // Track if a fetch is in progress
  String avatarUrl = '';
  String coverImageUrl = '';
  String? username = '';
  // Track which button is selected
  String selectedButton = '';
  String sortBy = '';
  String sortType = '';

  final ScrollController _scrollController = ScrollController();

  // Search related variables
  TextEditingController searchController = TextEditingController();
  String searchQuery = ''; // Stores the current search query

  @override
  void initState() {
    super.initState();

    // Set the system UI overlay style to ensure proper status bar appearance
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    _scrollController.addListener(_scrollListener);
    fetchCreatorVideos(2); // Fetch user history
    fetchUserDetails();
  }

  Future<void> fetchUserDetails() async {
    String? accessToken = await Constants.getAccessToken();
    String? refreshToken = await Constants.getRefreshToken();

    var headers = {
      'Cookie': 'accessToken=$accessToken; refreshToken=$refreshToken'
    };

    var url = Uri.parse('$BASE_URL/user/ch/${widget.username}');

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        final data = responseBody['data'];

        if (mounted) {
          setState(() {
            avatarUrl = data['avatar'];
            coverImageUrl = data['coverImage'];
            username = data['userName'];
          });
        }

        logger.d('Channel Profile fetched successfully');
      } else {
        logger.d(
            'Error while fetching Channel Profile - ${response.reasonPhrase}');
      }
    } catch (e) {
      logger.e('Error in Profile Fetching - $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false; // Stop loader
        });
      }
    }
  }

  //CalledBy tell who called us ScrollListener or other method
  //Because if scrollListener called us then we have to append
  //fetchedVideos to 'video' not assign.
  Future<void> fetchCreatorVideos(int calledBy) async {
    if (isLoading || currentPage > totalPages) {
      logger.d('No more videos - $currentPage......$totalPages');
      return;
    }

    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    String? accessToken = await Constants.getAccessToken();
    String? refreshToken = await Constants.getRefreshToken();

    // Headers with tokens
    var headers = {
      'Accept': 'application/json',
      'Cookie': 'accessToken=$accessToken; refreshToken=$refreshToken',
    };

    logger.d('sortBy - $sortBy\nsortType - $sortType');

    String apiUrl =
        '$BASE_URL/video/?page=$currentPage&limit=10&query=$searchQuery&sortBy=$sortBy&sortType=$sortType&userId=${widget.userId}';

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        final fetchedVideos = responseBody['data']['docs'];
        if (mounted) {
          setState(() {
            if (calledBy == 1) {
              videos.addAll(fetchedVideos); //append more videos
            } else {
              videos = fetchedVideos; // assign new videos
            }
            totalPages =
                responseBody['data']['totalPages']; // Update total pages
            currentPage =
                responseBody['data']['page'] + 1; // Next page to fetch
          });
        }
        logger.d('Channel videos fetched successfully');
      } else {
        logger.d('Error fetching Channel videos: ${response.statusCode}');
      }
    } catch (e) {
      logger.e('Error occurred in Channel videos - $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> homeVideos() async {
    if (isLoading || currentPage > totalPages) {
      logger.d('No more videos - $currentPage......$totalPages');
      return;
    }
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    logger.d('QUERY IS - $searchQuery');

    String apiUrl =
        '$BASE_URL/video/?page=$currentPage&limit=10&query=$searchQuery&sortBy=createdAt&sortType=asc&userId=${widget.userId}';

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        final fetchedVideos = responseBody['data']['docs'];

        if (mounted) {
          setState(() {
            videos.addAll(fetchedVideos); // Append new videos
            totalPages =
                responseBody['data']['totalPages']; // Update total pages
            currentPage =
                responseBody['data']['page'] + 1; // Next page to fetch
          });
        }
        logger.d('Videos fetched successfully');
      } else {
        logger.d('Error fetching videos: ${response.statusCode}');
      }
    } catch (e) {
      logger.d('Error occurred - $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Function to change the button's color based on its selected state
  Color getButtonColor(String button) {
    switch (button) {
      case 'Latest':
        return selectedButton == 'Latest'
            ? Colors.deepPurpleAccent[700]!
            : Colors.blueGrey.shade800;
      case 'Popular':
        return selectedButton == 'Popular'
            ? Colors.deepPurpleAccent[700]!
            : Colors.blueGrey.shade800;
      case 'Oldest':
        return selectedButton == 'Oldest'
            ? Colors.deepPurpleAccent[700]!
            : Colors.blueGrey.shade800;
      default:
        return Colors.blueAccent;
    }
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      logger.d('calling again');
      fetchCreatorVideos(1); // Fetch more videos when nearing the bottom
    }
  }

  @override
  void dispose() {
    _scrollController.dispose(); // Clean up the controller
    searchController.dispose(); // Dispose the controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: searchQuery.isEmpty
            ? Text('${widget.username}\'s Page')
            : TextField(
                controller: searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search...',
                  hintStyle: TextStyle(color: Colors.black),
                  border: InputBorder.none,
                ),
                style: const TextStyle(color: Colors.black),
                onChanged: (value) {
                  if (mounted) {
                    setState(() {
                      searchQuery =
                          value; // Update search query as the user types
                    });
                  }
                },
                onSubmitted: (value) {
                  if (mounted) {
                    setState(() {
                      searchQuery = value; // Set final query on submit
                    });
                  }
                  // Clear existing videos and reset pagination
                  videos.clear();
                  currentPage = 1;
                  totalPages = 1;
                  homeVideos(); // Fetch videos based on the query
                },
              ),
        backgroundColor: Colors.redAccent,
        elevation: 0,
        toolbarHeight: kToolbarHeight,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: IconButton(
              icon: Icon(searchQuery.isEmpty ? Icons.search : Icons.close),
              onPressed: () {
                if (mounted) {
                  setState(() {
                    if (searchQuery.isEmpty) {
                      // Switch to search mode
                      searchQuery = 'search'; // Trigger TextField to show
                    } else {
                      // Clear search
                      searchController.clear();
                      searchQuery = '';
                      videos.clear();
                      currentPage = 1;
                      totalPages = 1;
                      fetchCreatorVideos(2);
                    }
                  });
                }
              },
            ),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshPage, // Triggered when pulling to refresh
          child: Column(
            children: [
              // Top Section with Avatar and Cover Image using Stack
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueGrey.withOpacity(0.6), // Shadow color
                      blurRadius: 7, // Blur radius
                      offset: Offset(0, 4), // Shadow offset (below the stack)
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Cover Image
                    Container(
                      height: MediaQuery.of(context).size.height *
                          0.25, // 25% of screen
                      width: double.infinity,
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: coverImageUrl.isNotEmpty
                              ? NetworkImage(coverImageUrl)
                              : const AssetImage(
                                      'assets/images/default_avatar.png')
                                  as ImageProvider,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    // Avatar on top of Cover Image
                    Positioned(
                      top: 16.0,
                      left: 16.0,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape
                              .circle, // Ensures the container is circular
                          border: Border.all(
                            color: Colors.white, // Border color
                            width: 1.5, // Border width
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  Colors.black.withOpacity(0.4), // Shadow color
                              blurRadius: 5, // Blur radius
                              offset: Offset(0, 4), // Shadow offset
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 35,
                          backgroundImage: avatarUrl.isNotEmpty
                              ? NetworkImage(avatarUrl)
                              : const AssetImage(
                                      'assets/images/default_avatar.png')
                                  as ImageProvider,
                          child: avatarUrl.isEmpty
                              ? const Text('👤', style: TextStyle(fontSize: 30))
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              //Sorting buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        if (mounted) {
                          setState(() {
                            selectedButton =
                                selectedButton == 'Latest' ? '' : 'Latest';
                            if(selectedButton.isEmpty){
                              sortBy = '';
                              sortType = '';
                            }
                            else{
                              sortBy = 'createdAt';
                              sortType = 'desc';
                            }
                            totalPages = 1;
                            currentPage = 1;
                          });
                        }
                        fetchCreatorVideos(2);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: getButtonColor(
                            'Latest'), // Dynamically set button color
                      ),
                      child: const Text('Latest'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (mounted) {
                          setState(() {
                            selectedButton =
                                selectedButton == 'Popular' ? '' : 'Popular';
                            if(selectedButton.isEmpty){
                              sortBy = '';
                              sortType = '';
                            }
                            else{
                              sortBy = 'views';
                              sortType = 'desc';
                            }
                            totalPages = 1;
                            currentPage = 1;
                          });
                        }
                        fetchCreatorVideos(2);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: getButtonColor(
                            'Popular'), // Dynamically set button color
                      ),
                      child: const Text('Popular'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (mounted) {
                          setState(() {
                            selectedButton =
                                selectedButton == 'Oldest' ? '' : 'Oldest';
                            if(selectedButton.isEmpty){
                              sortBy = '';
                              sortType = '';
                            }
                            else{
                              sortBy = 'createdAt';
                              sortType = 'asc';
                            }
                            totalPages = 1;
                            currentPage = 1;
                          });
                        }
                        fetchCreatorVideos(2);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: getButtonColor(
                            'Oldest'), // Dynamically set button color
                      ),
                      child: const Text('Oldest'),
                    ),
                  ],
                ),
              ),

              // Videos Section
              Expanded(
                child: videos.isEmpty
                    ? Center(
                        child: LoadingAnimationWidget.threeRotatingDots(
                            color: Colors.white, size: 50)) // Loading indicator
                    : ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        itemCount: videos.length +
                            (isLoading ? 1 : 0), // Add a loader item
                        itemBuilder: (context, index) {
                          if (index < videos.length) {
                            final video = videos[index];
                            return VideoCard(
                              videoId: video['_id'],
                              title: video['title'] ?? 'No Title',
                              videoLength: formatDuration(video['duration']),
                              thumbnailUrl: video['thumbnail'] ??
                                  'https://via.placeholder.com/320x180',
                            );
                          } else {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: LoadingAnimationWidget.threeRotatingDots(
                                    color: Colors.white, size: 50),
                              ),
                            ); // Show loader at the end
                          }
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Function to refresh the page
  Future<void> _refreshPage() async {
    if (mounted) {
      setState(() {
        videos.clear(); // Clear existing videos
        currentPage = 1; // Reset pagination
        totalPages = 1; // Reset total pages
        sortBy = '';
        sortType = '';
        selectedButton = '';
      });
    }

    await fetchCreatorVideos(2); // Fetch the latest videos
  }

  String formatDuration(double? duration) {
    if (duration == null) return 'Unknown';
    final minutes = (duration / 60).floor();
    final seconds = (duration % 60).round();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
