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

  void _callNumber(String number) async {
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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kMaincolor,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Caterer Details",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
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
              final doc = await catererRef.get();
              final data = doc.data() as Map<String, dynamic>;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CustomerOrderPage(
                    catererId: catererId,
                    catererName: data['businessName'] ?? '',
                  ),
                ),
              );
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
                // Business Name & Price
                Text(
                  businessName,
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold),
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

                // Contact Info
                _infoTile(Icons.phone, "Contact", contact, action: () {
                  _callNumber(contact);
                }),
                _infoTile(Icons.email, "Email", email),
                _infoTile(Icons.location_on, "Service Area", serviceArea),
                _infoTile(Icons.event, "Event Types", eventTypes),

                const SizedBox(height: 16),

                // Gallery Carousel
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
                            return GestureDetector(
                              onTap: () => _showFullScreenImage(
                                  context, galleryImages[index]),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    galleryImages[index],
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    : const Text("No gallery images available."),

                const SizedBox(height: 16),

                // Menus / Packages - Grid
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

                    if (!menuSnapshot.hasData || menuSnapshot.data!.docs.isEmpty) {
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
                        final menu = menus[index].data() as Map<String, dynamic>;
                        return GestureDetector(
                          onTap: () => menu['imageUrl'] != null
                              ? _showFullScreenImage(context, menu['imageUrl'])
                              : null,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 6,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  menu['imageUrl'] != null
                                      ? ClipRRect(
                                          borderRadius: const BorderRadius.vertical(
                                              top: Radius.circular(12)),
                                          child: Image.network(
                                            menu['imageUrl'],
                                            height: 100,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : Container(
                                          height: 100,
                                          decoration: BoxDecoration(
                                              color: Colors.grey[300],
                                              borderRadius:
                                                  const BorderRadius.vertical(
                                                      top: Radius.circular(12))),
                                          child: const Icon(Icons.restaurant_menu,
                                              size: 40, color: Colors.white),
                                        ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(menu['name'] ?? 'Menu',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        if (menu['description'] != null &&
                                            (menu['description'] as String)
                                                .isNotEmpty)
                                          Text(
                                            menu['description'],
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        const SizedBox(height: 4),
                                        if (menu['price'] != null)
                                          Text(
                                            "Rs. ${menu['price']} / person",
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
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(value),
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
