import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'dart:convert';
import 'package:vdtube/constants/constants.dart';

const BASE_URL = Constants.baseUrl;
var logger = Constants.logger;
Timer? debounce;

// Owner model class
class Owner {
  final String userName;
  final String fullName;
  final String avatar;

  Owner({
    required this.userName,
    required this.fullName,
    required this.avatar,
  });

  factory Owner.fromJson(Map<String, dynamic> json) {
    return Owner(
      userName: json['userName'],
      fullName: json['fullName'],
      avatar: json['avatar'],
    );
  }
}

// Comment model class
class Comment {
  final String id;
  String content;
  final String createdAt;
  final Owner owner;
  int likesCount;
  bool isLiked;

  Comment({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.likesCount,
    required this.owner,
    required this.isLiked,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['_id'],
      content: json['content'],
      createdAt: json['createdAt'],
      owner: Owner.fromJson(json['owner']),
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
  final TextEditingController _commentController = TextEditingController();
  List<Comment> _comments = [];
  String currentUsername = '';
  String currentFullName = '';
  String currentAvatarUrl = '';

  @override
  void initState() {
    super.initState();
    _commentsFuture = CommentService.fetchComments(widget.videoId);
    _fetchInitialComments();

    getCurrentUser();
  }

  @override
  void dispose() {
    debounce?.cancel();
    super.dispose();
  }

  Future<void> getCurrentUser() async {
    String? accessToken = await Constants.getAccessToken();
    String? refreshToken = await Constants.getRefreshToken();

    var headers = {
      'Content-Type': 'application/json',
      'Cookie': 'accessToken=$accessToken; refreshToken=$refreshToken',
    };

    final url = Uri.parse('$BASE_URL/user/current-user');

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);

        final data = responseBody['data'];
        if (mounted) {
          setState(() {
            currentUsername = data['userName'];
            currentAvatarUrl = data['avatar'];
            currentFullName = data['fullName'];
          });
        }
      }
    } catch (e) {
      logger.e('Error in getting current user - $e');
    }
  }

  Future<void> _fetchInitialComments() async {
    try {
      final comments = await CommentService.fetchComments(widget.videoId);
      if (!mounted) {
        return;
      }
      if (mounted) {
        setState(() {
          _comments.addAll(comments);
        });
      }
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
      owner: Owner(
          userName: currentUsername,
          fullName: currentFullName,
          avatar: currentAvatarUrl),
    );

    if (mounted) {
      setState(() {
        _comments.insert(0, newComment); // Add to the top of the list
      });
    }

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

class CommentCard extends StatefulWidget {
  final Comment comment;

  const CommentCard({super.key, required this.comment});

  @override
  _CommentCardState createState() => _CommentCardState();
}

class _CommentCardState extends State<CommentCard> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.comment.content);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Function to handle editing the comment
  void _editComment(BuildContext context) async {
    // Show a dialog with a text field to edit the comment
    String newContent = widget.comment.content;
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Edit Comment"),
          content: TextField(
            controller: _controller,
            maxLines: null,
            decoration: const InputDecoration(hintText: 'Edit your comment'),
            onChanged: (value) {
              newContent = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                // Update the comment if it's different
                if (newContent != widget.comment.content) {
                  if(mounted){
                    setState(() {
                      widget.comment.content = newContent;
                    });
                    //api call for updating comment
                    await updateComment(context, widget.comment);
                  }

                }
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundImage:
                          NetworkImage(widget.comment.owner.avatar),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.comment.owner.userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.comment.getFormattedDate(),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                  onPressed: () => _editComment(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              widget.comment.content,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.thumb_up,
                        color:
                            widget.comment.isLiked ? Colors.blue : Colors.white,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          debounce?.cancel();

                          debounce = Timer(const Duration(milliseconds: 300),
                              () => togglingCommentLike(widget.comment));

                          widget.comment.isLiked = !widget.comment.isLiked;
                          widget.comment.likesCount +=
                              widget.comment.isLiked ? 1 : -1;
                        });
                      },
                    ),
                    Text('${widget.comment.likesCount}'),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> updateComment(BuildContext context, Comment comment) async {
  final url = Uri.parse('$BASE_URL/comment/c/${comment.id}');

  String? accessToken = await Constants.getAccessToken();
  String? refreshToken = await Constants.getRefreshToken();

  var headers = {
    'Content-Type': 'application/json',
    'Cookie': 'accessToken=$accessToken; refreshToken=$refreshToken',
  };

  logger.d('Updated comment - ${comment.content}');

  Map<String, String> payload = {'content': comment.content};

  try {
    final response =
        await http.patch(url, headers: headers, body: json.encode(payload));

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment Updated successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Problem while updating comment - ${response.reasonPhrase}')),
      );
    }
  } catch (e) {
    logger.e('Error while updating comment - $e');
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
