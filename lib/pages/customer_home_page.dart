import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/colors.dart';
import 'choose_role_page.dart';
import 'customer_bookings_page.dart';
import 'customer_profile_page.dart';
import 'customer_notifications_page.dart';
import 'caterer_details_page.dart';
import 'location_search_page.dart';

class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({super.key});

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  String _selectedEvent = "All";
  String _customerName = "Customer";
  int _selectedBottomIndex = 0;
  int _currentPage = 0;
  final PageController _pageController = PageController(viewportFraction: 0.55);

  @override
  void initState() {
    super.initState();
    _loadCustomerName();
  }

  Future<void> _loadCustomerName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      String? name;
      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>;
        final fromUsers = (data['name'] ?? data['displayName'] ?? '').toString().trim();
        if (fromUsers.isNotEmpty) name = fromUsers;
      }
      name ??= (user.displayName ?? '').trim();
      if (name.isEmpty) {
        final email = user.email ?? '';
        name = email.contains('@') ? email.split('@').first : 'Customer';
      }
      if (mounted) setState(() => _customerName = name!);
    } catch (_) {}
  }

  void _handleBackToRole() {
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const ChooseRolePage()));
  }

  void _onBottomTap(int index) {
    setState(() => _selectedBottomIndex = index);
    if (index == 1) {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const CustomerBookingsPage()));
    } else if (index == 2) {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const CustomerNotificationsPage()));
    } else if (index == 3) {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const CustomerProfilePage()));
    }
  }

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const LocationSearchPage())),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: Colors.grey[500]),
            const SizedBox(width: 12),
            Text(
              "Search nearby caterers...",
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventGrid() {
    final categories = [
      {"label": "Weddings", "icon": Icons.favorite},
      {"label": "Parties", "icon": Icons.celebration},
      {"label": "Corporate", "icon": Icons.business_center},
      {"label": "Birthdays", "icon": Icons.cake},
      {"label": "Religious", "icon": Icons.account_balance},
      {"label": "Cocktail", "icon": Icons.local_bar},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: categories.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.1,
        ),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = _selectedEvent == cat["label"];

          return GestureDetector(
            onTap: () => setState(() => _selectedEvent = cat["label"] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        colors: [kMaincolor.withOpacity(0.8), kMaincolor])
                    : null,
                color: isSelected ? null : Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: kMaincolor.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: isSelected
                        ? Colors.white.withOpacity(0.2)
                        : Colors.white,
                    child: Icon(
                      cat["icon"] as IconData,
                      color: isSelected ? Colors.white : kMaincolor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    cat["label"] as String,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _readString(Map<String, dynamic> data, String key, [String fallback = '']) {
    final v = data[key];
    if (v == null) return fallback;
    if (v is String) return v;
    return v.toString();
  }

  double _readDouble(Map<String, dynamic> data, String key, [double fallback = 0]) {
    final v = data[key];
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    final s = v.toString();
    return double.tryParse(s) ?? fallback;
  }

  Widget _buildCatererCarousel() {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection('caterers');
    if (_selectedEvent != "All") {
      q = q.where('cateredEventTypes', arrayContains: _selectedEvent);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              "No caterers available for ${_selectedEvent == "All" ? "now" : _selectedEvent}",
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return SizedBox(
          height: 230,
          child: PageView.builder(
            controller: _pageController,
            itemCount: docs.length,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final name = _readString(data, 'businessName', 'Caterer');
              final address = _readString(data, 'address', 'No address provided');
              final serviceArea = _readString(data, 'serviceArea', '');
              final logoUrl = (() {
                final a = data['logoUrl'];
                final b = data['logo'];
                if (a is String && a.trim().isNotEmpty) return a.trim();
                if (b is String && b.trim().isNotEmpty) return b.trim();
                return '';
              })();
              final rating = _readDouble(data, 'rating', 0);

              double scale = _currentPage == index ? 1.0 : 0.9;
              double translateY = _currentPage == index ? 0 : 12;

              return Transform.translate(
                offset: Offset(0, translateY),
                child: Transform.scale(
                  scale: scale,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => CatererDetailsPage(catererId: doc.id)),
                      );
                    },
                    child: Container(
                      width: 140,
                      // **first card starts fully at left edge**
                      margin: EdgeInsets.only(
                        left: index == 0 ? 0 : 12,
                        right: index == docs.length - 1 ? 16 : 12,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                            child: SizedBox(
                              height: 120,
                              width: 140,
                              child: logoUrl.isNotEmpty
                                  ? Image.network(logoUrl, fit: BoxFit.cover)
                                  : Container(
                                      color: kMaincolor.withOpacity(0.2),
                                      child: const Icon(
                                        Icons.restaurant,
                                        color: Colors.white70,
                                        size: 36,
                                      ),
                                    ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    address,
                                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (serviceArea.isNotEmpty)
                                    Text(
                                      serviceArea,
                                      style: TextStyle(
                                          color: Colors.grey[500], fontSize: 10),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: List.generate(
                                      5,
                                      (i) => Icon(
                                        i < rating.round()
                                            ? Icons.star
                                            : Icons.star_border,
                                        size: 12,
                                        color: Colors.amber,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    width: double.infinity,
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    decoration: BoxDecoration(
                                      color: kMaincolor,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      "View Details",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _handleBackToRole();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          backgroundColor: kMaincolor,
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _handleBackToRole,
          ),
          title: Text(
            "Hello, $_customerName",
            style:
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchBar(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  "Explore Events",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              _buildEventGrid(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Text(
                  "Explore Caterers",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              _buildCatererCarousel(),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedBottomIndex,
          selectedItemColor: kMaincolor,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          onTap: _onBottomTap,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.event_note), label: 'Bookings'),
            BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Alerts'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
