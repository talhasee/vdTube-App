import 'package:flutter/material.dart';
import 'package:vdtube/constants/constants.dart';
import 'package:typewritertext/typewritertext.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

var logger = Constants.logger;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState(); // Use the private state class here
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {

    // Check for tokens
    String? accessToken = await Constants.getAccessToken();
    String? refreshToken = await Constants.getRefreshToken();

    logger.d('LOGIN SUCCESS AUTOMATICALLY... $accessToken\n$refreshToken');

    // Ensure the widget is still mounted before navigating
    if (!mounted) return;

    if (accessToken != null && refreshToken != null) {
      Constants.logger.d('LOGIN SUCCESS AUTOMATICALLY...');
      // Navigate to Home Screen
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      // Navigate to Login Screen
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // Vertically center the widgets
          children: [
            TypeWriter.text(
              'Getting things ready!! 😜',
              duration: const Duration(milliseconds: 50),
              repeat: true,
              textAlign: TextAlign.center, // Ensure it is centered
              style: const TextStyle(
                fontSize: 20.0, // Adjust the font size
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20), // Spacing between widgets
            LoadingAnimationWidget.discreteCircle(
              color: Colors.white,
              size: 50, // Larger loader size for better visibility
              secondRingColor: Colors.black,
              thirdRingColor: Colors.purple,
            ),
          ],
        ),
      ),
    );
  }
}
