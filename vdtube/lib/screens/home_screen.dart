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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<StatefulWidget> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  List<dynamic> videos = []; // Store fetched videos
  int currentPage = 1; // Start with the first page
  int totalPages = 1; // Total pages from the API response
  bool isLoading = false; // Track if a fetch is in progress
  final ScrollController _scrollController = ScrollController();
  late RouteObserver<PageRoute> routeObserver;

  // Search related variables
  TextEditingController searchController = TextEditingController();
  String searchQuery = ''; // Stores the current search query

  @override
  void initState() {
    super.initState();
    routeObserver = RouteObserver<PageRoute>();

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

    homeVideos(); // Fetch initial videos
    _scrollController.addListener(_scrollListener); // Add scroll listener
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

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      logger.d('calling again');
      homeVideos(); // Fetch more videos when nearing the bottom
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void didPopNext() {
    // This is called when the user returns to this screen
    _refreshPage();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _scrollController.dispose(); // Clean up the controller
    searchController.dispose(); // Dispose the controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: searchQuery.isEmpty
            ? const Text('📺vdTube')
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
                      homeVideos();
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
                      return GestureDetector(
                        onTap: () async {
                          logger.d('VIDEO DATA - $video');
                          // Assuming that the video might not be available
                          if (video == null) {
                            // Show a dialog if video data is not available
                            _showVideoNotFoundDialog();
                          }
                        },
                        child: VideoCard(
                          videoId: video['_id'],
                          title: video['title'] ?? 'No Title',
                          videoLength: formatDuration(video['duration']),
                          thumbnailUrl: video['thumbnail'] ??
                              'https://via.placeholder.com/320x180',
                        ),
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
    if (mounted) {
      setState(() {
        videos.clear(); // Clear existing videos
        currentPage = 1; // Reset pagination
        totalPages = 1; // Reset total pages
      });
    }
    await homeVideos(); // Fetch the latest videos
  }

  String formatDuration(double? duration) {
    if (duration == null) return 'Unknown';
    final minutes = (duration / 60).floor();
    final seconds = (duration % 60).round();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Function to show the "Video not found" dialog and dismiss after 5 seconds
  void _showVideoNotFoundDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Video not found"),
          content: Text("The video you're looking for could not be found."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text("OK"),
            ),
          ],
        );
      },
    );

    // Dismiss the dialog after 5 seconds if not clicked
    Future.delayed(const Duration(seconds: 5), () {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _refreshPage(); // Call the refresh function after dismissing the dialog
    });
  }
}
