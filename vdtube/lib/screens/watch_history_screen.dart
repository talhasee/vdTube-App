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

class WatchHistoryScreen extends StatefulWidget {
  const WatchHistoryScreen({super.key});

  @override
  State<StatefulWidget> createState() => _WatchHistoryScreen();
}

class _WatchHistoryScreen extends State<WatchHistoryScreen> {
  List<dynamic> videos = []; // Store fetched videos
  int currentPage = 1; // Start with the first page
  int totalPages = 1; // Total pages from the API response
  bool isLoading = false; // Track if a fetch is in progress
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

    watchHistoryVideos(); // Fetch user history
    // _scrollController.addListener(_scrollListener); // Add scroll listener
  }

  Future<void> watchHistoryVideos() async {
    if (isLoading) {
      logger.d('No more videos - $currentPage......$totalPages');
      return;
    }

    setState(() {
      isLoading = true;
    });

    // logger.d('QUERY IS - $searchQuery');

    String? accessToken = await Constants.getAccessToken();
    String? refreshToken = await Constants.getRefreshToken();

    // Headers with tokens
    var headers = {
      'Accept': 'application/json',
      'Cookie': 'accessToken=$accessToken; refreshToken=$refreshToken',
    };

    String apiUrl = '$BASE_URL/user/history';

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        final fetchedVideos = responseBody['data'];

        setState(() {
          videos = fetchedVideos; // Append new videos
          //SET TO ONE BECAUSE PAGING NOT IMPLEMENTED RIGHT NOW IN WATCH HISTORY VIDEOS
          totalPages = 1; // Update total pages
          currentPage = 1; // Next page to fetch
        });
        logger.d('Watch history Videos fetched successfully');
      } else {
        logger.d('Error fetching history videos: ${response.statusCode}');
      }
    } catch (e) {
      logger.e('Error occurred in history videos - $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> homeVideos() async {
    if (isLoading || currentPage > totalPages) {
      logger.d('No more videos - $currentPage......$totalPages');
      return;
    }

    setState(() {
      isLoading = true;
    });

    logger.d('QUERY IS - $searchQuery');

    String apiUrl =
        '$BASE_URL/video/?page=$currentPage&limit=10&query=$searchQuery&sortBy=&sortType=&userId=';

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

        setState(() {
          videos.addAll(fetchedVideos); // Append new videos
          totalPages = responseBody['data']['totalPages']; // Update total pages
          currentPage = responseBody['data']['page'] + 1; // Next page to fetch
        });
        logger.d('Videos fetched successfully');
      } else {
        logger.d('Error fetching videos: ${response.statusCode}');
      }
    } catch (e) {
      logger.d('Error occurred - $e');
    } finally {
      setState(() {
        isLoading = false;
      });
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
            ? const Text('📺Watch History')
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
                  setState(() {
                    searchQuery =
                        value; // Update search query as the user types
                  });
                },
                onSubmitted: (value) {
                  setState(() {
                    searchQuery = value; // Set final query on submit
                  });
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
                    watchHistoryVideos();
                  }
                });
              },
            ),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshPage, // Triggered when pulling to refresh
          child: videos.isEmpty
              ? Center(
                  child: LoadingAnimationWidget.threeRotatingDots(
                      color: Colors.white, size: 50)) // Loading indicator
              : ListView.builder(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  itemCount:
                      videos.length + (isLoading ? 1 : 0), // Add a loader item
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
      ),
    );
  }

  // Function to refresh the page
  Future<void> _refreshPage() async {
    setState(() {
      videos.clear(); // Clear existing videos
      currentPage = 1; // Reset pagination
      totalPages = 1; // Reset total pages
    });
    await watchHistoryVideos(); // Fetch the latest videos
  }

  String formatDuration(double? duration) {
    if (duration == null) return 'Unknown';
    final minutes = (duration / 60).floor();
    final seconds = (duration % 60).round();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
