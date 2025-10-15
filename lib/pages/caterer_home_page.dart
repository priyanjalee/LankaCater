import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../constants/colors.dart';
import 'choose_role_page.dart';
import 'caterer_profile_page.dart';
import 'orders_page.dart';
import 'event_page.dart';
import 'manage_menu_page.dart';
import 'manage_gallery_page.dart';
import 'caterer_inbox_page.dart';

class CatererHomePage extends StatefulWidget {
  const CatererHomePage({super.key});

  @override
  State<CatererHomePage> createState() => _CatererHomePageState();
}

class _CatererHomePageState extends State<CatererHomePage> {
  String? businessName;
  int _selectedIndex = 0;
  List<Map<String, dynamic>> reviews = [];
  double averageRating = 0.0;
  bool hasUnreadMessages = false;

  @override
  void initState() {
    super.initState();
    _fetchCatererData();
    _fetchReviews();
    _checkUnreadMessages();
  }

  Future<void> _fetchCatererData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('caterers')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          setState(() {
            businessName = doc['businessName'] ?? 'Caterer';
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching caterer data: $e");
    }
  }

  Future<void> _checkUnreadMessages() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Check for unread messages where the caterer is the receiver
      QuerySnapshot unreadSnapshot = await FirebaseFirestore.instance
          .collection('messages')
          .where('receiverId', isEqualTo: user.uid)
          .where('isRead', isEqualTo: false)
          .limit(1)
          .get();

