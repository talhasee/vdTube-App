import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:vdtube/constants/constants.dart';
import 'package:http/http.dart' as http;

const BASE_URL = Constants.baseUrl;
var logger = Constants.logger;

class SubscribedUsersScreen extends StatefulWidget {
  const SubscribedUsersScreen({super.key});

  @override
  State<StatefulWidget> createState() => _SubscribedUsersScreen();
}

class _SubscribedUsersScreen extends State<SubscribedUsersScreen> {
  List<dynamic> subscribedUsers = []; // Store fetched Subscribed Channel's data
  int currentPage = 1; // Start with the first page
  int totalPages = 1; // Total pages from the API response
  bool isLoading = false; // Track if a fetch is in progress
  String avatarUrl = '';
  String coverImageUrl = '';
  String? username = '';
  String? userId = '';
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
    userNameAndUserIdInit();
    fetchUserDetails();
    fetchSubscribedChannels();
  }

  Future<void> userNameAndUserIdInit() async {
    String? tempId = await Constants.getUserId();
    String? tempUsername = await Constants.getUsername();

    setState(() {
      userId = tempId;
      username = tempUsername;
    });
  }

  Future<void> fetchUserDetails() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    String? accessToken = await Constants.getAccessToken();
    String? refreshToken = await Constants.getRefreshToken();

    var headers = {
      'Cookie': 'accessToken=$accessToken; refreshToken=$refreshToken'
    };

    var url = Uri.parse('$BASE_URL/user/ch/$username');

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        final data = responseBody['data'];

        if (mounted) {
          setState(() {
            avatarUrl = data['avatar'];
            coverImageUrl = data['coverImage'];
          });
        }

        logger.d('Channel Profile fetched successfully - $isLoading');
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

  //Fetch Subscribed Channels
  Future<void> fetchSubscribedChannels() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }
    String? accessToken = await Constants.getAccessToken();
    String? refreshToken = await Constants.getRefreshToken();

    var headers = {
      'Cookie': 'accessToken=$accessToken; refreshToken=$refreshToken'
    };

    final url = Uri.parse('$BASE_URL/subscriptions/u/$userId');

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        logger.d('Subscribed Channel fetched successfully');

        final responseData = json.decode(response.body);

        final data = responseData['data'];

        if (mounted) {
          setState(() {
            subscribedUsers = data;
          });
        }
      } else {
        logger.d(
            'Unable to fetching subsrcibed channels - ${response.reasonPhrase}');
      }
    } catch (e) {
      logger.e('Error in fetching subscribed Channels - $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ignore: unused_element
  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      logger.d('calling again');
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
        title: const Text(
          'Subscribed Channels',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _refreshPage,
              child: Column(
                children: [
                  // Top Section with Avatar and Cover Image
                  Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blueGrey.withOpacity(0.6),
                          blurRadius: 7,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Container(
                          height: MediaQuery.of(context).size.height * 0.25,
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
                        Positioned(
                          top: 16.0,
                          left: 16.0,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.4),
                                  blurRadius: 5,
                                  offset: Offset(0, 4),
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
                                  ? const Text('👤',
                                      style: TextStyle(fontSize: 30))
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // List of Subscribed Users
                  Expanded(
                    child: subscribedUsers.isEmpty && !isLoading
                        ? Center(
                            child: isLoading
                                ? LoadingAnimationWidget.discreteCircle(
                                    color: Colors.white,
                                    size: 60,
                                    secondRingColor: Colors.black,
                                    thirdRingColor: Colors.purple)
                                : Text(
                                    'You have not subscribed anyone.',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white70,
                                    ),
                                  ),
                          )
                        : ListView.builder(
                            itemCount: subscribedUsers.length,
                            itemBuilder: (context, index) {
                              Map<String, dynamic> user =
                                  subscribedUsers[index]['subscribedChannel'];
                              String? username = user['userName'];
                              String? avatar = user['avatar'];
                              String? fullName = user['fullName'];
                              String? userId = user['_id'];
                              return _buildUserCard(
                                  context, username, fullName, avatar, userId);
                            },
                          ),
                  ),
                ],
              ),
            ),
            if (isLoading)
              Stack(
                children: [
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                    child: Container(
                      color: Colors.black.withOpacity(0.4),
                    ),
                  ),
                  Center(
                    child: LoadingAnimationWidget.threeRotatingDots(
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, String? username,
      String? fullName, String? avatarUrl, String? userId) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Circular Avatar
            GestureDetector(
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/channelVideos',
                  arguments: {
                    'userId' : userId,
                    'username': username
                  },
                );

              },
              child: CircleAvatar(
                radius: 35,
                backgroundImage: avatarUrl!.isNotEmpty
                    ? NetworkImage(avatarUrl)
                    : const AssetImage('assets/images/default_avatar.png')
                        as ImageProvider,
                child: avatarUrl.isEmpty
                    ? const Text('👤', style: TextStyle(fontSize: 30))
                    : null,
              ),
            ),

            const SizedBox(width: 16),
            // Username and Full Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        username!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // More Vert Icon Button
                      IconButton(
                        icon: const Icon(Icons.more_vert),
                        onPressed: () {
                          _showBottomMenu(context); // Call the menu function
                        },
                      ),
                    ],
                  ),
                  Text(
                    fullName!,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBottomMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Unsubscribe'),
                onTap: () {
                  Navigator.pop(context);
                  // Add delete functionality here
                  //TODO
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Function to refresh the page
  Future<void> _refreshPage() async {
    if (mounted) {
      setState(() {});
    }
  }
}
