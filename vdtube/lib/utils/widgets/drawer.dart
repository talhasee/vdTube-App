import 'package:flutter/material.dart';
import 'package:vdtube/constants/constants.dart';

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
              Navigator.pushNamed(context, '/likedVideos');
            },
          ),
          ListTile(
            leading: Icon(Icons.history),
            title: Text('History'),
            onTap: () {
              // Navigate to the history screen
              Navigator.pushNamed(context, '/history');
            },
          ),
          ListTile(
            leading: Icon(Icons.library_add),
            title: Text('My Content'),
            onTap: () {
              // Navigate to my content screen
              Navigator.pushNamed(context, '/myContent');
            },
          ),
          ListTile(
            leading: Icon(Icons.collections),
            title: Text('Collections'),
            onTap: () {
              // Navigate to collections screen
              Navigator.pushNamed(context, '/collections');
            },
          ),
          ListTile(
            leading: Icon(Icons.subscriptions),
            title: Text('Subscriptions'),
            onTap: () {
              // Navigate to subscriptions screen
              Navigator.pushNamed(context, '/subscriptions');
            },
          ),
          // Log out item at the bottom of the drawer
          Divider(),
          ListTile(
            leading: Icon(Icons.logout),
            title: Text('Log Out'),
            onTap: () async {
              // Log out logic here (can use a method to clear tokens or reset state)
              //Deleting tokens and logging user out
              await Constants.deleteAccessToken();
              await Constants.deleteRefreshToken();
              
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
    );
  }
}
