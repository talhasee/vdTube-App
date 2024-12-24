import 'package:flutter/material.dart';
import 'package:vdtube/constants/constants.dart';
import 'package:vdtube/screens/home_screen.dart';

// Utility class for Drawer
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Drawer Header (can be customized with a user profile or logo)
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue,
            ),
            child: Text(
              'VDTube',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // List of menu items
          ListTile(
            leading: Icon(Icons.thumb_up),
            title: Text('Liked Videos'),
            onTap: () {
              // Navigate to the liked videos screen
              Navigator.pop(context); // Close the drawer
              Navigator.pushNamed(context, '/likedVideos');
            },
          ),
          ListTile(
            leading: Icon(Icons.history),
            title: Text('History'),
            onTap: () {
              // Navigate to the history screen
              Navigator.pop(context); // Close the drawer
              Navigator.pushNamed(context, '/watchHistory');
            },
          ),
          ListTile(
            leading: Icon(Icons.library_add),
            title: Text('My Content'),
            onTap: () {
              // Navigate to my content screen
              Navigator.pop(context); // Close the drawer
              Navigator.pushNamed(context, '/addVideo');
            },
          ),
          ListTile(
            leading: Icon(Icons.collections),
            title: Text('Dashboard'),
            onTap: () {
              // Navigate to collections screen
              Navigator.pop(context); // Close the drawer
              Navigator.pushNamed(context, '/dashboard');
            },
          ),
          ListTile(
            leading: Icon(Icons.subscriptions),
            title: Text('Subscriptions'),
            onTap: () {
              // Navigate to subscriptions screen
              Navigator.pop(context); // Close the drawer
              Navigator.pushNamed(context, '/subscribedChannels');
            },
          ),
          // Log out item at the bottom of the drawer
          Divider(),

          ListTile(
            leading: Icon(Icons.logout),
            title: Text('Log Out'),
            onTap: () async {
              logger.d('Logout button tapped'); // Debug print
              try {
                // Delete all secure storage keys
                await Constants.deleteAll();

                // Confirm deletion by checking if all keys are removed
                String? accessToken = await Constants.getAccessToken();
                String? refreshToken = await Constants.getRefreshToken();
                String? username = await Constants.getUsername();

                if (accessToken == null &&
                    refreshToken == null &&
                    username == null) {
                  Constants.logger
                      .d('Successfully logged out - All keys cleared.');

                  if (!context.mounted) {
                    logger.d('Not mounted ERROR');
                  }

                  Navigator.pushReplacementNamed(context, '/login');
                } else {
                  Constants.logger
                      .e('Logout failed - Some keys are still present.');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Logout failed. Please try again.')),
                  );
                }
              } catch (e) {
                Constants.logger.e('Error during logout: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text('An error occurred. Please try again later.')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
