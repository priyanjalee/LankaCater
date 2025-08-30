// customer_bookings_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/colors.dart';

// Import other pages
import 'customer_home_page.dart';
import 'customer_notifications_page.dart';
import 'customer_profile_page.dart';
import 'caterer_home_page.dart';

class CustomerBookingsPage extends StatefulWidget {
  const CustomerBookingsPage({super.key});

  @override
  State<CustomerBookingsPage> createState() => _CustomerBookingsPageState();
}

class _CustomerBookingsPageState extends State<CustomerBookingsPage> {
  int _selectedIndex = 1; // Bookings tab active

  // Store ratings & review controllers per booking
  final Map<String, double> _ratings = {};
  final Map<String, TextEditingController> _reviewControllers = {};

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CustomerHomePage()),
        );
        break;
      case 1:
        // Already on Bookings page
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CustomerNotificationsPage()),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CustomerProfilePage()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text("You must be logged in to view bookings."),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kMaincolor,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "My Bookings",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('customerId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final bookings = snapshot.data!.docs;
          if (bookings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_busy,
                    size: 100,
                    color: kMaincolor.withOpacity(0.5),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "No bookings found",
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "You haven't made any bookings yet.\nStart exploring caterers and place your first order!",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.black45),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kMaincolor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const CustomerHomePage()),
                      );
                    },
                    child: const Text(
                      "Explore Caterers",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final data = bookings[index].data() as Map<String, dynamic>;
              final bookingId = bookings[index].id;
              final catererId = data['catererId'] ?? '';
              final catererName = data['catererName'] ?? 'Unknown Caterer';
              final catererContact = data['catererContact'] ?? 'N/A';
              final eventDate = data['eventDate'] ?? 'N/A';
              final eventType = data['eventType'] ?? 'N/A';
              final guestCount = data['noOfPax']?.toString() ?? 'N/A';
              final menu = data['menu'] ?? 'N/A';
              final notes = data['message'] ?? '';
              final status = data['status'] ?? 'Pending';
              final paymentStatus = data['paymentStatus'] ?? 'Unpaid';

              final rating = _ratings[bookingId] ?? 0.0;
              final reviewController =
                  _reviewControllers[bookingId] ??= TextEditingController();

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 8,
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [Colors.white, Colors.grey.shade50],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 2,
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Caterer Name & Contact
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            catererName,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            catererContact,
                            style:
                                const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Event Details
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _iconInfo(Icons.event, eventType),
                          _iconInfo(Icons.date_range, eventDate),
                          _iconInfo(Icons.people, guestCount),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Menu
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "Menu: $menu",
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),

                      // Notes
                      if (notes.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "Notes: $notes",
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),

                      // Status & Payment badges
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _statusBadge(status),
                          _paymentBadge(paymentStatus),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Rating & Review (only if completed)
                      if (status == "Completed") ...[
                        const Divider(),
                        const SizedBox(height: 8),
                        const Text(
                          "Rate this Caterer",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: List.generate(5, (starIndex) {
                            return IconButton(
                              onPressed: () {
                                setState(() {
                                  _ratings[bookingId] = starIndex + 1.0;
                                });
                              },
                              icon: Icon(
                                rating >= starIndex + 1
                                    ? Icons.star
                                    : Icons.star_border,
                                color: Colors.amber,
                              ),
                            );
                          }),
                        ),
                        TextField(
                          controller: reviewController,
                          decoration: const InputDecoration(
                            hintText: "Write a review (optional)",
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kMaincolor,
                          ),
                          onPressed: () async {
                            await FirebaseFirestore.instance
                                .collection('reviews')
                                .add({
                              'bookingId': bookingId,
                              'catererId': catererId,
                              'customerId': user.uid,
                              'rating': rating,
                              'review': reviewController.text.trim(),
                              'timestamp': Timestamp.now(),
                            });

                            reviewController.clear();
                            setState(() {
                              _ratings[bookingId] = 0.0;
                            });

                            // Navigate to Caterer Home Page
                            if (context.mounted) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CatererHomePage(),
                                ),
                              );
                            }
                          },
                          child: const Text("Submit Rating"),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: kMaincolor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.event_note), label: 'Bookings'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Alerts'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  // Helper Widgets
  Widget _iconInfo(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: kMaincolor),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _statusBadge(String status) {
    Color bgColor;
    Color textColor;
    switch (status) {
      case "Pending":
        bgColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        break;
      case "Confirmed":
        bgColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        break;
      case "Completed":
        bgColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        break;
      default:
        bgColor = Colors.grey.shade200;
        textColor = Colors.grey.shade600;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
            color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  Widget _paymentBadge(String paymentStatus) {
    Color bgColor;
    Color textColor;
    if (paymentStatus == "Paid") {
      bgColor = Colors.green.shade100;
      textColor = Colors.green.shade800;
    } else {
      bgColor = Colors.red.shade100;
      textColor = Colors.red.shade800;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        paymentStatus,
        style: TextStyle(
            color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }
}
