import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart'; // For file storage
import 'package:vdtube/constants/constants.dart';
import 'package:http/http.dart' as http;

const BASE_URL = Constants.baseUrl;
const uploadUrl = Constants.baseUrlForUploads;
var logger = Constants.logger;
Timer? debounceTimer;

File? avatarImage;
final ImagePicker _picker = ImagePicker();
// Variable to manage the loading state
bool isUpdateVideoLoading = false;
bool updateFunRunnng = false;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool isDashboardLoading = true; // Track loading state for dashboard stats
  bool isVideosLoading = true; // Track loading state for videos
  String? username = "";
  int videos = 0;
  int views = 0;
  int subscribers = 0;
  int likes = 0;

  List<dynamic> videoList = [];

  // Derived state for isLoading
  bool get isLoading => isDashboardLoading || isVideosLoading;

  @override
  void initState() {
    super.initState();
    loadData(); //Load all the necessary data
  }

  void loadData() {
    fetchUsername(); // Fetch username asynchronously
    fetchDashboardData(); //Fetch dashboard stats on startup
    fetchDashboardVideos(); //Fetch dashboard videos on startup
  }

  @override
  void dispose() {
    // TODO: implement dispose
    debounceTimer?.cancel();
    super.dispose();
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
    } finally {
      fetchDashboardVideos();
      if (mounted) {
        setState(() {
          isDashboardLoading = false;
        });
      }
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

        if (mounted) {
          setState(() {
            videoList = data;
          });
        }
      } else {
        logger.d('Error in fetching your videos - ${response.reasonPhrase}');
      }
    } catch (e) {
      logger.e('Error fetching dashboard videos - $e');
    } finally {
      if (mounted) {
        setState(() {
          isVideosLoading = false;
        });
      }
    }
  }

  Future<void> togglePublishStatus(String videoId) async {
    String? refreshToken = await Constants.getAccessToken();
    String? accessToken = await Constants.getAccessToken();

    var headers = {
      'Cookie': 'accessToken=$accessToken; refreshToken=$refreshToken'
    };

    // logger.d('VIDEO ID - $videoId');

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

  // Check for permission and request if not granted
  Future<void> checkAndRequestPermission(StateSetter localSetState) async {
    PermissionStatus status = await Permission.storage.request();

    if (status.isGranted) {
      // Permission granted, proceed with picking the image
      pickAvatarImage(localSetState);
    } else if (status.isDenied) {
      // Permission denied, show a dialog or alert explaining why permission is needed
      showPermissionDeniedDialog();
    } else if (status.isPermanentlyDenied) {
      // If the user has permanently denied permission, open the settings page to let them enable it
      openAppSettings();
    }
  }

  // Show a dialog if the user denies the permission
  void showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permission Required'),
          content: const Text(
              'Please grant permission to access the gallery to upload an avatar image.'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Pick Image from Gallery and save to temporary directory
  Future<void> pickAvatarImage(StateSetter localSetState) async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      // Get the temporary directory to store the image
      Directory tempDir = await getTemporaryDirectory();
      String tempPath = tempDir.path;

      // Create a new file in the temporary directory
      String fileName = path.basename(pickedFile.path);
      File savedImage = File('$tempPath/$fileName');

      // Copy the picked file to the temporary directory
      await File(pickedFile.path).copy(savedImage.path);

      localSetState(() {
        avatarImage = savedImage; // Set the saved image as the avatar
      });
    }
  }

  //Updating video Details
  Future<void> updateVideoDetails(String videoId, String description,
      String title, File? selectedImage, BuildContext context) async {
    String? refreshToken = await Constants.getAccessToken();
    String? accessToken = await Constants.getAccessToken();

    logger
        .d('Video ID - $videoId----title - $title\ndescription - $description');

    var headers = {
      'Cookie': 'accessToken=$accessToken; refreshToken=$refreshToken'
    };

    //Using different render server url for uploading not vercel one
    var url = Uri.parse('$uploadUrl/video/v/$videoId');

    var request = http.MultipartRequest('PATCH', url);

    //check if title is not empty
    if (title.isNotEmpty) {
      request.fields['title'] = title;
    }

    //check if description is not empty
    if (description.isNotEmpty) {
      request.fields['description'] = description;
    }

    //Check if user added a image or not
    if (avatarImage != null) {
      request.files.add(
          await http.MultipartFile.fromPath('thumbnail', avatarImage!.path));
    }

    //Adding all headers
    request.headers.addAll(headers);

    try {
      //Sending the request and await the response
      http.StreamedResponse response = await request.send();

      if (response.statusCode == 200) {
        logger.d(
            'Video Updated successfully: ${await response.stream.bytesToString()}');

        if (avatarImage != null) {
          await avatarImage!.delete();
        }

        Navigator.pop(context);
        // Add this to show success dialog
        showSuccessDialog();
      } else {
        logger.d('Failed to update the video: ${response.reasonPhrase}');
        // Add this to show error dialog
        Navigator.pop(context);
        showErrorDialog('An error occurred: ${response.reasonPhrase}');
      }
    } catch (e) {
      logger.e('Error in video updation - $e');
      // Add this to show error dialog
      Navigator.pop(context);
      showErrorDialog('An error occurred, please try again.');
    } finally {
      // Ensure setState is called even if there's an error
      if (mounted) {
        setState(() {
          isUpdateVideoLoading = false;
        });
      }
    }
  }

  void showSuccessDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Success'),
          content: const Text(
              'Updated registered successfully!!. PLEASE REFRESH FROM TOP'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                if (mounted) {
                  setState(() {
                    isUpdateVideoLoading = false;
                  });
                }
              },
            ),
          ],
        );
      },
    );
  }

  void showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
                if (mounted) {
                  setState(() {
                    isUpdateVideoLoading = false;
                  });
                }
              },
            ),
          ],
        );
      },
    );
  }

  // Function to delete a video by its ID
  void deleteVideo(String videoId) {
    logger.d('VIDEO ID FOR DELETE - $videoId');
    if (mounted) {
      setState(() {
        // Remove the video from the list where _id matches
        videoList.removeWhere((video) => video['_id'] == videoId);
      });
    }

    deleteVideoPermanently(videoId);
  }

  //API call for deleting the video
  Future<void> deleteVideoPermanently(String videoId) async {
    String? refreshToken = await Constants.getAccessToken();
    String? accessToken = await Constants.getAccessToken();

    var headers = {
      'Cookie': 'accessToken=$accessToken; refreshToken=$refreshToken'
    };

    // logger.d('VIDEO ID - $videoId');

    var url = Uri.parse('$BASE_URL/video/v/$videoId');

    try {
      final response = await http.delete(url, headers: headers);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        logger.d('${responseData['message']}');
      } else {
        logger.d('Error in deleting the video - ${response.reasonPhrase}');
      }
    } catch (e) {
      logger.e('Error occurred while deleting the video - $e');
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
            // Display loading indicator if either data is loading
            if (isVideosLoading || isDashboardLoading)
              Center(
                  child: LoadingAnimationWidget.staggeredDotsWave(
                color: Colors.white,
                size: 50,
              )),

            // Welcome Text
            if (!isLoading) _buildWelcomeText(),

            const SizedBox(height: 20),

            // Stats Row
            if (!isLoading) _buildStatsRow(),

            const SizedBox(height: 40), // Gap

            if (!isLoading) _buildTableHeader(),

            // Placeholder for future entries
            Expanded(
              child: videoList.isEmpty && !isLoading
                  ? Center(
                      child: isVideosLoading
                          ? LoadingAnimationWidget.discreteCircle(
                              color: Colors.white,
                              size: 60,
                              secondRingColor: Colors.black,
                              thirdRingColor: Colors.purple)
                          : Text(
                              'Please drop some videos in My content section',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
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
    return Row(
      children: [
        Expanded(
          child: Text.rich(
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
          ),
        ),
        // Add the refresh icon at the far right
        IconButton(
          icon: Icon(Icons.refresh),
          onPressed: () {
            // Call your dummy function here
            if (mounted) {
              setState(() {
                isDashboardLoading = true;
                isVideosLoading = true;
              });
            }
            loadData();
          },
        ),
      ],
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

    // logger.d('Title - $title.....videoID - $videoId');

    String formattedDate =
        '${creationDate['day']}/${creationDate['month']}/${creationDate['year']}';

    final ValueNotifier<bool> publishStatusNotifier =
        ValueNotifier<bool>(isPublished);

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
                  _showBottomMenu(context, video);
                },
              ),
            ),
          ],
        )
      ],
    );
  }

  void _showBottomMenu(BuildContext context, dynamic video) {
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
                  _showUpdateVideoDialog(context, video);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Video'),
                onTap: () {
                  Navigator.pop(context);
                  // Add delete functionality here
                  _showDeleteConfirmationDialog(context, video);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Function to show delete confirmation dialog
  void _showDeleteConfirmationDialog(BuildContext context, dynamic video) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Are you sure you want to delete this?'),
          content: const Text('This action cannot be reversed.'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.pop(
                    context); // Close the dialog without doing anything
              },
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () {
                Navigator.pop(context); // Close the dialog
                String videoId = video['_id'] ?? '';
                deleteVideo(videoId); // Delete the video from the list
              },
            ),
          ],
        );
      },
    );
  }

  void _showUpdateVideoDialog(BuildContext context, dynamic video) {
    // Reset avatarImage to null
    if (mounted) {
      setState(() {
        avatarImage = null;
      });
    }
    String videoId = video['_id'];
    String title = video['title'] ?? '';
    String description = video['description'] ?? '';
    TextEditingController titleController = TextEditingController(text: title);
    TextEditingController descriptionController =
        TextEditingController(text: description);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Stack(
              children: [
                // AlertDialog content
                AlertDialog(
                  contentPadding: EdgeInsets.all(20),
                  title: const Text('Update Video'),
                  content: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image Picker for Avatar with increased size and matching width
                        GestureDetector(
                          onTap: () async {
                            await checkAndRequestPermission(setState);
                          },
                          child: Container(
                            width: MediaQuery.of(context)
                                .size
                                .width, // Ensure finite width
                            height: 180, // Fixed height

                            color: Colors.blue[900],
                            child: avatarImage == null
                                ? Icon(Icons.camera_alt,
                                    size: 80, color: Colors.grey[300])
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                        8), // Optional rounded corners
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        return Image.file(
                                          avatarImage!,
                                          width: constraints
                                              .maxWidth, // Use the maximum available width
                                          height: constraints
                                              .maxHeight, // Use the maximum available height
                                          fit: BoxFit.cover,
                                        );
                                      },
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Draggable Title Text Field inside a colored box with decreased padding
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: TextField(
                            controller: titleController,
                            maxLines: null, // Allow multiple lines for title
                            style: const TextStyle(fontSize: 12),
                            decoration: const InputDecoration(
                              labelText: 'Title',
                              hintText: 'Enter new title',
                              labelStyle: TextStyle(fontSize: 14),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12), // Space between fields

                        // Draggable Description Text Field inside a colored box
                        Container(
                          padding: const EdgeInsets.only(
                              left: 12, right: 12, top: 5, bottom: 5),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: TextField(
                            controller: descriptionController,
                            maxLines:
                                null, // Allow multiple lines for the description
                            style: const TextStyle(fontSize: 12),
                            decoration: const InputDecoration(
                              labelText: 'Description',
                              hintText: 'Enter new description',
                              labelStyle: TextStyle(fontSize: 14),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    // Cancel Button with color
                    TextButton(
                      onPressed: () {
                        // Reset avatarImage to null
                        if (mounted) {
                          setState(() {
                            avatarImage = null;
                          });
                        }
                        Navigator.pop(context); // Close the dialog
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Cancel'),
                    ),
                    // Update Button with color
                    TextButton(
                      onPressed: () async {
                        // Set the loading state to true
                        if (mounted) {
                          setState(() {
                            isUpdateVideoLoading = true;
                          });
                        }
                        // Retrieve the updated title and description
                        String newTitle = titleController.text;
                        String newDescription = descriptionController.text;

                        await updateVideoDetails(videoId, newDescription,
                            newTitle, avatarImage, context);
                        // Call update video function
                        // try {
                        // } catch (e) {
                        //   logger.d('Error in updating - $e');
                        //   Navigator.pop(context);
                        //   // showErrorDialog('Error in updating');
                        // }
                        // setState(() {
                        //   isUpdateVideoLoading = false;
                        // });
                        // // Once the request is completed, close the dialog
                        // if (!isUpdateVideoLoading) {
                        //   Navigator.pop(context); // Close the dialog
                        // }
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: isUpdateVideoLoading
                          ? CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            )
                          : const Text('Update'),
                    ),
                  ],
                ),

                // Loader Overlay (only visible when isLoading is true)
                if (isUpdateVideoLoading)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black
                          .withOpacity(0.5), // Semi-transparent overlay
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
