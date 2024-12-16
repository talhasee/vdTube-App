import 'package:flutter/material.dart';
import 'package:vdtube/constants/constants.dart';

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

  @override
  void initState() {
    super.initState();
    fetchUsername(); // Fetch username asynchronously
  }

  Future<void> fetchUsername() async {
    setState(() async {
      username = await Constants.getUsername();
    });
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
            Text(
              'Welcome back, $username',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Stats Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatBox('Number of Videos', '0'),
                _buildStatBox('Total Views', '0'),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatBox('Subscribers', '0'),
                _buildStatBox('Likes', '0'),
              ],
            ),

            const SizedBox(height: 40), // Gap

            // List Header
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
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Center(
                      child: Text(
                        'Publish',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Center(
                      child: Text(
                        'Title',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Center(
                      child: Text(
                        'Date',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Center(
                      child: Text(
                        'Actions',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Placeholder for future entries
            Expanded(
              child: ListView.builder(
                itemCount: publishStatus.length, // Use list length
                itemBuilder: (context, index) {
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
                            child: Switch(
                              value: publishStatus[index],
                              onChanged: (value) {
                                setState(() {
                                  publishStatus[index] = value;
                                });
                              },
                            ),
                          ),
                          Align(
                            alignment: Alignment.center,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 10.0),
                              child: Icon(
                                Icons.circle,
                                color: publishStatus[index]
                                    ? Colors.green
                                    : Colors.red,
                                size: 20,
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.center,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 10.0),
                              child: Text(
                                'Sample Title'.length > 20
                                    ? 'Sample Title'.substring(0, 20) + '...'
                                    : 'Sample Title',
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
                                '01/01/2024',
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
                },
              ),
            ),
          ],
        ),
      ),
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
