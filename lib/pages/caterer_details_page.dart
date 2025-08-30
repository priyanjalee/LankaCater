import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/colors.dart';
import 'customer_order_page.dart';
import 'chat_page.dart';

class CatererDetailsPage extends StatelessWidget {
  final String catererId;
  final String customerId;
  final Map<String, dynamic> initialData;

  const CatererDetailsPage({
    super.key,
    required this.catererId,
    required this.customerId,
    required this.initialData,
  });

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: InteractiveViewer(
            child: Center(child: Image.network(imageUrl, fit: BoxFit.contain)),
          ),
        ),
      ),
    );
  }

  void _callNumber(String number) async {
    if (number.isEmpty) return;
    final Uri phoneUri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      debugPrint('Could not launch $number');
    }
  }

  @override
  Widget build(BuildContext context) {
    final catererRef =
        FirebaseFirestore.instance.collection("caterers").doc(catererId);

    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

    // Create unique chatId
    final chatId = (currentUserId.hashCode <= catererId.hashCode)
        ? "${currentUserId}_$catererId"
        : "${catererId}_$currentUserId";

    // Get data from initialData if available
    final businessName = initialData['businessName']?.toString() ?? '';
    final distance = initialData['distance'] as double?;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kMaincolor,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          businessName.isNotEmpty ? businessName : "Caterer Details",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream:
                FirebaseFirestore.instance.collection('chats').doc(chatId).snapshots(),
            builder: (context, snapshot) {
              bool hasUnread = false;

              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                final lastRead = data["lastRead_$currentUserId"];
                final lastTimestamp = data["lastTimestamp"];

                if (lastTimestamp != null &&
                    (lastRead == null || (lastRead as Timestamp).compareTo(lastTimestamp) < 0)) {
                  hasUnread = true;
                }
              }

              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chat),
                    onPressed: () async {
                      try {
                        final doc = await catererRef.get();
                        final data = doc.data();

                        if (data == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Caterer data not found.')),
                          );
                          return;
                        }

                        final otherUserName =
                            data['businessName']?.toString() ?? (businessName.isNotEmpty ? businessName : 'Caterer');
                        final otherUserImage = data['logoUrl']?.toString() ?? '';

                        if (currentUserId.isEmpty || catererId.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Invalid user IDs.')),
                          );
                          return;
                        }

                        final chatRef =
                            FirebaseFirestore.instance.collection('chats').doc(chatId);

                        await chatRef.set({
                          'participants': [currentUserId, catererId],
                          'lastMessage': '',
                          'lastTimestamp': FieldValue.serverTimestamp(),
                        }, SetOptions(merge: true));

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatPage(
                              chatId: chatId,
                              otherUserName: otherUserName,
                              otherUserId: catererId,
                              otherUserImage: otherUserImage,
                            ),
                          ),
                        );
                      } catch (e) {
                        debugPrint('Error opening chat: $e');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to open chat.')),
                        );
                      }
                    },
                  ),
                  if (hasUnread)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        height: 10,
                        width: 10,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              );
            },
          )
        ],
      ),
      bottomNavigationBar: SizedBox(
        height: 70,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.shopping_cart, color: Colors.white),
            label: const Text(
              "Book Now",
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: kMaincolor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              try {
                final doc = await catererRef.get();
                final data = doc.data();
                if (data == null) return;

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CustomerOrderPage(
                      catererId: catererId,
                      catererName: data['businessName']?.toString() ?? businessName,
                    ),
                  ),
                );
              } catch (e) {
                debugPrint('Error booking: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to book order.')),
                );
              }
            },
          ),
        ),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: catererRef.get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Caterer not found."));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>?;

          if (data == null) {
            return const Center(child: Text("Caterer data is empty."));
          }

          final galleryImages = List<String>.from(data['gallery'] ?? []);
          final firestoreBusinessName =
              data['businessName']?.toString() ?? 'Unnamed Caterer';
          final displayBusinessName = businessName.isNotEmpty ? businessName : firestoreBusinessName;
          final contact = data['contact']?.toString() ?? '';
          final email = data['email']?.toString() ?? '';
          final serviceArea = data['serviceArea']?.toString() ?? '';
          final eventTypes =
              ((data['cateredEventTypes'] as List<dynamic>?)?.join(', ')) ?? '';
          final startingPrice = data['startingPrice']?.toString() ?? 'N/A';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Business Name and Distance
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayBusinessName,
                        style: const TextStyle(
                            fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (distance != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: kMaincolor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: kMaincolor),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on, color: kMaincolor, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              "${distance.toStringAsFixed(1)} km away",
                              style: TextStyle(
                                color: kMaincolor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "Starting Price: Rs. $startingPrice / person",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: kMaincolor),
                ),
                const SizedBox(height: 16),

                _infoTile(Icons.phone, "Contact", contact,
                    action:
                        contact.isNotEmpty ? () => _callNumber(contact) : null),
                _infoTile(Icons.email, "Email", email),
                _infoTile(Icons.location_on, "Service Area", serviceArea),
                _infoTile(Icons.event, "Event Types", eventTypes),

                const SizedBox(height: 16),

                const Text("Gallery",
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                galleryImages.isNotEmpty
                    ? SizedBox(
                        height: 200,
                        child: PageView.builder(
                          itemCount: galleryImages.length,
                          controller: PageController(viewportFraction: 0.8),
                          itemBuilder: (context, index) {
                            final imageUrl = galleryImages[index];
                            return GestureDetector(
                              onTap: () =>
                                  _showFullScreenImage(context, imageUrl),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.broken_image,
                                          size: 40),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    : const Text("No gallery images available."),

                const SizedBox(height: 16),

                const Text("Menus / Packages",
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot>(
                  stream: catererRef.collection("menus").snapshots(),
                  builder: (context, menuSnapshot) {
                    if (menuSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!menuSnapshot.hasData ||
                        menuSnapshot.data!.docs.isEmpty) {
                      return const Text("No menus available.");
                    }

                    final menus = menuSnapshot.data!.docs;

                    return GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.85,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: menus.length,
                      itemBuilder: (context, index) {
                        final menu =
                            menus[index].data() as Map<String, dynamic>? ?? {};
                        final menuName = menu['name']?.toString() ?? 'Menu';
                        final menuDesc = menu['description']?.toString() ?? '';
                        final menuPrice = menu['price']?.toString() ?? '';
                        final menuImage = menu['imageUrl']?.toString() ?? '';

                        return GestureDetector(
                          onTap: menuImage.isNotEmpty
                              ? () => _showFullScreenImage(context, menuImage)
                              : null,
                          child: Card(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                menuImage.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                                top: Radius.circular(12)),
                                        child: Image.network(
                                          menuImage,
                                          height: 100,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                            height: 100,
                                            color: Colors.grey[300],
                                            child: const Icon(
                                                Icons.broken_image, size: 40),
                                          ),
                                        ),
                                      )
                                    : Container(
                                        height: 100,
                                        decoration: BoxDecoration(
                                            color: Colors.grey[300],
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                    top: Radius.circular(12))),
                                        child: const Icon(
                                            Icons.restaurant_menu,
                                            size: 40,
                                            color: Colors.white),
                                      ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(menuName,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      if (menuDesc.isNotEmpty)
                                        Text(
                                          menuDesc,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style:
                                              const TextStyle(fontSize: 12),
                                        ),
                                      if (menuPrice.isNotEmpty)
                                        Text(
                                          "Rs. $menuPrice / person",
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: kMaincolor),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoTile(IconData icon, String title, String value,
      {VoidCallback? action}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: kMaincolor),
        title:
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(value.isNotEmpty ? value : 'N/A'),
        trailing: action != null
            ? ElevatedButton(
                onPressed: action,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kMaincolor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Icon(Icons.call, color: Colors.white),
              )
            : null,
      ),
    );
  }
}