import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'dart:convert';
import 'package:vdtube/constants/constants.dart';

const BASE_URL = Constants.baseUrl;
var logger = Constants.logger;
Timer? debounce;

// Comment model class
class Comment {
  final String id;
  final String content;
  final String createdAt;
  int likesCount;
  bool isLiked;

  Comment({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.likesCount,
    required this.isLiked,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['_id'],
      content: json['content'],
      createdAt: json['createdAt'],
      likesCount: json['likesCount'],
      isLiked: json['isLiked'],
    );
  }

  String getFormattedDate() {
    DateTime date = DateTime.parse(createdAt);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays < 1) {
      return 'today';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day(s) ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).round()} week(s) ago';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).round()} month(s) ago';
    } else {
      return '${(difference.inDays / 365).round()} year(s) ago';
    }
  }
}

// CommentService class to fetch comments from the API
class CommentService {
  static Future<List<Comment>> fetchComments(String videoId) async {
    String? accessToken = await Constants.getAccessToken();
    String? refreshToken = await Constants.getRefreshToken();

    var headers = {
      'Cookie': 'accessToken=$accessToken; refreshToken=$refreshToken',
    };

    try {
      var url = Uri.parse('$BASE_URL/comment/$videoId?page=1&limit=10');
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        var data = json.decode(response.body)['data']['docs'];
        List<Comment> comments = (data as List)
            .map((commentJson) => Comment.fromJson(commentJson))
            .toList();

        return comments;
      } else {
        throw Exception('Failed to load comments');
      }
    } catch (e) {
      logger.e('Error in loading comments - $e');
        throw Exception('Failed to load comments');
    }
  }

  // API call to add a new comment
  static Future<void> addComment(String videoId, String content) async {
    String? accessToken = await Constants.getAccessToken();
    String? refreshToken = await Constants.getRefreshToken();

    var headers = {
      'Content-Type': 'application/json',
      'Cookie': 'accessToken=$accessToken; refreshToken=$refreshToken',
    };

    var url = Uri.parse('$BASE_URL/comment/$videoId');
    var request = http.Request('POST', url)
      ..headers.addAll(headers)
      ..body = json.encode({'content': content});

    final response = await request.send();

    if (response.statusCode != 200) {
      throw Exception('Failed to add comment');
    }
  }
}

// StatefulWidget to display the comments
class CommentsWidget extends StatefulWidget {
  final String videoId;

  const CommentsWidget({super.key, required this.videoId});

  @override
  _CommentsWidgetState createState() => _CommentsWidgetState();
}

class _CommentsWidgetState extends State<CommentsWidget> {
  late Future<List<Comment>> _commentsFuture;
  TextEditingController _commentController = TextEditingController();
  List<Comment> _comments = [];

  @override
  void initState() {
    super.initState();
    _commentsFuture = CommentService.fetchComments(widget.videoId);
    _fetchInitialComments();
  }

  @override
  void dispose() {
    debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchInitialComments() async {
    try {
      final comments = await CommentService.fetchComments(widget.videoId);
      if (!mounted) {
        return;
      }

      setState(() {
        _comments.addAll(comments);
      });
    } catch (e) {
      logger.e('Error in adding Comments - $e');
    }
  }

  void _addComment(String content) async {
    if (content.isEmpty) return;

    // Add the new comment locally without waiting for the server response
    final newComment = Comment(
      id: 'temp-id', // Temporary ID until server assigns one
      content: content,
      createdAt: DateTime.now().toString(),
      likesCount: 0,
      isLiked: false,
    );

    setState(() {
      _comments.insert(0, newComment); // Add to the top of the list
    });

    // Send the comment to the backend
    try {
      await CommentService.addComment(widget.videoId, content);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add comment: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TextField(
            controller: _commentController,
            decoration: InputDecoration(
              hintText: 'Write a comment...',
              suffixIcon: IconButton(
                icon: const Icon(Icons.send),
                onPressed: () {
                  _addComment(_commentController.text);
                  _commentController
                      .clear(); // Clear the text field after submitting
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<Comment>>(
          future: _commentsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                  child: LoadingAnimationWidget.staggeredDotsWave(
                color: Colors.blueGrey.shade200,
                size: 40,
              ));
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (snapshot.hasData) {
              final comments = snapshot.data!;
              if (comments.isEmpty && _comments.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Be the first one to comment',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70, // Styled for better appearance
                      ),
                    ),
                  ),
                );
              }

              logger.d('_comments - $_comments\ncomments - $comments');
              // _comments.addAll(comments); // Add fetched comments to the list
              return Column(
                children: [
                  ..._comments.map((comment) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: CommentCard(comment: comment),
                    );
                  }).toList(),
                ],
              );
            } else {
              return const Center(child: Text('Be the first one to comment'));
            }
          },
        ),
      ],
    );
  }
}

// Widget to display individual comment
class CommentCard extends StatelessWidget {
  final Comment comment;

  const CommentCard({super.key, required this.comment});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              comment.getFormattedDate(),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              comment.content,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.thumb_up,
                        color: comment.isLiked ? Colors.blue : Colors.white,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          //Closing already exisiting timer
                          debounce?.cancel();

                          //Starting a new debouncing timer
                          debounce = Timer(const Duration(milliseconds: 5000),
                              () => togglingCommentLike(comment));

                          comment.isLiked = !comment.isLiked;
                          comment.likesCount += comment.isLiked ? 1 : -1;
                        });

                        //Api call for toggling like
                      },
                    ),
                    Text('${comment.likesCount}'),
                  ],
                );
              },
            )
          ],
        ),
      ),
    );
  }
}

Future<void> togglingCommentLike(Comment comment) async {
  final url = '$BASE_URL/like/toggle/c/${comment.id}';

  String? accessToken = await Constants.getAccessToken();
  String? refreshToken = await Constants.getRefreshToken();

  var headers = {
    'Cookie': 'accessToken=$accessToken; refreshToken=$refreshToken',
  };

  try {
    final response = await http.post(Uri.parse(url), headers: headers);

    if (response.statusCode == 200) {
      logger.d('Successfully toggled the Like on comment');
    } else {
      logger.d('Failed to like the comment: ${response.reasonPhrase}');
    }
  } catch (e) {
    logger.e('Error while toggling the like on comment');
  }
}
