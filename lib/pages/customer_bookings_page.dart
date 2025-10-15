// customer_bookings_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/colors.dart';

// Import other pages
import 'customer_home_page.dart';
import 'customer_notifications_page.dart';
import 'customer_profile_page.dart';

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

  Future<void> _deleteBooking(String bookingId) async {
    try {
      // Show confirmation dialog
      bool? shouldDelete = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
                SizedBox(width: 8),
                Text('Delete Booking'),
              ],
            ),
            content: const Text('Are you sure you want to delete this booking? This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                ),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Delete'),
              ),
            ],
          );
        },
      );

      if (shouldDelete == true) {
        // Delete from Firestore
        await FirebaseFirestore.instance
            .collection('bookings')
            .doc(bookingId)
            .delete();

        // Clean up local data
        _ratings.remove(bookingId);
        _reviewControllers[bookingId]?.dispose();
        _reviewControllers.remove(bookingId);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Booking deleted successfully'),
                ],
              ),
              backgroundColor: Colors.green[600],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed to delete booking: $e')),
              ],
            ),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
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
        elevation: 4,
      ),
      backgroundColor: const Color(0xFFF8F9FA),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('customerId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text("Error: ${snapshot.error}",
                      style: TextStyle(color: Colors.red[600])),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: kMaincolor),
                  const SizedBox(height: 16),
                  Text(
                    "Loading your bookings...",
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          final bookings = snapshot.data!.docs;
          if (bookings.isEmpty) {
            return _emptyStateUI();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final data = bookings[index].data() as Map<String, dynamic>;
              final bookingId = bookings[index].id;

              final catererName = data['catererName'] ?? '';
              final catererContact = data['catererContact'] ?? '';
              final eventDate = data['eventDate'] ?? '';
              final eventType = data['eventType'] ?? '';
              final guestCount = data['noOfPax']?.toString() ?? '';
              final notes = data['message'] ?? '';
              final status = data['status'] ?? 'Pending';
              final paymentStatus = data['paymentStatus'] ?? 'Unpaid';

              final rating = _ratings[bookingId] ?? 0.0;
              final reviewController =
                  _reviewControllers[bookingId] ??= TextEditingController();

              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with gradient background
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [kMaincolor.withOpacity(0.1), Colors.white],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Caterer Avatar
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: kMaincolor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.restaurant_menu,
                              color: kMaincolor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Caterer Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (catererName.isNotEmpty)
                                  Text(
                                    catererName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2D3748),
                                    ),
                                  ),
                                if (catererContact.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.phone_outlined,
                                        size: 16,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        catererContact,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Status and Delete
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _statusBadge(status),
                              if (status == 'Pending') ...[
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: () => _deleteBooking(bookingId),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Content
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Event Details Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.event_note,
                                      size: 18,
                                      color: kMaincolor,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      "Event Details",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Color(0xFF2D3748),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _enhancedInfoRow(Icons.celebration_outlined, "Event Type", eventType),
                                _enhancedInfoRow(Icons.calendar_today_outlined, "Date", eventDate),
                                _enhancedInfoRow(Icons.people_outline, "Guests", "$guestCount people"),
                              ],
                            ),
                          ),

                          // Notes Section (if available)
                          if (notes.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.amber.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.note_outlined,
                                        size: 18,
                                        color: Colors.amber[700],
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Special Notes",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.amber[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    notes,
                                    style: TextStyle(
                                      color: Colors.amber[800],
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // Payment Status
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _paymentBadge(paymentStatus),
                            ],
                          ),

                          // Ratings Section for Completed Orders
                          if (status == "Completed") ...[
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blue.withOpacity(0.05),
                                    Colors.white,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.blue.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.star_outline,
                                        size: 20,
                                        color: Colors.blue[700],
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Rate this Caterer",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.blue[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: List.generate(5, (starIndex) {
                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _ratings[bookingId] = starIndex + 1.0;
                                          });
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.only(right: 6),
                                          child: Icon(
                                            rating >= starIndex + 1
                                                ? Icons.star
                                                : Icons.star_border,
                                            color: Colors.amber[600],
                                            size: 28,
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: reviewController,
                                    decoration: InputDecoration(
                                      hintText: "Share your experience (optional)",
                                      hintStyle: TextStyle(color: Colors.grey[500]),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey[300]!),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: kMaincolor, width: 2),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey[300]!),
                                      ),
                                      contentPadding: const EdgeInsets.all(16),
                                      fillColor: Colors.white,
                                      filled: true,
                                    ),
                                    maxLines: 3,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(height: 16),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: kMaincolor,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20, vertical: 12),
                                        elevation: 0,
                                      ),
                                      onPressed: () async {
                                        if (reviewController.text.trim().isEmpty &&
                                            rating == 0.0) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: const Row(
                                                children: [
                                                  Icon(Icons.info_outline, color: Colors.white, size: 20),
                                                  SizedBox(width: 8),
                                                  Text("Please provide a rating or review."),
                                                ],
                                              ),
                                              backgroundColor: Colors.orange[600],
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              margin: const EdgeInsets.all(16),
                                            ),
                                          );
                                          return;
                                        }

                                        try {
                                          await FirebaseFirestore.instance
                                              .collection('reviews')
                                              .add({
                                            'bookingId': bookingId,
                                            'customerId': user.uid,
                                            'rating': rating,
                                            'review': reviewController.text.trim(),
                                            'timestamp': Timestamp.now(),
                                          });

                                          reviewController.clear();
                                          setState(() {
                                            _ratings[bookingId] = 0.0;
                                          });

                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: const Row(
                                                  children: [
                                                    Icon(Icons.check_circle, color: Colors.white, size: 20),
                                                    SizedBox(width: 8),
                                                    Text("Review submitted successfully!"),
                                                  ],
                                                ),
                                                backgroundColor: Colors.green[600],
                                                behavior: SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                margin: const EdgeInsets.all(16),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Row(
                                                children: [
                                                  const Icon(Icons.error_outline, color: Colors.white, size: 20),
                                                  const SizedBox(width: 8),
                                                  Expanded(child: Text("Failed to submit review: $e")),
                                                ],
                                              ),
                                              backgroundColor: Colors.red[600],
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              margin: const EdgeInsets.all(16),
                                            ),
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.send, size: 16),
                                      label: const Text(
                                        "Submit Rating",
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
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
        unselectedItemColor: Colors.grey[600],
        backgroundColor: Colors.white,
        elevation: 12,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.event_note), label: 'Bookings'),
          BottomNavigationBarItem(
              icon: Icon(Icons.notifications), label: 'Alerts'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _enhancedInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: kMaincolor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: kMaincolor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2D3748),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color bgColor;
    Color textColor;
    IconData icon;
    
    switch (status) {
      case "Pending":
        bgColor = Colors.orange.withOpacity(0.15);
        textColor = Colors.orange[700]!;
        icon = Icons.access_time;
        break;
      case "Confirmed":
        bgColor = Colors.green.withOpacity(0.15);
        textColor = Colors.green[700]!;
        icon = Icons.check_circle_outline;
        break;
      case "Completed":
        bgColor = Colors.blue.withOpacity(0.15);
        textColor = Colors.blue[700]!;
        icon = Icons.done_all;
        break;
      default:
        bgColor = Colors.grey.withOpacity(0.15);
        textColor = Colors.grey[700]!;
        icon = Icons.help_outline;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentBadge(String paymentStatus) {
    Color bgColor;
    Color textColor;
    IconData icon;
    
    if (paymentStatus == "Paid") {
      bgColor = Colors.green.withOpacity(0.15);
      textColor = Colors.green[700]!;
      icon = Icons.check_circle;
    } else {
      bgColor = Colors.red.withOpacity(0.15);
      textColor = Colors.red[700]!;
      icon = Icons.payment;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            paymentStatus,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyStateUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: kMaincolor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(60),
              ),
              child: Icon(
                Icons.event_busy,
                size: 60,
                color: kMaincolor.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "No bookings found",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "You haven't made any bookings yet.\nStart exploring caterers and place your first order!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: kMaincolor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const CustomerHomePage()),
                );
              },
              icon: const Icon(Icons.explore),
              label: const Text(
                "Explore Caterers",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Clean up controllers
    for (var controller in _reviewControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}