import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:vdtube/constants/constants.dart';
import 'package:http/http.dart' as http;

const BASE_URL = Constants.baseUrl;
var logger = Constants.logger;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<bool> publishStatus =
      List.generate(5, (index) => false); // Initial publish status
  String? username = "";
  int videos = 0;
  int views = 0;
  int subscribers = 0;
  int likes = 0;

  List<dynamic> videoList = [];

  @override
  void initState() {
    super.initState();
    fetchUsername(); // Fetch username asynchronously
    fetchDashboardData(); //Fetch dashboard stats on startup
    fetchDashboardVideos(); //Fetch dashboard videos on startup
  }

  Future<void> fetchUsername() async {
    String? tempName = await Constants.getUsername();
    setState(() {
      username = tempName;
    });
  }

  Future<void> fetchDashboardData() async {
    String? refreshToken = await Constants.getAccessToken();
    String? accessToken = await Constants.getAccessToken();

    var headers = {
      'Cookie': 'accessToken=$accessToken; refreshToken=$refreshToken'
    };

    var url = Uri.parse('$BASE_URL/dashboard/stats');

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        logger.d('Dashboard data fetched successfully');

        final responseData = json.decode(response.body);

        var data = responseData['data'];
        logger.d('DATA - $data');

        setState(() {
          videos = data['totalVideos'];
          likes = data['totalLikes'];
          subscribers = data['totalSubscribers'];
          views = data['totalViews'];
        });
      } else {
        logger
            .d('Error in fetching dashboard stats - ${response.reasonPhrase}');
      }
    } catch (e) {
      logger.e('Error in loading stats - $e');
    }
  }

  Future<void> fetchDashboardVideos() async {
    String? refreshToken = await Constants.getAccessToken();
    String? accessToken = await Constants.getAccessToken();

    var headers = {
      'Cookie': 'accessToken=$accessToken; refreshToken=$refreshToken'
    };

    var url = Uri.parse('$BASE_URL/dashboard/videos');

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        var data = responseData['data'];

        setState(() {
          videoList = data;
        });
      } else {
        logger.d('Error in fetching your videos - ${response.reasonPhrase}');
      }
    } catch (e) {
      logger.e('Error fetching dashboard videos - $e');
    }
  }

  Future<void> togglePublishStatus(String videoId) async {
    String? refreshToken = await Constants.getAccessToken();
    String? accessToken = await Constants.getAccessToken();

    var headers = {
      'Cookie': 'accessToken=$accessToken; refreshToken=$refreshToken'
    };

    logger.d('VIDEO ID - $videoId');

    var url = Uri.parse('$BASE_URL/video/toggle/publish/$videoId');

    try {
      final response = await http.patch(url, headers: headers);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        logger.d('${responseData['message']}');
      } else {
        logger.d('Error in changing publish status - ${response.reasonPhrase}');
      }
    } catch (e) {
      logger.e('Error toggling publish status - $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //Welcome Text
            _buildWelcomeText(),

            const SizedBox(height: 20),

            //Stats Row
            _buildStatsRow(),

            const SizedBox(height: 40), // Gap

            _buildTableHeader(),

            // Placeholder for future entries
            Expanded(
              child: videoList.isEmpty
                  ? Center(
                      child: Text(
                        'Please drop some videos in My content section',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70, // Adjust the color to match your theme
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: videoList.length,
                      itemBuilder: (context, index) {
                        var video = videoList[index];
                        return _buildVideoRow(video);
                      },
                    ),
            ),

          
          ],
        ),
      ),
    );
  }

  //Welcome Text Widget
  Widget _buildWelcomeText() {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Welcome back, ',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white, // Default text color
            ),
          ),
          TextSpan(
            text: username, // The username in italics with a custom color
            style: TextStyle(
              fontSize: 24,
              fontStyle: FontStyle.italic, // Italicize the username
              color: Colors.blue[400], // Change to desired color
            ),
          ),
        ],
      ),
    );
  }

  //Stats Rows Widget
  Widget _buildStatsRow() {
    return Column(
      children: [
        // Stats Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatBox('Videos 📹', videos.toString()),
            _buildStatBox('Total Views 👁️', views.toString()),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatBox('Subscribers 🫂', subscribers.toString()),
            _buildStatBox('Likes ❤️', likes.toString()),
          ],
        ),
      ],
    );
  }

  Widget _buildStatBox(String title, String value) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: Colors.amber),
          ),
        ],
      ),
    );
  }

  //Table header Widget
  Widget _buildTableHeader() {
    return // List Header
        Table(
      columnWidths: {
        0: FixedColumnWidth(50), // Toggle
        1: FixedColumnWidth(70), // Status
        2: FlexColumnWidth(100), // Title
        3: FixedColumnWidth(70), // Date
        4: FixedColumnWidth(50), // Actions
      },
      children: [
        TableRow(
          children: [
            Center(
              child: Text(
                'Toggle',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            Center(
              child: Text(
                'Publish',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            Center(
              child: Text(
                'Title',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            Center(
              child: Text(
                'Date',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            Center(
              child: Text(
                'Actions',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ],
    );
  }

  //Table row Contents builder widget
  Widget _buildVideoRow(dynamic video) {
    String title = video['title'] ?? 'No title';
    bool isPublished = video['isPublished'] ?? false;
    Map creationDate = video['creationDate'];
    String videoId = video['_id'];

    logger.d('Title - $title.....videoID - $videoId');

    String formattedDate =
        '${creationDate['day']}/${creationDate['month']}/${creationDate['year']}';

    final ValueNotifier<bool> publishStatusNotifier =
        ValueNotifier<bool>(isPublished);

    Timer? debounceTimer;

    return Table(
      columnWidths: const {
        0: FixedColumnWidth(50),
        1: FixedColumnWidth(60),
        2: FlexColumnWidth(120),
        3: FixedColumnWidth(70),
        4: FixedColumnWidth(50),
      },
      children: [
        TableRow(
          children: [
            Align(
              alignment: Alignment.center,
              child: ValueListenableBuilder<bool>(
                valueListenable: publishStatusNotifier,
                builder: (context, isPublished, child) {
                  return Switch(
                    value: isPublished,
                    onChanged: (value) {
                      // Update the ValueNotifier instantly
                      publishStatusNotifier.value = value;

                      // Debounced API call
                      debounceTimer?.cancel(); // Cancel the previous timer
                      debounceTimer = Timer(Duration(seconds: 2), () {
                        togglePublishStatus(videoId);
                      });
                    },
                  );
                },
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: ValueListenableBuilder<bool>(
                  valueListenable: publishStatusNotifier,
                  builder: (context, isPublished, child) {
                    return Icon(
                      Icons.circle,
                      color: isPublished ? Colors.green : Colors.red,
                      size: 20,
                    );
                  },
                ),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: Text(
                  title.length > 20 ? '${title.substring(0, 20)}...' : title,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: Text(
                  formattedDate,
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: IconButton(
                icon: const Icon(Icons.more_vert, size: 16),
                onPressed: () {
                  _showBottomMenu(context);
                },
              ),
            ),
          ],
        )
      ],
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
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('Update Video'),
                onTap: () {
                  Navigator.pop(context);
                  // Add update functionality here
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Video'),
                onTap: () {
                  Navigator.pop(context);
                  // Add delete functionality here
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
