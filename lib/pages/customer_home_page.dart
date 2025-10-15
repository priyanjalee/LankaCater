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
import 'package:latlong2/latlong.dart';

class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({super.key});

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  String _selectedEvent = "All";
  String _customerName = "Customer";
  int _selectedBottomIndex = 0;
  LatLng? _selectedLocation;

  // Mapping main categories to sub-events
  final Map<String, List<String>> _eventMap = {
    "Weddings": ["Weddings"],
    "Parties": ["Anniversary", "Birthday Parties", "Christmas", "Puberty Engagement"],
    "Corporate": ["Corporate", "Opening Ceremonies", "Cocktail Parties"],
    "Birthdays": ["Birthday Parties"],
    "Religious": ["Pirith Ceremonies Catering", "Alms Giving Ceremonies", "Church Event Catering"],
    "Cocktail": ["Cocktail Parties"],
  };

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

  // Search bar now receives selected location from map
  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () async {
        final selected = await Navigator.push<LatLng>(
          context,
          MaterialPageRoute(builder: (_) => const LocationSearchPage()),
        );
        if (selected != null) {
          setState(() {
            _selectedLocation = selected;
          });
        }
      },
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
            Expanded(
              child: Text(
                _selectedLocation != null
                    ? "Selected: ${_selectedLocation!.latitude.toStringAsFixed(5)}, ${_selectedLocation!.longitude.toStringAsFixed(5)}"
                    : "Search nearby caterers...",
                style: TextStyle(color: Colors.grey[500], fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
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

  String _getCatererImageUrl(Map<String, dynamic> data) {
    // First check for logoUrl or logo
    String logoUrl = (data['logoUrl'] ?? data['logo'] ?? '').toString().trim();
    if (logoUrl.isNotEmpty) {
      return logoUrl;
    }
    
    // If no logo, check for profile picture with various possible field names
    String profilePicture = (data['profilePicture'] ?? 
                           data['profilePictureUrl'] ?? 
                           data['profileImage'] ??
                           data['profileImageUrl'] ??
                           data['imageUrl'] ??
                           data['image'] ?? '').toString().trim();
    if (profilePicture.isNotEmpty) {
      return profilePicture;
    }
    
    return '';
  }

  Widget _buildCatererGrid() {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection('caterers');

    if (_selectedEvent != "All") {
      List<String> subEvents = _eventMap[_selectedEvent] ?? [_selectedEvent];
      q = q.where('cateredEventTypes', arrayContainsAny: subEvents);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                "No caterers available for ${_selectedEvent == "All" ? "now" : _selectedEvent}",
                style: const TextStyle(color: Colors.grey, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: (docs.length / 2).ceil(), // Create rows of 2 items
            itemBuilder: (context, rowIndex) {
              final startIndex = rowIndex * 2;
              final endIndex = (startIndex + 2 > docs.length) ? docs.length : startIndex + 2;
              final rowDocs = docs.sublist(startIndex, endIndex);

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    ...rowDocs.asMap().entries.map((entry) {
                      final doc = entry.value;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: entry.key == 0 && rowDocs.length > 1 ? 8 : 0,
                            left: entry.key == 1 ? 8 : 0,
                          ),
                          child: _buildCatererCard(doc),
                        ),
                      );
                    }),
                    // Add empty space if odd number of items
                    if (rowDocs.length == 1) const Expanded(child: SizedBox()),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCatererCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final name = _readString(data, 'businessName', 'Caterer');
    final address = _readString(data, 'address', 'No address provided');
    final serviceArea = _readString(data, 'serviceArea', '');
    final imageUrl = _getCatererImageUrl(data);
    final rating = _readDouble(data, 'rating', 0);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => CatererDetailsPage(catererId: doc.id, customerId: '', initialData: {})),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image section
            Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                gradient: LinearGradient(
                  colors: [
                    kMaincolor.withOpacity(0.1),
                    kMaincolor.withOpacity(0.05),
                  ],
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: Stack(
                  children: [
                    imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            width: double.infinity,
                            height: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildPlaceholderImage();
                            },
                          )
                        : _buildPlaceholderImage(),
                    // Rating overlay
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              size: 12,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              rating > 0 ? rating.toStringAsFixed(1) : 'New',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
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
            
            // Content section
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Business name
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  
                  // Address
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          address,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  
                  // Service area (if available)
                  if (serviceArea.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.public_outlined,
                          size: 12,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            serviceArea,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  const SizedBox(height: 12),
                  
                  // View Details button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => CatererDetailsPage(
                                  catererId: doc.id, 
                                  customerId: '', 
                                  initialData: {})),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kMaincolor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        "View Details",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kMaincolor.withOpacity(0.15),
            kMaincolor.withOpacity(0.08),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant_menu,
            size: 32,
            color: kMaincolor.withOpacity(0.6),
          ),
          const SizedBox(height: 6),
          Text(
            "Catering",
            style: TextStyle(
              fontSize: 12,
              color: kMaincolor.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
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
              _buildCatererGrid(),
              const SizedBox(height: 30),
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