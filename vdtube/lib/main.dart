import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vdtube/screens/creator_channel_screen.dart';
import 'package:vdtube/screens/dashboard.dart';
import 'package:vdtube/screens/home_screen.dart';
import 'package:vdtube/screens/liked_video_screen.dart';
import 'package:vdtube/screens/login_screen.dart';
import 'package:vdtube/screens/signup_screen.dart';
import 'package:vdtube/screens/subscribed_users_screen.dart';
import 'package:vdtube/screens/upload_video_screen.dart';
import 'package:vdtube/screens/watch_history_screen.dart';
import 'package:vdtube/utils/splash_screen.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

void main() {
  // Ensure the app is configured with the right system UI overlay style before running
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations and system UI overlay style
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          Brightness.light, // Changed to light for dark theme
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VDTube',
      theme: ThemeData(
        brightness: Brightness.dark, // Dark theme
        appBarTheme: AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
          toolbarHeight: kToolbarHeight,
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
      ),
      navigatorObservers: [routeObserver],
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/addVideo': (context) => const AddVideoScreen(),
        '/watchHistory': (context) => const WatchHistoryScreen(),
        '/likedVideos': (context) => const LikedVideoScreen(),
        '/subscribedChannels': (context) => const SubscribedUsersScreen()
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/channelVideos') {
          final args = settings.arguments as Map<String, String?>;
          final userId = args['userId'];
          final username = args['username'];

          if (userId != null && username != null) {
            return MaterialPageRoute(
              builder: (context) => CreatorChannelScreen(
                userId: userId,
                username: username,
              ),
            );
          }
        } 
        return null;
      },
    );
  }
}
