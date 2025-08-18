import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../constants/colors.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _currentIndex = 3; // Profile page index
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final _formKey = GlobalKey<FormState>();

  // Controllers initialized at declaration
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  String profilePicUrl = '';
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    final uid = _auth.currentUser!.uid;
    final userDoc = await _firestore.collection('users').doc(uid).get();

    if (userDoc.exists) {
      final data = userDoc.data()!;
      setState(() {
        _nameController.text = data['name'] ?? '';
        _emailController.text = data['email'] ?? _auth.currentUser!.email!;
        _phoneController.text = data['phone'] ?? '';
        _addressController.text = data['address'] ?? '';
        profilePicUrl = data['profilePic'] ?? '';
      });
    } else {
      _emailController.text = _auth.currentUser!.email!;
    }
  }

  void _onBottomNavTap(int index) {
    setState(() {
      _currentIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/orders');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/events');
        break;
      case 3:
        break; // current page
    }
  }

  Future<void> _pickProfileImage() async {
    final pickedFile =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
      await _uploadProfileImage();
    }
  }

  Future<void> _uploadProfileImage() async {
    if (_profileImage == null) return;
    final uid = _auth.currentUser!.uid;
    final storageRef =
        FirebaseStorage.instance.ref().child('profile_pics/$uid.jpg');
    await storageRef.putFile(_profileImage!);
    final url = await storageRef.getDownloadURL();
    setState(() {
      profilePicUrl = url;
    });
    await _firestore.collection('users').doc(uid).set({
      'profilePic': url,
    }, SetOptions(merge: true));
  }

  Future<void> _saveProfile() async {
    final uid = _auth.currentUser!.uid;
    await _firestore.collection('users').doc(uid).set({
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'address': _addressController.text.trim(),
      'profilePic': profilePicUrl,
    }, SetOptions(merge: true));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated successfully!')),
    );
  }

  void _logout() async {
    await _auth.signOut();
    Navigator.pushReplacementNamed(context, '/login'); // adjust route
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Profile",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: kMaincolor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Profile Picture
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundImage: _profileImage != null
                          ? FileImage(_profileImage!)
                          : (profilePicUrl.isNotEmpty
                              ? NetworkImage(profilePicUrl)
                              : const AssetImage(
                                  'assets/profile_placeholder.png') as ImageProvider),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickProfileImage,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: kMaincolor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Editable Fields (email now editable)
              _buildTextField("Name", _nameController),
              _buildTextField("Email", _emailController), 
              _buildTextField("Phone", _phoneController),
              _buildTextField("Address", _addressController),

              const SizedBox(height: 30),

              // Save Profile Button
              ElevatedButton.icon(
                onPressed: _saveProfile,
                icon: const Icon(Icons.save, color: Colors.white),
                label: const Text(
                  "Save Profile",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 16, // uniform font size
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kMaincolor,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 30, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Logout Button
              ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text(
                  "Logout",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16, // same as Save Profile
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kMaincolor,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 30, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onBottomNavTap,
        selectedItemColor: kMaincolor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.shopping_bag), label: 'Orders'),
          BottomNavigationBarItem(icon: Icon(Icons.event), label: 'Events'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {bool readOnly = false}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextFormField(
          controller: controller,
          readOnly: readOnly,
          decoration: InputDecoration(
            labelText: label,
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }
}