      setState(() {
        hasUnreadMessages = unreadSnapshot.docs.isNotEmpty;
      });
    } catch (e) {
      debugPrint("Error checking unread messages: $e");
    }
  }

  Future<void> _fetchReviews() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Fetch all bookings for this caterer
      QuerySnapshot bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('catererId', isEqualTo: user.uid)
          .get();

      final bookingIds =
          bookingsSnapshot.docs.map((doc) => doc.id).toList();

      if (bookingIds.isEmpty) return;

      List<Map<String, dynamic>> fetchedReviews = [];

      // Firestore whereIn allows max 10 elements
      const int chunkSize = 10;
      for (var i = 0; i < bookingIds.length; i += chunkSize) {
        final chunk = bookingIds.sublist(
          i,
          i + chunkSize > bookingIds.length ? bookingIds.length : i + chunkSize,
        );

        final reviewsSnapshot = await FirebaseFirestore.instance
            .collection('reviews')
            .where('bookingId', whereIn: chunk)
            .get();

        // Fetch customer details for each review
        for (var reviewDoc in reviewsSnapshot.docs) {
          final reviewData = reviewDoc.data();
          reviewData['timestamp'] = reviewData['timestamp'] ?? Timestamp.now();
          
          // Get customer name from the booking
          final bookingId = reviewData['bookingId'];
          try {
            DocumentSnapshot bookingDoc = await FirebaseFirestore.instance
                .collection('bookings')
                .doc(bookingId)
                .get();
            
            if (bookingDoc.exists) {
              final bookingData = bookingDoc.data() as Map<String, dynamic>;
              final customerId = bookingData['customerId'];
              
              // Get customer details
              if (customerId != null) {
                DocumentSnapshot customerDoc = await FirebaseFirestore.instance
                    .collection('customers')
                    .doc(customerId)
                    .get();
                
                if (customerDoc.exists) {
                  final customerData = customerDoc.data() as Map<String, dynamic>;
                  reviewData['customerName'] = customerData['name'] ?? 'Unknown Customer';
                } else {
                  reviewData['customerName'] = 'Unknown Customer';
                }
              } else {
                reviewData['customerName'] = 'Unknown Customer';
              }
            } else {
              reviewData['customerName'] = 'Unknown Customer';
            }
          } catch (e) {
            debugPrint("Error fetching customer name: $e");
            reviewData['customerName'] = 'Unknown Customer';
          }
          
          fetchedReviews.add(reviewData);
        }
      }

      // Sort reviews by timestamp descending
      fetchedReviews.sort((a, b) {
        final t1 = a['timestamp'] as Timestamp;
        final t2 = b['timestamp'] as Timestamp;
        return t2.compareTo(t1);
      });

      // Calculate average rating
      double total = 0;
      for (var r in fetchedReviews) {
        total += (r['rating'] ?? 0).toDouble();
      }
      double avg = fetchedReviews.isNotEmpty ? total / fetchedReviews.length : 0.0;

      setState(() {
        reviews = fetchedReviews;
        averageRating = avg;
      });
    } catch (e) {
      debugPrint("Error fetching reviews: $e");
    }
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;

    setState(() => _selectedIndex = index);

    switch (index) {
      case 0:
        break; // Already on Home
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OrdersPage()),
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EventsPage()),
        );
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CatererProfilePage()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: kMaincolor,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ChooseRolePage()),
            );
          },
        ),
        title: Text(
          businessName != null ? "Welcome, $businessName" : "Welcome Caterer",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.chat, color: Colors.white),
                onPressed: () async {
                  final catererId = FirebaseAuth.instance.currentUser!.uid;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CatererInboxPage(catererId: catererId),
                    ),
                  );
                  // Check for unread messages when returning from chat
                  _checkUnreadMessages();
                },
              ),
              if (hasUnreadMessages)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: const Text(
                      '',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _quickActionsCard(),
            const SizedBox(height: 16),
            if (reviews.isNotEmpty) ...[
              _sectionTitle("Customer Reviews"),
              const SizedBox(height: 16),
              _buildRatingOverview(),
              const SizedBox(height: 20),
              _buildRecentReviews(),
            ],
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: kMaincolor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_bag), label: "Orders"),
          BottomNavigationBarItem(icon: Icon(Icons.event), label: "Events"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }

  Widget _quickActionsCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Quick Actions",
          style: TextStyle(
            color: kMaincolor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 3 / 4,
          children: [
            _quickActionButton(
              icon: Icons.shopping_bag,
              title: "Orders",
              page: const OrdersPage(),
              description: "View and manage all customer orders efficiently.",
            ),
            _quickActionButton(
              icon: Icons.event,
              title: "Events",
              page: const EventsPage(),
              description: "Plan, track, and organize catering events.",
            ),
            _quickActionButton(
              icon: Icons.menu_book,
              title: "Manage Menus",
              page: const ManageMenuPage(),
              description: "Add or edit your menus for customers to explore.",
            ),
            _quickActionButton(
              icon: Icons.photo_library,
              title: "Manage Gallery",
              page: const ManageGalleryPage(),
              description: "Upload and showcase photos of your dishes.",
            ),
          ],
        ),
      ],
    );
  }

  Widget _quickActionButton({
    required IconData icon,
    required String title,
    required Widget page,
    required String description,
  }) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => page),
      ),
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        decoration: BoxDecoration(
          color: kMaincolor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: kMaincolor.withOpacity(0.15),
              child: Icon(icon, size: 28, color: kMaincolor),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: kMaincolor,
      ),
    );
  }

  Widget _buildRatingOverview() {
    // Calculate rating distribution
    Map<int, int> ratingCount = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (var review in reviews) {
      int rating = (review['rating'] ?? 0).round();
      if (rating >= 1 && rating <= 5) {
        ratingCount[rating] = (ratingCount[rating] ?? 0) + 1;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kMaincolor.withOpacity(0.05),
            kMaincolor.withOpacity(0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kMaincolor.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: kMaincolor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          // Overall rating section - made more compact
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  children: [
                    Text(
                      averageRating.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: kMaincolor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildStarRating(averageRating, size: 20),
                    const SizedBox(height: 4),
                    Text(
                      "${reviews.length} Reviews",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Rating breakdown - made more compact
          Column(
            children: [
              for (int star = 5; star >= 1; star--)
                _buildRatingBar(star, ratingCount[star] ?? 0, reviews.length),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStarRating(double rating, {double size = 24}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return Icon(Icons.star, color: Colors.amber, size: size);
        } else if (index < rating) {
          return Icon(Icons.star_half, color: Colors.amber, size: size);
        } else {
          return Icon(Icons.star_border, color: Colors.amber, size: size);
        }
      }),
    );
  }

  Widget _buildRatingBar(int stars, int count, int total) {
    double percentage = total > 0 ? count / total : 0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 12,
            child: Text(
              "$stars",
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.star, color: Colors.amber, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: percentage,
                child: Container(
                  decoration: BoxDecoration(
                    color: kMaincolor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 24,
            child: Text(
              "$count",
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentReviews() {
    final recentReviews = reviews.take(5).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Recent Reviews",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kMaincolor,
              ),
            ),
            if (reviews.length > 5)
              TextButton(
                onPressed: () {
                  // Navigate to all reviews page
                },
                child: Text(
                  "View All",
                  style: TextStyle(color: kMaincolor),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: recentReviews.length,
          itemBuilder: (context, index) {
            final review = recentReviews[index];
            return _buildReviewCard(review);
          },
        ),
      ],
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final rating = (review['rating'] ?? 0).toDouble();
    final reviewText = review['review'] ?? '';
    final timestamp = review['timestamp'] as Timestamp?;
    final date = timestamp != null ? timestamp.toDate() : DateTime.now();
    final customerName = review['customerName'] ?? 'Unknown Customer';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
            spreadRadius: 1,
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: kMaincolor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text(
                    customerName.isNotEmpty ? customerName[0].toUpperCase() : 'U',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: kMaincolor,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            customerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(date),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildStarRating(rating, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          rating.toStringAsFixed(1),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (reviewText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.withOpacity(0.1)),
              ),
              child: Text(
                reviewText,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    
    if (difference == 0) {
      return "Today";
    } else if (difference == 1) {
      return "Yesterday";
    } else if (difference < 7) {
      return "$difference days ago";
    } else {
      return "${date.day}/${date.month}/${date.year}";
    }
  }
}