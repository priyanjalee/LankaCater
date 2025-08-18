import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/colors.dart';
import 'choose_role_page.dart'; 

class CatererHomePage extends StatefulWidget {
  const CatererHomePage({super.key});

  @override
  State<CatererHomePage> createState() => _CatererHomePageState();
}

class _CatererHomePageState extends State<CatererHomePage> {
  String? businessName;
  int _selectedIndex = 0;
  bool hasRatings = false;

  @override
  void initState() {
    super.initState();
    _fetchCatererData();
    _checkRatings();
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
      print("Error fetching caterer data: $e");
    }
  }

  Future<void> _checkRatings() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        QuerySnapshot ratingsSnapshot = await FirebaseFirestore.instance
            .collection('ratings')
            .where('catererId', isEqualTo: user.uid)
            .get();

        if (ratingsSnapshot.docs.isNotEmpty) {
          setState(() {
            hasRatings = true;
          });
        }
      }
    } catch (e) {
      print("Error checking ratings: $e");
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    switch (index) {
      case 1:
        Navigator.pushNamed(context, '/orders');
        break;
      case 2:
        Navigator.pushNamed(context, '/events');
        break;
      case 3:
        Navigator.pushNamed(context, '/edit-profile');
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
            // Navigate directly to ChooseRolePage
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const ChooseRolePage(),
              ),
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _quickActionsCard(),
            const SizedBox(height: 16),
            if (hasRatings) ...[
              _sectionTitle("Ratings & Reviews"),
              const SizedBox(height: 12),
              _ratingCard(),
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

  // ---------------- Quick Actions Card ----------------
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
              routeName: "/orders",
              description: "View and manage all customer orders efficiently.",
            ),
            _quickActionButton(
              icon: Icons.event,
              title: "Events",
              routeName: "/events",
              description: "Plan, track, and organize catering events.",
            ),
            _quickActionButton(
              icon: Icons.menu_book,
              title: "Manage Menus",
              routeName: "/manage-menu",
              description: "Add or edit your menus for customers to explore.",
            ),
            _quickActionButton(
              icon: Icons.photo_library,
              title: "Manage Gallery",
              routeName: "/manage-gallery",
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
    required String routeName,
    required String description,
  }) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, routeName),
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
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: kMaincolor,
      ),
    );
  }

  Widget _ratingCard() {
    return InkWell(
      onTap: () async {
        final roleDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .get();

        if (roleDoc.exists && roleDoc['role'] == 'customer') {
          Navigator.pushNamed(context, '/reviews');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Only customers can give reviews.")),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              spreadRadius: 2,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: kMaincolor.withOpacity(0.15),
              child: const Icon(Icons.star, size: 30, color: Colors.orange),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text("4.8 / 5.0", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text("Based on 25 customer reviews", style: TextStyle(color: Colors.grey)),
              ],
            )
          ],
        ),
      ),
    );
  }
}
