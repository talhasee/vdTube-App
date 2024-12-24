import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:vdtube/constants/constants.dart';
import 'package:permission_handler/permission_handler.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as path;
// ignore: depend_on_referenced_packages
import 'package:path_provider/path_provider.dart';

const BASE_URL = Constants.baseUrl;
const uploadUrl = Constants.baseUrlForUploads;
var logger = Constants.logger;

class AddVideoScreen extends StatefulWidget {
  const AddVideoScreen({super.key});
  @override
  State<StatefulWidget> createState() => _AddVideoScreenState();
}

class _AddVideoScreenState extends State<AddVideoScreen> {
  String avatarUrl = '';
  String coverImageUrl = '';
  String? username = ''; // Replace with dynamic username
  bool isLoading = true; // Loader state
  File? thumbnailImage;
  File? coverImage;
  File? videoFile;
  String? videoName;
  final ImagePicker _picker = ImagePicker();
  bool imagePlaced = false; //Flag to track if image is placed
  String title = '';
  String description = '';
  TextEditingController titleController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  bool isUploading = false;
  bool isUploadSuccess = false;

  @override
  void initState() {
    super.initState();
    fetchUsername();
    fetchUserDetails();
  }

  Future<void> fetchUsername() async {
    String? tempName = await Constants.getUsername();
    if (mounted) {
      setState(() {
        username = tempName;
      });
    }
  }

  // Function to clear text fields after successful upload
  void clearDataFields() {
    titleController.clear();
    descriptionController.clear();
    videoFile = null;
    videoName = "";
    thumbnailImage = null;
  }

