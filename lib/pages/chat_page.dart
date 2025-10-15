import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../constants/colors.dart';

class ChatPage extends StatefulWidget {
  final String chatId;
  final String otherUserName;
  final String otherUserId;
  final String otherUserImage;

  const ChatPage({
    super.key,
    required this.chatId,
    required this.otherUserName,
    required this.otherUserId,
    this.otherUserImage = '',
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();

  bool _isUploading = false;
  String? _cachedBusinessName; // Cache business name to avoid repeated fetches
  bool _hasUnreadMessages = false; // Track unread messages

  @override
  void initState() {
    super.initState();
    _setupFCM();
    _markMessagesAsRead();
    _handleNotificationClick();
    _fetchBusinessName(); // Fetch business name once when page loads
    _listenToUnreadMessages(); // Listen for unread message status
  }

  /// Listen to unread messages to show notification dot
  void _listenToUnreadMessages() {
    final user = _auth.currentUser;
    if (user == null) return;

    _firestore.collection('chats').doc(widget.chatId).snapshots().listen((doc) {
      if (doc.exists && mounted) {
        final data = doc.data()!;
        final unreadCount = data['unreadCount_${user.uid}'] ?? 0;
        setState(() {
          _hasUnreadMessages = unreadCount > 0;
        });
      }
    });
  }

  /// Fetch and cache business name
  Future<void> _fetchBusinessName() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final catererDoc =
          await _firestore.collection('caterers').doc(user.uid).get();
      if (catererDoc.exists && mounted) {
        final data = catererDoc.data()!;
        _cachedBusinessName = data['businessName'] ??
            data['name'] ??
            user.displayName ??
            'Caterer';
      }
    } catch (e) {
      debugPrint('Error fetching business name: $e');
      _cachedBusinessName =
          _auth.currentUser?.displayName ?? 'Caterer';
    }
  }

  /// Get business name (uses cached value or fetches if needed)
  Future<String> _getBusinessName() async {
    if (_cachedBusinessName != null) {
      return _cachedBusinessName!;
    }

    final user = _auth.currentUser;
    if (user == null) return 'Caterer';

    try {
      final catererDoc =
          await _firestore.collection('caterers').doc(user.uid).get();
      if (catererDoc.exists) {
        final data = catererDoc.data()!;
        final businessName = data['businessName'] ??
            data['name'] ??
            user.displayName ??
            'Caterer';
        _cachedBusinessName = businessName; // Cache for future use
        return businessName;
      }
    } catch (e) {
      debugPrint('Error fetching business name: $e');
    }

    return user.displayName ?? 'Caterer';
  }

