import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/colors.dart';
import 'chat_page.dart';

class CatererInboxPage extends StatelessWidget {
  final String catererId;
  const CatererInboxPage({super.key, required this.catererId});

  @override
  Widget build(BuildContext context) {
    final chatsRef = FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: catererId);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kMaincolor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Messages",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: chatsRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final chats = snapshot.data?.docs ?? [];

          // Debug print
          print("Fetched chats: ${chats.map((e) => e.data())}");

          if (chats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No messages yet",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Start a conversation with your customers!",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chatDoc = chats[index];
              final chatData = chatDoc.data() as Map<String, dynamic>? ?? {};
              final participants = List<String>.from(chatData['participants'] ?? []);
              final otherUserId = participants.firstWhere(
                (id) => id != catererId,
                orElse: () => '',
              );

              if (otherUserId.isEmpty) {
                return const SizedBox(); // Skip invalid chat
              }

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
                builder: (context, userSnapshot) {
                  final userData = userSnapshot.data?.data() as Map<String, dynamic>?;

                  final lastMessage = chatData['lastMessage'] ?? '';
                  final timestamp = chatData['lastTimestamp'] as Timestamp?;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundColor: kMaincolor.withOpacity(0.1),
                        backgroundImage: userData != null && userData['profilePic'] != null
                            ? NetworkImage(userData['profilePic'])
                            : null,
                        child: userData == null || userData['profilePic'] == null
                            ? const Icon(Icons.person, color: Colors.grey)
                            : null,
                      ),
                      title: Text(
                        userData?['name'] ?? "Customer",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        lastMessage,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        timestamp != null
                            ? TimeOfDay.fromDateTime(timestamp.toDate()).format(context)
                            : '',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatPage(
                              chatId: chatDoc.id,
                              otherUserName: userData?['name'] ?? "Customer",
                              otherUserId: otherUserId,
                              otherUserImage: userData?['profilePic'] ?? '',
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
