import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:vdtube/constants/constants.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const BASE_URL = Constants.baseUrl;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Create TextEditingControllers for email and password
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  //Secure storage instance
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();

  //Variable to track loading state
  bool isLoading = false;

  @override
  void dispose() {
    // Dispose controllers to prevent memory leaks
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  var logger = Logger(
    printer: PrettyPrinter(),
  );

  //API LOGIN METHOD
  Future<void> _login() async {
    // Get the entered text
    String email = _emailController.text;
    String password = _passwordController.text;

    // Log email and password to console
    logger.d('Email: $email');
    logger.d('Password: $password');
    // print('Email: $email');
    // print('Password: $password');

    setState(() {
      isLoading = true;
    });

    String apiUrl = '$BASE_URL/user/login'; //ENDPOINT

    Map<String, String> payload = {'email': email, 'password': password};

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        logger.d('Login successfull: ${response.body}');

        //Extract tokens
        final responseBody = json.decode(response.body);

        String accessToken = responseBody['data']['accessToken'];
        String refreshToken = responseBody['data']['refreshToken'];

        logger.d('Access Token - $accessToken');
        logger.d('Refresh Token - $refreshToken');

        //Saving tokens securely
        await secureStorage.write(key: 'accessToken', value: accessToken);
        await secureStorage.write(key: 'refreshToken', value: refreshToken);

        //Navigating to home screen on successfull Login
        if (mounted) {
          Navigator.pushNamed(context, '/home');
        }
      } else {
        logger.d('Failed to log In: ${response.statusCode}');
      }
    } catch (e) {
      logger.d('Error - $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: const Text(
            'Login', //TITLE TEXT
            textAlign: TextAlign.right, //TEXT ALIGNMENT
            style: TextStyle(
              fontSize: 34.0, // Increase font size
              fontWeight: FontWeight.bold, // Optional: Make it bold
              color: Colors.amber,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Main content
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome Back!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _emailController, // Assign the controller
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email, color: Colors.amber),
                    filled: true,
                    fillColor: Colors.grey[800],
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _passwordController, // Assign the controller
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock, color: Colors.redAccent),
                    filled: true,
                    fillColor: Colors.grey[800],
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey[800],
                    ),
                    onPressed: _login, // Call the login method on press
                    child: const Text('Login'),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/signup');
                  },
                  child: const Text('Don\'t have an account? Sign up'),
                ),
              ],
            ),
          ),

          // Show spinner and blur the background when loading
          if (isLoading)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {}, // Prevent interaction with background
                child: Container(
                  color: Colors.black.withOpacity(0.5), // Dim the background
                  child: Center(
                    child: LoadingAnimationWidget.threeRotatingDots(
                        color: Colors.white, size: 50),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