  /// Setup foreground FCM notifications
  void _setupFCM() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (!mounted) return;
      if (message.notification != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message.notification!.body ?? 'New message'),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    });
  }

  /// Handle tap on notification to open the correct chat
  void _handleNotificationClick() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (!mounted) return;
      final data = message.data;
      if (data.isNotEmpty && data['chatId'] != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChatPage(
              chatId: data['chatId'],
              otherUserId: data['otherUserId'],
              otherUserName: data['otherUserName'],
              otherUserImage: data['otherUserImage'] ?? '',
            ),
          ),
        );
      }
    });
  }

  /// Mark messages as read for this user
  Future<void> _markMessagesAsRead() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('chats').doc(widget.chatId).set({
        'lastRead_${user.uid}': FieldValue.serverTimestamp(),
        'unreadCount_${user.uid}': 0,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  /// Delete a message with proper permissions
  Future<void> _deleteMessage(
      String messageId, String messageType, String? imageUrl) async {
    try {
      // Show confirmation dialog
      final shouldDelete = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Message'),
          content: const Text(
              'Are you sure you want to delete this message? This action cannot be undone.'),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child:
                  Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              // If your Flutter is older, you can change foregroundColor -> primary
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (shouldDelete != true) return;

      final msgRef = _firestore
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc(messageId);

      // Delete the Firestore message first
      await msgRef.delete();

      // If it's an image message, attempt to delete the image from Storage
      if (messageType == 'image' && imageUrl != null && imageUrl.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(imageUrl).delete();
        } catch (e) {
          // Storage delete can fail due to rules or if already deleted; not fatal for UX
          debugPrint('Error deleting image from storage: $e');
        }
      }

      // Update last message in chat
      await _updateLastMessageAfterDeletion();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Message deleted successfully'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Error deleting message: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to delete message'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () =>
                _deleteMessage(messageId, messageType, imageUrl),
          ),
        ),
      );
    }
  }

  /// Update the last message in chat after deletion
  Future<void> _updateLastMessageAfterDeletion() async {
    try {
      final chatRef = _firestore.collection('chats').doc(widget.chatId);
      final messagesSnapshot = await chatRef
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (messagesSnapshot.docs.isNotEmpty) {
        final lastDoc = messagesSnapshot.docs.first;
        final lastMessage = lastDoc.data();
        final messageText = (lastMessage['type'] == 'image')
            ? 'Photo'
            : (lastMessage['text'] ?? '');

        await chatRef.update({
          'lastMessage': messageText,
          'lastTimestamp': lastMessage['timestamp'] ?? FieldValue.serverTimestamp(),
        });
      } else {
        // No messages left in this chat
        await chatRef.update({
          'lastMessage': '',
          'lastTimestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error updating last message: $e');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Create notification for customer when caterer sends message
  Future<void> _createCustomerNotification({
    required String messageText,
    required String messageType,
    String? imageUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Get business name
      final businessName = await _getBusinessName();

      String notificationMessage = messageText;

      // If it's an image message, show appropriate text
      if (messageType == 'image') {
        notificationMessage = 'Photo';
      }

      // Add notification to customer's notifications collection
      await _firestore
          .collection('customers')
          .doc(widget.otherUserId)
          .collection('notifications')
          .add({
        'type': 'message',
        'title': 'New message from $businessName',
        'message': notificationMessage,
        'timestamp': FieldValue.serverTimestamp(),
        'chatId': widget.chatId,
        'senderId': user.uid,
        'senderName': businessName,
        'senderImage': user.photoURL ?? '',
        'isRead': false,
        'priority': 'normal',
        'messageType': messageType,
        if (imageUrl != null) 'imageUrl': imageUrl,
      });
    } catch (e) {
      debugPrint('Error creating customer notification: $e');
    }
  }

  /// Send a text message and create notification for recipient
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final user = _auth.currentUser;
    if (user == null) return;

    final chatRef = _firestore.collection('chats').doc(widget.chatId);
    final messagesRef = chatRef.collection('messages');

    try {
      // Ensure chat document exists and update last message
      await chatRef.set({
        'participants': FieldValue.arrayUnion([user.uid, widget.otherUserId]),
        'lastMessage': text,
        'lastTimestamp': FieldValue.serverTimestamp(),
        'unreadCount_${widget.otherUserId}': FieldValue.increment(1),
      }, SetOptions(merge: true));

      // Add the message
      await messagesRef.add({
        'senderId': user.uid,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'text',
      });

      // Create notification for customer
      await _createCustomerNotification(
        messageText: text,
        messageType: 'text',
      );

      // Get business name for FCM notification
      final businessName = await _getBusinessName();

      // Optional: send FCM push notification
      await _sendNotificationToUser(
        widget.otherUserId,
        "$businessName sent you a message",
        text,
        widget.chatId,
      );

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      debugPrint("Error sending message: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Failed to send message."),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  /// Upload image to Firebase Storage
  Future<String?> _uploadImage(File image) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = FirebaseStorage.instance
          .ref()
          .child('chat_images')
          .child(widget.chatId)
          .child('${user.uid}_$timestamp.jpg');

      final uploadTask = ref.putFile(image);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  /// Send image message
  Future<void> _sendImageMessage(File image) async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isUploading = true);

    try {
      // Upload image to Firebase Storage
      final imageUrl = await _uploadImage(image);
      if (imageUrl == null) {
        throw Exception('Failed to upload image');
      }

      final chatRef = _firestore.collection('chats').doc(widget.chatId);
      final messagesRef = chatRef.collection('messages');

      // Update chat info
      await chatRef.set({
        'participants': FieldValue.arrayUnion([user.uid, widget.otherUserId]),
        'lastMessage': 'Photo',
        'lastTimestamp': FieldValue.serverTimestamp(),
        'unreadCount_${widget.otherUserId}': FieldValue.increment(1),
      }, SetOptions(merge: true));

      // Add the image message
      await messagesRef.add({
        'senderId': user.uid,
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'image',
      });

      // Create notification for customer
      await _createCustomerNotification(
        messageText: 'Sent a photo',
        messageType: 'image',
        imageUrl: imageUrl,
      );

      // Get business name for FCM notification
      final businessName = await _getBusinessName();

      // Send FCM push notification
      await _sendNotificationToUser(
        widget.otherUserId,
        "$businessName sent you a photo",
        'Photo',
        widget.chatId,
      );

      _scrollToBottom();
    } catch (e) {
      debugPrint("Error sending image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Failed to send image."),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  /// Show image picker options
  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Send Image',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildImageSourceOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  source: ImageSource.camera,
                ),
                _buildImageSourceOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  source: ImageSource.gallery,
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required ImageSource source,
  }) {
    return GestureDetector(
      onTap: () async {
        Navigator.pop(context);
        final pickedFile = await _picker.pickImage(
          source: source,
          imageQuality: 70,
          maxWidth: 1024,
          maxHeight: 1024,
        );
        if (pickedFile != null) {
          await _sendImageMessage(File(pickedFile.path));
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kMaincolor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: kMaincolor.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 30, color: kMaincolor),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: kMaincolor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Send FCM push notification to target user
  Future<void> _sendNotificationToUser(
      String toUserId, String title, String body, String chatId) async {
    try {
      final tokenSnapshot =
          await _firestore.collection('users').doc(toUserId).get();
      final token = tokenSnapshot.data()?['fcmToken'];
      if (token == null) return;

      final data = {
        "to": token,
        "notification": {"title": title, "body": body},
        "data": {
          "chatId": chatId,
          "otherUserId": _auth.currentUser!.uid,
          "otherUserName":
              _cachedBusinessName ?? _auth.currentUser!.displayName ?? '',
          "otherUserImage": _auth.currentUser!.photoURL ?? ''
        }
      };

      const serverKey = 'YOUR_FCM_SERVER_KEY_HERE';

      await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$serverKey',
        },
        body: jsonEncode(data),
      );
    } catch (e) {
      debugPrint('Error sending FCM notification: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inDays == 0) {
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $ampm';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }

  Widget _buildMessageBubble({
    required String messageId,
    required String text,
    required bool isMe,
    required Timestamp? timestamp,
    String? imageUrl,
    required String type,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque, // ensure long-press always registers
      onLongPress: isMe
          ? () {
              // Show delete option only for messages sent by the current user
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (context) => Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Message Options',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      ListTile(
                        leading:
                            const Icon(Icons.delete, color: Colors.red),
                        title: const Text('Delete Message',
                            style: TextStyle(color: Colors.red)),
                        onTap: () async {
                          Navigator.pop(context);
                          // Wait a microtask so the sheet fully closes before showing dialog/snackbar
                          await Future<void>.delayed(
                              const Duration(milliseconds: 10));
                          await _deleteMessage(messageId, type, imageUrl);
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              );
            }
          : null,
      child: Align(
        alignment:
            isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: type == 'image'
              ? const EdgeInsets.all(4)
              : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
            minWidth: type == 'image' ? 200 : 0,
          ),
          decoration: BoxDecoration(
            color: isMe ? kMaincolor : Colors.grey.shade200,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft:
                  isMe ? const Radius.circular(16) : const Radius.circular(4),
              bottomRight:
                  isMe ? const Radius.circular(4) : const Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (type == 'image' && imageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Icon(Icons.error, color: Colors.red),
                        ),
                      );
                    },
                  ),
                ),
                if (timestamp != null) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    child: Text(
                      _formatTimestamp(timestamp),
                      style: TextStyle(
                        color: isMe ? Colors.white70 : Colors.black45,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ] else ...[
                Text(
                  text,
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.black87,
                    fontSize: 15,
                  ),
                ),
                if (timestamp != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _formatTimestamp(timestamp),
                    style: TextStyle(
                      color: isMe ? Colors.white70 : Colors.black45,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: kMaincolor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white,
                    backgroundImage: widget.otherUserImage.isNotEmpty
                        ? NetworkImage(widget.otherUserImage)
                        : null,
                    child: widget.otherUserImage.isEmpty
                        ? Icon(Icons.person, color: kMaincolor, size: 20)
                        : null,
                  ),
                ),
                // Notification dot for unread messages
                if (_hasUnreadMessages)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    'Customer',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [kMaincolor, kMaincolor.withOpacity(0.8)],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestore
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: kMaincolor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: kMaincolor,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          "No messages yet",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "Say hello and start the conversation.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final data = doc.data();
                    final messageId = doc.id;
                    final text = (data['text'] ?? '').toString();
                    final imageUrl = data['imageUrl']?.toString();
                    final senderId = (data['senderId'] ?? '').toString();
                    final timestamp = data['timestamp'] as Timestamp?;
                    final type = (data['type'] ?? 'text').toString();
                    final isMe =
                        senderId == (currentUser?.uid ?? '');

                    return Padding(
                      key: ValueKey(messageId),
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: _buildMessageBubble(
                        messageId: messageId,
                        text: text,
                        isMe: isMe,
                        timestamp: timestamp,
                        imageUrl: imageUrl,
                        type: type,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Upload progress indicator
          if (_isUploading)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const CircularProgressIndicator(strokeWidth: 2),
                  const SizedBox(width: 16),
                  Text(
                    'Uploading image...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          // Message input area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Image picker button
                  GestureDetector(
                    onTap: _showImagePicker,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: kMaincolor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.image,
                        color: kMaincolor,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Text input field
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Send button
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: kMaincolor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: kMaincolor.withOpacity(0.3),
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
