// customer_profile_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/colors.dart';
import 'customer_home_page.dart';
import 'customer_bookings_page.dart';
import 'customer_notifications_page.dart';

class CustomerProfilePage extends StatefulWidget {
  const CustomerProfilePage({super.key});

  @override
  State<CustomerProfilePage> createState() => _CustomerProfilePageState();
}

class _CustomerProfilePageState extends State<CustomerProfilePage> with TickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser!;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _profileImageUrl;
  File? _pickedImage;
  final int _selectedIndex = 3; // Profile tab selected

  AnimationController? _fadeController;
  Animation<double>? _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _loadProfile();
  }

  void _initializeAnimation() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController!, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('customers').doc(user.uid).get();
      if (doc.exists) {
        _nameController.text = doc['name'] ?? '';
        _emailController.text = doc['email'] ?? user.email ?? '';
        _addressController.text = doc['address'] ?? '';
        _contactController.text = doc['contact'] ?? '';
        _profileImageUrl = doc['profileImage'];
      } else {
        _emailController.text = user.email ?? '';
      }
      _fadeController?.forward();
    } catch (e) {
      debugPrint("Error loading profile: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Failed to load profile. Check your permissions."),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _fadeController?.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Select Profile Picture',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildImageOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onTap: () async {
                    Navigator.pop(context);
                    final pickedFile = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 75,
                    );
                    if (pickedFile != null) {
                      setState(() => _pickedImage = File(pickedFile.path));
                    }
                  },
                ),
                _buildImageOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  onTap: () async {
                    Navigator.pop(context);
                    final pickedFile = await ImagePicker().pickImage(
                      source: ImageSource.camera,
                      imageQuality: 75,
                    );
                    if (pickedFile != null) {
                      setState(() => _pickedImage = File(pickedFile.path));
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildImageOption({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 25),
        decoration: BoxDecoration(
          color: kMaincolor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: kMaincolor.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 30, color: kMaincolor),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: kMaincolor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _uploadImage(File image) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('customer_profiles')
          .child('${user.uid}.jpg');

      await ref.putFile(image);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint("Image upload error: $e");
      return null;
    }
  }

  Future<void> _saveProfile() async {
    // Simple validation
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Name cannot be empty."),
          backgroundColor: Colors.orange[400],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    String? imageUrl = _profileImageUrl;

    try {
      if (_pickedImage != null) {
        final uploadedUrl = await _uploadImage(_pickedImage!);
        if (uploadedUrl != null) imageUrl = uploadedUrl;
      }

      await FirebaseFirestore.instance.collection('customers').doc(user.uid).set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        'contact': _contactController.text.trim(),
        'profileImage': imageUrl,
      }, SetOptions(merge: true));

      setState(() {
        _profileImageUrl = imageUrl;
        _pickedImage = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Profile updated successfully"),
          backgroundColor: Colors.green[400],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      debugPrint("Error saving profile: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Failed to update profile. Check permissions."),
          backgroundColor: Colors.red[400],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CustomerHomePage()),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CustomerBookingsPage()),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CustomerNotificationsPage()),
        );
        break;
      case 3:
        // Already here
        break;
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType type = TextInputType.text,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: kMaincolor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: kMaincolor, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey[50],
          labelStyle: TextStyle(color: Colors.grey[600]),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildProfileContent() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Profile Picture Card
          Card(
            elevation: 8,
            shadowColor: kMaincolor.withOpacity(0.3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: kMaincolor.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 70,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: _pickedImage != null
                              ? FileImage(_pickedImage!)
                              : (_profileImageUrl != null ? NetworkImage(_profileImageUrl!) : null) as ImageProvider<Object>?,
                          child: (_pickedImage == null && _profileImageUrl == null)
                              ? Icon(Icons.person, size: 70, color: Colors.grey[400])
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 5,
                        right: 5,
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: kMaincolor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: kMaincolor.withOpacity(0.5),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _nameController.text.isNotEmpty ? _nameController.text : "Your Name",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    _emailController.text,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Form Card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Personal Information",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: kMaincolor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  _buildTextField(
                    controller: _nameController,
                    label: "Full Name",
                    icon: Icons.person_outline,
                  ),
                  
                  _buildTextField(
                    controller: _emailController,
                    label: "Email Address",
                    icon: Icons.email_outlined,
                    type: TextInputType.emailAddress,
                  ),
                  
                  _buildTextField(
                    controller: _addressController,
                    label: "Address",
                    icon: Icons.location_on_outlined,
                  ),
                  
                  _buildTextField(
                    controller: _contactController,
                    label: "Contact Number",
                    icon: Icons.phone_outlined,
                    type: TextInputType.phone,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Action Buttons
          Column(
            children: [
              // Save Button
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [kMaincolor, kMaincolor.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: kMaincolor.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _saveProfile,
                  icon: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save_outlined, color: Colors.white),
                  label: Text(
                    _saving ? "Saving..." : "Save Profile",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Logout Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: const Text("Confirm Logout"),
                        content: const Text("Are you sure you want to logout?"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              "Cancel",
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              await FirebaseAuth.instance.signOut();
                              Navigator.pop(context);
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              "Logout",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.logout_outlined, color: Colors.red),
                  label: const Text(
                    "Logout",
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 100), // Space for bottom navigation
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: kMaincolor),
              const SizedBox(height: 20),
              Text(
                'Loading Profile...',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // Custom App Bar
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            backgroundColor: kMaincolor,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      kMaincolor,
                      kMaincolor.withOpacity(0.8),
                    ],
                  ),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: 40),
                      Text(
                        "My Profile",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Manage your account details",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Profile Content
          SliverToBoxAdapter(
            child: _fadeAnimation != null 
                ? FadeTransition(
                    opacity: _fadeAnimation!,
                    child: _buildProfileContent(),
                  )
                : _buildProfileContent(),
          ),
        ],
      ),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: kMaincolor,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.event_note_outlined),
              activeIcon: Icon(Icons.event_note),
              label: 'Bookings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_outlined),
              activeIcon: Icon(Icons.notifications),
              label: 'Alerts',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}