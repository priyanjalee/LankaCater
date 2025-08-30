import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/colors.dart';
import 'package:intl/intl.dart';

import 'customer_home_page.dart';
import 'customer_bookings_page.dart';
import 'customer_profile_page.dart';
import 'chat_page.dart';

class CustomerNotificationsPage extends StatefulWidget {
  const CustomerNotificationsPage({super.key});

  @override
  State<CustomerNotificationsPage> createState() =>
      _CustomerNotificationsPageState();
}

class _CustomerNotificationsPageState
    extends State<CustomerNotificationsPage> {
  final int _selectedIndex = 2;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _listenToUnreadNotifications();
  }

  /// Listen to unread notifications count
  void _listenToUnreadNotifications() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    FirebaseFirestore.instance
        .collection('customers')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _unreadCount = snapshot.docs.length;
        });
      }
    });
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CustomerHomePage()),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CustomerBookingsPage()),
        );
        break;
      case 2:
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CustomerProfilePage()),
        );
        break;
    }
  }

  IconData _getIcon(String type) {
    switch (type) {
      case "booking":
        return Icons.event_available;
      case "reminder":
        return Icons.alarm;
      case "offer":
        return Icons.local_offer;
      case "update":
        return Icons.update;
      case "message":
        return Icons.chat;
      case "payment":
        return Icons.payment;
      case "cancellation":
        return Icons.cancel;
      case "confirmation":
        return Icons.check_circle;
      default:
        return Icons.notifications;
    }
  }

  Color _getColor(String type) {
    switch (type) {
      case "booking":
        return Colors.blueAccent;
      case "reminder":
        return Colors.orangeAccent;
      case "offer":
        return Colors.green;
      case "update":
        return Colors.purpleAccent;
      case "message":
        return Colors.teal;
      case "payment":
        return Colors.indigo;
      case "cancellation":
        return Colors.red;
      case "confirmation":
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "";
    final date = timestamp.toDate();
    
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return "Just now";
    } else if (difference.inMinutes < 60) {
      return "${difference.inMinutes}m ago";
    } else if (difference.inHours < 24) {
      return "${difference.inHours}h ago";
    } else if (difference.inDays < 7) {
      return "${difference.inDays}d ago";
    } else {
      return DateFormat('MMM dd, hh:mm a').format(date);
    }
  }

  /// Create a notification for a customer
  Future<void> _createMessageNotification({
    required String customerId,
    required String chatId,
    required String senderId,
    required String senderName,
    required String messageText,
  }) async {
    await FirebaseFirestore.instance
        .collection('customers')
        .doc(customerId)
        .collection('notifications')
        .add({
      'type': 'message',
      'title': 'New message from $senderName',
      'message': messageText,
      'timestamp': FieldValue.serverTimestamp(),
      'chatId': chatId,
      'senderId': senderId,
      'isRead': false,
      'priority': 'normal',
    });
  }

  /// Send a chat message and create a notification if sender is caterer
  Future<void> sendMessage({
    required String chatId,
    required String otherUserId, // the customer
    required String messageText,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);

    // Add message
    await chatRef.collection('messages').add({
      'senderId': user.uid,
      'text': messageText,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Update chat info
    await chatRef.set({
      'lastMessage': messageText,
      'lastTimestamp': FieldValue.serverTimestamp(),
      'participants': [user.uid, otherUserId],
      'unreadCount_$otherUserId': FieldValue.increment(1),
    }, SetOptions(merge: true));

    // Send notification (assume caterer role)
    bool isCaterer = true; // Replace with your role check if needed
    if (isCaterer) {
      await _createMessageNotification(
        customerId: otherUserId,
        chatId: chatId,
        senderId: user.uid,
        senderName: user.displayName ?? "Caterer",
        messageText: messageText,
      );
    }
  }

  /// Mark notification as read
  Future<void> _markAsRead(String notificationId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('customers')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  /// Delete notification
  Future<void> _deleteNotification(String notificationId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('customers')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .delete();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification deleted'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> _markAllAsRead() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      final notifications = await FirebaseFirestore.instance
          .collection('customers')
          .doc(userId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in notifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  /// Handle notification tap
  void _handleNotificationTap(Map<String, dynamic> notif, String notificationId) {
    final type = notif['type'] ?? '';
    final chatId = notif['chatId'];
    final senderId = notif['senderId'] ?? '';
    final bookingId = notif['bookingId'];

    // Mark as read when tapped
    _markAsRead(notificationId);

    switch (type.toLowerCase()) {
      case "message":
        if (chatId != null && senderId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatPage(
                chatId: chatId,
                otherUserId: senderId,
                otherUserName: _extractCatererName(notif['title'] ?? ''),
                otherUserImage: notif['senderImage'] ?? '',
              ),
            ),
          );
        }
        break;
      case "booking":
      case "confirmation":
      case "cancellation":
        if (bookingId != null) {
          // Navigate to booking details or bookings page
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const CustomerBookingsPage()),
          );
        }
        break;
      case "offer":
        // Navigate to offers page or home page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CustomerHomePage()),
        );
        break;
      default:
        // Handle other notification types as needed
        break;
    }
  }

  /// Extract caterer name from notification title
  String _extractCatererName(String title) {
    if (title.startsWith('New message from ')) {
      return title.replaceFirst('New message from ', '');
    }
    return 'Caterer';
  }

  /// Widget to create notification badge
  Widget _buildNotificationBadge(Widget child, int count) {
    return Stack(
      children: [
        child,
        if (count > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                count > 99 ? '99+' : count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kMaincolor,
        title: const Text(
          "Notifications",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'mark_all_read') {
                _markAllAsRead();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'mark_all_read',
                child: Row(
                  children: [
                    Icon(Icons.done_all, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('Mark all as read'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('customers')
            .doc(userId)
            .collection('notifications')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 80, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading notifications',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data!.docs;

          if (notifications.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_off_outlined,
                      size: 80,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "No Notifications Yet",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "We'll let you know when there's an update\nabout your bookings, reminders, or offers.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final doc = notifications[index];
              final notif = doc.data() as Map<String, dynamic>;
              final notificationId = doc.id;
              
              final type = notif['type'] ?? 'general';
              final title = notif['title'] ?? '';
              final message = notif['message'] ?? '';
              final timestamp = notif['timestamp'];
              final chatId = notif['chatId'];
              final senderId = notif['senderId'] ?? '';
              final isRead = notif['isRead'] ?? false;
              final priority = notif['priority'] ?? 'normal';

              return Dismissible(
                key: Key(notificationId),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.red,
                  child: const Icon(
                    Icons.delete,
                    color: Colors.white,
                  ),
                ),
                onDismissed: (direction) {
                  _deleteNotification(notificationId);
                },
                child: Card(
                  elevation: isRead ? 1 : 3,
                  color: isRead ? Colors.grey.shade50 : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: priority == 'high' 
                        ? BorderSide(color: Colors.red.shade300, width: 1)
                        : BorderSide.none,
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          backgroundColor: _getColor(type).withOpacity(0.2),
                          child: Icon(_getIcon(type), color: _getColor(type)),
                        ),
                        if (!isRead)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Text(
                      title,
                      style: TextStyle(
                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                        color: isRead ? Colors.grey.shade700 : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            message,
                            style: TextStyle(
                              fontSize: 13,
                              color: isRead ? Colors.grey.shade600 : Colors.grey.shade800,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatTimestamp(timestamp),
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                            if (priority == 'high')
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'URGENT',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    trailing: type == 'message' 
                        ? Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.grey.shade400,
                          )
                        : null,
                    onTap: () {
                      if (type == "message" && chatId != null) {
                        _markAsRead(notificationId);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatPage(
                              chatId: chatId,
                              otherUserId: senderId,
                              otherUserName: _extractCatererName(title),
                              otherUserImage: '',
                            ),
                          ),
                        );
                      } else {
                        _handleNotificationTap(notif, notificationId);
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: kMaincolor,
        unselectedItemColor: Colors.grey,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.event_note), label: 'Bookings'),
          BottomNavigationBarItem(
            icon: _buildNotificationBadge(
              const Icon(Icons.notifications),
              _unreadCount,
            ),
            label: 'Alerts',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}