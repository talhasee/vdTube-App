import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';  // For file storage
import 'package:http/http.dart' as http;
import 'package:vdtube/constants/constants.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';  // Add this import
import 'package:loading_animation_widget/loading_animation_widget.dart';

const BASE_URL = Constants.baseUrl;
var logger = Constants.logger;

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController fullNameController = TextEditingController();
  TextEditingController userNameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController retypePasswordController = TextEditingController();

  File? avatarImage;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  // Check for permission and request if not granted
  Future<void> checkAndRequestPermission() async {
    PermissionStatus status = await Permission.storage.request();

    if (status.isGranted) {
      // Permission granted, proceed with picking the image
      pickAvatarImage();
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
          content: const Text('Please grant permission to access the gallery to upload an avatar image.'),
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
  Future<void> pickAvatarImage() async {
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

      setState(() {
        avatarImage = savedImage; // Set the saved image as the avatar
      });
    }
  }

Future<void> signUpUser() async {
  if (!_formKey.currentState!.validate()) {
    return;
  }

  setState(() {
    _isLoading = true; // Show loader and freeze background
  });

  String? accessToken = await Constants.getAccessToken();
  String? refreshToken = await Constants.getRefreshToken();

  var headers = {
    'Cookie': 'accessToken=$accessToken; refreshToken=$refreshToken'
  };

  var request = http.MultipartRequest(
      'POST', Uri.parse('$BASE_URL/user/register'));

  request.fields.addAll({
    'fullName': fullNameController.text,
    'userName': userNameController.text,
    'email': emailController.text,
    'password': passwordController.text,
  });

  // Attach the image file to the request if available
  if (avatarImage != null) {
    request.files.add(await http.MultipartFile.fromPath(
      'avatar',
      avatarImage!.path,
    ));
  }

  request.headers.addAll(headers);

  try {
    http.StreamedResponse response = await request.send();

    if (response.statusCode == 201) {
      logger.d('Sign up successful');
      logger.d(await response.stream.bytesToString());

      // Delete the temporary image after successful registration
      if (avatarImage != null) {
        await avatarImage!.delete();
      }

      // Show success dialog
      showSuccessDialog();
    } else {
      showErrorDialog('Sign up failed: ${response.reasonPhrase}');
    }
  } catch (e) {
    logger.d('Error during sign up: $e');
    showErrorDialog('An error occurred, please try again.');
  } finally {
    setState(() {
      _isLoading = false; // Hide loader after the process
    });
  }
}

// Show success dialog and navigate to login screen
void showSuccessDialog() {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Registration Successful'),
        content: const Text('You can login now.'),
        actions: <Widget>[
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
              // Navigate to login page after successful registration
              Navigator.pushReplacementNamed(context, '/login'); // Adjust the route as needed
            },
          ),
        ],
      );
    },
  );
}

  // Show error dialog
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
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  // Avatar Image Section
                  GestureDetector(
                    onTap: () async {
                      await checkAndRequestPermission();
                    },
                    child: ClipOval(
                      child: avatarImage != null
                          ? Image.file(
                              avatarImage!,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover, // Fit the image into the circular area
                            )
                          : const Icon(
                              Icons.camera_alt,
                              size: 50,
                              color: Colors.grey,
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Full Name Field
                  TextFormField(
                    controller: fullNameController,
                    decoration: const InputDecoration(labelText: 'Full Name'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your full name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // User Name Field
                  TextFormField(
                    controller: userNameController,
                    decoration: const InputDecoration(labelText: 'User Name'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your username';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Email Field
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")
                          .hasMatch(value)) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Password Field
                  TextFormField(
                    controller: passwordController,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Retype Password Field
                  TextFormField(
                    controller: retypePasswordController,
                    decoration: const InputDecoration(labelText: 'Retype Password'),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please retype your password';
                      }
                      if (value != passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Sign Up Button
                  ElevatedButton(
                    onPressed: signUpUser,
                    child: const Text('Sign Up'),
                  ),
                ],
              ),
            ),
          ),

          // Show loader if _isLoading is true
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: LoadingAnimationWidget.threeRotatingDots(
                  color: Colors.red, size: 50),
              ),
            ),
        ],
      ),
    );
  }
}
