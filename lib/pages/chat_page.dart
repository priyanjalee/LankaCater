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

  @override
  void initState() {
    super.initState();
    _setupFCM();
    _markMessagesAsRead();
    _handleNotificationClick();
    _fetchBusinessName(); // Fetch business name once when page loads
  }

  /// Fetch and cache business name
  Future<void> _fetchBusinessName() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final catererDoc = await _firestore.collection('caterers').doc(user.uid).get();
      if (catererDoc.exists && mounted) {
        final data = catererDoc.data()!;
        _cachedBusinessName = data['businessName'] ?? data['name'] ?? user.displayName ?? 'Caterer';
      }
    } catch (e) {
      debugPrint('Error fetching business name: $e');
      _cachedBusinessName = _auth.currentUser?.displayName ?? 'Caterer';
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
      final catererDoc = await _firestore.collection('caterers').doc(user.uid).get();
      if (catererDoc.exists) {
        final data = catererDoc.data()!;
        final businessName = data['businessName'] ?? data['name'] ?? user.displayName ?? 'Caterer';
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
      if (message.notification != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message.notification!.body ?? 'New message'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    });
  }

  /// Handle tap on notification to open the correct chat
  void _handleNotificationClick() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
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

    await _firestore.collection('chats').doc(widget.chatId).set({
      'lastRead_${user.uid}': FieldValue.serverTimestamp(),
      'unreadCount_${user.uid}': 0,
    }, SetOptions(merge: true));
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Failed to send message."),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Failed to send image."),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      setState(() => _isUploading = false);
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
        "otherUserName": _cachedBusinessName ?? _auth.currentUser!.displayName ?? '',
        "otherUserImage": _auth.currentUser!.photoURL ?? ''
      }
    };

    const serverKey = 'YOUR_FCM_SERVER_KEY_HERE'; // replace with your key

    try {
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
    required String text,
    required bool isMe,
    required Timestamp? timestamp,
    String? imageUrl,
    required String type,
  }) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
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
            bottomLeft: isMe
                ? const Radius.circular(16)
                : const Radius.circular(4),
            bottomRight: isMe
                ? const Radius.circular(4)
                : const Radius.circular(16),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final d = docs[i].data();
                    final text = (d['text'] ?? '').toString();
                    final imageUrl = d['imageUrl']?.toString();
                    final senderId = (d['senderId'] ?? '').toString();
                    final ts = d['timestamp'] as Timestamp?;
                    final type = (d['type'] ?? 'text').toString();
                    final isMe = currentUser != null && senderId == currentUser.uid;

                    return _buildMessageBubble(
                      text: text,
                      isMe: isMe,
                      timestamp: ts,
                      imageUrl: imageUrl,
                      type: type,
                    );
                  },
                );
              },
            ),
          ),
          if (_isUploading)
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Sending image...',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, -2),
                  )
                ],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _isUploading ? null : _showImagePicker,
                    child: Container(
                      height: 46,
                      width: 46,
                      decoration: BoxDecoration(
                        color: _isUploading 
                            ? Colors.grey[400] 
                            : kMaincolor.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isUploading ? Colors.grey : kMaincolor,
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.image,
                        color: _isUploading ? Colors.grey : kMaincolor,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: null,
                      enabled: !_isUploading,
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _isUploading ? null : _sendMessage,
                    child: Container(
                      height: 46,
                      width: 46,
                      decoration: BoxDecoration(
                        gradient: _isUploading 
                            ? null 
                            : LinearGradient(
                                colors: [kMaincolor, kMaincolor.withOpacity(0.8)],
                              ),
                        color: _isUploading ? Colors.grey[400] : null,
                        shape: BoxShape.circle,
                        boxShadow: !_isUploading ? [
                          BoxShadow(
                            color: kMaincolor.withOpacity(0.3),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ] : null,
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
          )
        ],
      ),
    );
  }
}