  Future<void> fetchUserDetails() async {
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

  // Check for permission and request if not granted
  Future<void> checkAndRequestPermission(int flag) async {
    PermissionStatus status = await Permission.storage.request();

    if (status.isGranted) {
      // Permission granted, proceed with picking the image
      if (flag == 1) {
        pickAvatarImage(flag);
      } else if (flag == 2) {
        pickVideo();
      } else {
        await pickAvatarImage(flag);
        updateCoverImage();
      }
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
  Future<void> pickAvatarImage(int flag) async {
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

      if (flag == 1) {
        if (mounted) {
          setState(() {
            thumbnailImage = savedImage; // Set the saved image as the avatar
            imagePlaced = true;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            coverImage = savedImage;
          });
        }
      }
    }
  }

  //Pick Video From Gallery
  Future<void> pickVideo() async {
    final pickdedFile = await _picker.pickVideo(source: ImageSource.gallery);

    if (pickdedFile != null) {
      if (mounted) {
        setState(() {
          videoFile = File(pickdedFile.path);
          videoName = pickdedFile.name; //Extract the name of the video
        });
      }
    }
  }

  // Show popup while uploading
  void showPopUpWhileUplaoding() {
    showDialog(
      context: context,
      barrierDismissible:
          isUploadSuccess, // Prevents closing by tapping outside
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Center(
            child: Container(
              width: 300,
              height: 250,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // If still uploading, show the loader
                  isUploading
                      ? LoadingAnimationWidget.discreteCircle(
                          color: Colors.white,
                          size: 50,
                          secondRingColor: Colors.indigo.shade900,
                          thirdRingColor: Colors.orange.shade800,
                        )
                      : Container(),
                  SizedBox(height: 20),
                  // Display different messages based on upload success/failure
                  Text(
                    isUploading
                        ? "Thank you for your patience, your video is getting uploaded..."
                        : isUploadSuccess
                            ? 'Video uploaded successfully! Head to the dashboard to publish it.'
                            : 'Failed to upload video. Try again later.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  SizedBox(height: 20),
                  // OK button is enabled when upload is finished
                  ElevatedButton(
                    onPressed: isUploading
                        ? null
                        : () {
                            Navigator.pop(context); // Close the dialog
                          },
                    child: Text(isUploading ? 'Uploading...' : 'OK'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Snackbar Utility Function
  void showSnackbar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  //Api call for publishing the video
  Future<void> publishVideo() async {
    if (mounted) {
      setState(() {
        isUploading = true;
      });
    }

    String? accessToken = await Constants.getAccessToken();
    String? refreshToken = await Constants.getRefreshToken();

    var headers = {
      'Cookie': 'accessToken=$accessToken; refreshToken=$refreshToken'
    };

    //For uploading task we'll use render server not verel
    var url =
        Uri.parse('$uploadUrl/video/');

    var request = http.MultipartRequest('POST', url);

    if (title.isNotEmpty) {
      request.fields['title'] = title;
    } else {
      showSnackbar('Title is required');
      return;
    }

    if (description.isNotEmpty) {
      request.fields['description'] = description;
    } else {
      showSnackbar('Description is required');
      return;
    }

    if (videoFile != null) {
      request.files
          .add(await http.MultipartFile.fromPath('videoFile', videoFile!.path));
    } else {
      showSnackbar('Video file is required');
      return;
    }

    if (thumbnailImage != null) {
      request.files.add(
          await http.MultipartFile.fromPath('thumbnail', thumbnailImage!.path));
    } else {
      showSnackbar('Thumbnail is requiured');
      return;
    }

    showPopUpWhileUplaoding();

    request.headers.addAll(headers);

    try {
      http.StreamedResponse response = await request.send();

      if (response.statusCode == 200) {
        logger.d(
            'Your Video Uploaded successfully : ${await response.stream.bytesToString()}');
        if (mounted) {
          setState(() {
            isUploading = false;
            isUploadSuccess = true;
          });
          Navigator.pop(context);
        }
        showPopUpWhileUplaoding();
        clearDataFields();

        if (thumbnailImage != null) {
          await thumbnailImage!.delete();
        }

        if (videoFile != null) {
          await videoFile!.delete();
        }
      } else {
        logger.d('Error in uploading you video - ${response.reasonPhrase}');
        if (mounted) {
          setState(() {
            isUploading = false;
            isUploadSuccess = false;
          });
          Navigator.pop(context);
        }
        showPopUpWhileUplaoding();
        clearDataFields();

        showSnackbar('Failed to upload video. Try again later');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isUploading = false;
          isUploadSuccess = false;
        });
        Navigator.pop(context);
      }
      showPopUpWhileUplaoding();
      clearDataFields();

      logger.e('Error in adding video - $e');
      showSnackbar('Error in uploading video');
    }
  }

  Future<void> updateCoverImage() async {
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

    var url = Uri.parse('$uploadUrl/user/cover-image');

    var request = http.MultipartRequest('PATCH', url);

    if (coverImage != null) {
      request.files.add(
          await http.MultipartFile.fromPath('coverImage', coverImage!.path));
    } else {
      showSnackbar('Cover Image required!!');
      clearDataFields();
    }

    request.headers.addAll(headers);

    try {
      http.StreamedResponse response = await request.send();

      if (response.statusCode == 200) {
        logger.d('Cover Image updated successfully');
        clearDataFields();
        fetchUserDetails(); //For refreshing the page
      } else {
        logger.d('Error in updating Cover image - ${response.reasonPhrase}');
        showSnackbar(
            'Error in updating Cover image - ${response.reasonPhrase}');
      }
    } catch (e) {
      logger.d('Error while updating cover Image - $e');
      showSnackbar('Error occured while updating cover Image');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Video'),
      ),
      body: isLoading
          ? Center(
              child: LoadingAnimationWidget.discreteCircle(
                color: Colors.white,
                size: 50,
                secondRingColor: Colors.indigo.shade900,
                thirdRingColor: Colors.orange.shade800,
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundImage: avatarUrl.isNotEmpty
                              ? NetworkImage(avatarUrl)
                              : null,
                          radius: 20,
                          child: avatarUrl.isEmpty ? Icon(Icons.person) : null,
                        ),
                        SizedBox(width: 10),
                        Text(
                          username!,
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  coverImageUrl.isNotEmpty
                      ? Stack(
                          children: [
                            Image.network(
                              coverImageUrl,
                              height: MediaQuery.of(context).size.height * 0.3,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              top: 8.0, // Adjust position to your preference
                              right: 8.0, // Adjust position to your preference
                              child: GestureDetector(
                                onTap: () {
                                  // Add your edit functionality here
                                  checkAndRequestPermission(3);
                                },
                                child: Container(
                                  padding: EdgeInsets.all(
                                      4.0), // Add padding around the icon
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(
                                        0.6), // Background color with transparency
                                    shape:
                                        BoxShape.circle, // Circular background
                                  ),
                                  child: Icon(
                                    Icons.edit, // Pencil icon for editing
                                    size: 20.0, // Icon size
                                    color: Colors.white, // Icon color
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Container(
                          height: MediaQuery.of(context).size.height * 0.3,
                          color: Colors.grey[700],
                          child: Center(
                            child: GestureDetector(
                              onTap: () {
                                // Add your camera functionality here
                                checkAndRequestPermission(3);
                              },
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.camera_alt,
                                    size: 40,
                                    color: Colors.blue[900],
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Add Cover Image',
                                    style: TextStyle(color: Colors.blue[900]),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: titleController,
                          decoration: InputDecoration(
                            labelText: 'Title',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            if (mounted) {
                              setState(() {
                                title = value;
                              });
                            }
                          },
                        ),
                        SizedBox(height: 16),
                        GestureDetector(
                          onTap: () {
                            // Video selection logic here
                            checkAndRequestPermission(2);
                          },
                          child: Container(
                            height: 75, // Half the thumbnail height
                            width: double.infinity,
                            color: Colors.grey[700],
                            child: Center(
                              child: videoFile == null
                                  ? Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.videocam,
                                          size: 30,
                                          color: Colors.blue[900],
                                        ),
                                        Text('Add Video'),
                                      ],
                                    )
                                  : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.videocam,
                                          size: 30,
                                          color: Colors.blue[900],
                                        ),
                                        Text(
                                          videoName ?? 'Video Uploaded',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        GestureDetector(
                          onTap: () {
                            // Thumbnail selection logic here
                            checkAndRequestPermission(1);
                          },
                          child: Container(
                            height: 150,
                            width: double.infinity,
                            color: Colors.grey[700],
                            child: Center(
                              child: thumbnailImage == null
                                  ? Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.camera_alt,
                                          size: 40,
                                          color: Colors.blue[900],
                                        ),
                                        Text('Select Thumbnail'),
                                      ],
                                    )
                                  : Stack(
                                      children: [
                                        ClipRRect(
                                          child: SizedBox(
                                            height: 150, // Specify a height
                                            width: double
                                                .infinity, // Allow full width
                                            child: Stack(
                                              children: [
                                                // Apply blur to the background if the image is smaller than the box
                                                Positioned.fill(
                                                  child: Image.file(
                                                    thumbnailImage!,
                                                    fit: BoxFit
                                                        .contain, // Ensures the image shrinks to fit within the box without cropping
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top:
                                              8.0, // Adjust position to your preference
                                          right:
                                              8.0, // Adjust position to your preference
                                          child: GestureDetector(
                                            child: Container(
                                              padding: EdgeInsets.all(
                                                  4.0), // Add some padding around the icon
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(
                                                    0.6), // Background color with transparency
                                                shape: BoxShape
                                                    .circle, // Circular background
                                              ),
                                              child: Icon(
                                                Icons.edit, // Pencil icon
                                                size: 20.0, // Icon size
                                                color:
                                                    Colors.white, // Icon color
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        TextField(
                          controller: descriptionController,
                          maxLines: 5,
                          decoration: InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            if (mounted) {
                              setState(() {
                                description = value;
                              });
                            }
                          },
                        ),
                        SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                clearDataFields();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent.shade700,
                                foregroundColor: Colors.white,
                                textStyle: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ).copyWith(backgroundColor:
                                  WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.pressed)) {
                                  return Colors.redAccent.shade100;
                                }
                                return Colors
                                    .redAccent.shade700; // Normal color
                              })),
                              child: Text('Clear'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                publishVideo();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purpleAccent.shade700,
                                foregroundColor: Colors
                                    .white, // Set background color to purple
                                textStyle: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold), // Text style
                              ).copyWith(backgroundColor:
                                  WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.pressed)) {
                                  return Colors.purpleAccent
                                      .shade100; // Lighter shade when pressed
                                }
                                return Colors
                                    .purpleAccent.shade700; // Normal color
                              })),
                              child: Text('Upload'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
