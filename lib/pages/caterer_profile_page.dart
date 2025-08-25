// caterer_details_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/colors.dart';
import 'customer_order_page.dart';

class CatererDetailsPage extends StatelessWidget {
  final String catererId;
  const CatererDetailsPage({super.key, required this.catererId});

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

  @override
  Widget build(BuildContext context) {
    final catererRef =
        FirebaseFirestore.instance.collection("caterers").doc(catererId);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: kMaincolor,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Caterer Details",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
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

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final galleryImages = List<String>.from(data['gallery'] ?? []);
          final businessName = data['businessName'] ?? 'Unnamed Caterer';
          final contact = data['contact'] ?? 'N/A';
          final email = data['email'] ?? 'N/A';
          final serviceArea = data['serviceArea'] ?? 'N/A';
          final eventTypes =
              (data['cateredEventTypes'] as List<dynamic>?)?.join(', ') ?? 'N/A';
          final startingPrice = data['startingPrice'] ?? 'N/A';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Caterer Name & Badge ---
                Text(
                  businessName,
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Chip(
                  label: Text("Starting from Rs. $startingPrice / person",
                      style: const TextStyle(color: Colors.white)),
                  backgroundColor: kMaincolor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                const SizedBox(height: 16),

                // --- Contact Info Card ---
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoRow(Icons.phone, "Contact:", contact, isPhone: true),
                        const SizedBox(height: 8),
                        _infoRow(Icons.email, "Email:", email, isEmail: true),
                        const SizedBox(height: 8),
                        _infoRow(Icons.location_on, "Service Area:", serviceArea),
                        const SizedBox(height: 8),
                        _infoRow(Icons.event, "Event Types:", eventTypes),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                const Text(
                  "Gallery",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                galleryImages.isNotEmpty
                    ? SizedBox(
                        height: 180,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: galleryImages.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) => GestureDetector(
                            onTap: () => _showFullScreenImage(
                                context, galleryImages[index]),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                galleryImages[index],
                                width: 180,
                                height: 180,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      )
                    : const Text("No gallery images available."),

                const SizedBox(height: 16),
                const Text(
                  "Menus / Packages",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot>(
                  stream: catererRef.collection("menus").snapshots(),
                  builder: (context, menuSnapshot) {
                    if (menuSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!menuSnapshot.hasData || menuSnapshot.data!.docs.isEmpty) {
                      return const Text("No menus available.");
                    }

                    final menus = menuSnapshot.data!.docs;
                    return Column(
                      children: menus.map((menuDoc) {
                        final menu = menuDoc.data() as Map<String, dynamic>;
                        return Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: menu['imageUrl'] != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      menu['imageUrl'],
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Icon(Icons.restaurant_menu,
                                    size: 50, color: kMaincolor),
                            title: Text(menu['name'] ?? 'Menu',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (menu['description'] != null &&
                                    (menu['description'] as String).isNotEmpty)
                                  Text(menu['description']),
                                if (menu['price'] != null)
                                  Text("Rs. ${menu['price']} / person",
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                              ],
                            ),
                            onTap: menu['imageUrl'] != null
                                ? () => _showFullScreenImage(context, menu['imageUrl'])
                                : null,
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 80), // spacing for button
              ],
            ),
          );
        },
      ),
      bottomSheet: FutureBuilder<DocumentSnapshot>(
        future: catererRef.get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();
          final businessName = (snapshot.data!.data() as Map<String, dynamic>)['businessName'] ?? 'Caterer';
          return Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            color: Colors.white,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kMaincolor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CustomerOrderPage(
                      catererId: catererId,
                      catererName: businessName,
                    ),
                  ),
                );
              },
              child: const Text("Book Now",
                  style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
          );
        },
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value,
      {bool isPhone = false, bool isEmail = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: kMaincolor),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () async {
              if (isPhone && value != 'N/A') {
                final uri = Uri.parse('tel:$value');
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              } else if (isEmail && value != 'N/A') {
                final uri = Uri.parse('mailto:$value');
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              }
            },
            child: RichText(
              text: TextSpan(
                text: "$label ",
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: Colors.black87),
                children: [
                  TextSpan(
                    text: value,
                    style: TextStyle(
                        fontWeight: FontWeight.normal,
                        color: (isPhone || isEmail) && value != 'N/A'
                            ? Colors.blue
                            : Colors.black54,
                        decoration: (isPhone || isEmail) && value != 'N/A'
                            ? TextDecoration.underline
                            : null),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
