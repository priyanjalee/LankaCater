import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/colors.dart';
import 'caterer_home_page.dart';
import 'orders_page.dart';
import 'event_page.dart';
import 'caterer_location_pick_page.dart';
import 'package:lankacater/screens/login_page.dart'; 

class CatererProfilePage extends StatefulWidget {
  const CatererProfilePage({super.key});

  @override
  State<CatererProfilePage> createState() => _CatererProfilePageState();
}

class _CatererProfilePageState extends State<CatererProfilePage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  int _currentIndex = 3;
  bool _loading = true;
  bool _saving = false;

  String? profileImageUrl;
  File? _pickedImage;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _aboutUsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final doc = await _firestore.collection('caterers').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          _nameController.text = data['name'] ?? '';
          _emailController.text = data['email'] ?? user.email ?? '';
          _phoneController.text = data['phone'] ?? '';
          _addressController.text = data['address'] ?? '';
          _aboutUsController.text = data['description'] ?? '';
          profileImageUrl = data['profileImage'];
        } else {
          _emailController.text = user.email ?? '';
        }
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickProfileImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Change Profile Picture',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildImagePickerOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  source: ImageSource.camera,
                ),
                _buildImagePickerOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  source: ImageSource.gallery,
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePickerOption({
    required IconData icon,
    required String label,
    required ImageSource source,
  }) {
    return GestureDetector(
      onTap: () async {
        Navigator.pop(context);
        final picker = ImagePicker();
        final pickedFile = await picker.pickImage(
          source: source, 
          imageQuality: 50,
          maxWidth: 800,
          maxHeight: 800,
        );
        if (pickedFile != null) {
          setState(() => _pickedImage = File(pickedFile.path));
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kMaincolor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: kMaincolor.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 30, color: kMaincolor),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: kMaincolor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _uploadProfileImage(File image) async {
    try {
      final user = _auth.currentUser!;
      
      // Check if file exists and is readable
      if (!await image.exists()) {
        debugPrint('Image file does not exist: ${image.path}');
        return null;
      }

      final ref = FirebaseStorage.instance
          .ref()
          .child('caterer_profiles')
          .child('${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      
      debugPrint('Starting upload to: ${ref.fullPath}');
      
      // Upload with metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedBy': user.uid,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );
      
      final uploadTask = ref.putFile(image, metadata);
      
      // Monitor upload progress
      uploadTask.snapshotEvents.listen(
        (TaskSnapshot snapshot) {
          double progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
          debugPrint('Upload progress: ${progress.toStringAsFixed(2)}%');
        },
        onError: (error) {
          debugPrint('Upload stream error: $error');
        },
      );
      
      final snapshot = await uploadTask;
      debugPrint('Upload completed. State: ${snapshot.state}');
      
      if (snapshot.state == TaskState.success) {
        final downloadUrl = await ref.getDownloadURL();
        debugPrint('Download URL obtained: $downloadUrl');
        return downloadUrl;
      } else {
        debugPrint('Upload failed with state: ${snapshot.state}');
        return null;
      }
      
    } catch (e) {
      debugPrint('Image upload failed with error: $e');
      debugPrint('Error type: ${e.runtimeType}');
      if (e.toString().contains('permission')) {
        debugPrint('Permission error detected. Check Firebase Storage rules.');
      } else if (e.toString().contains('network')) {
        debugPrint('Network error detected. Check internet connection.');
      }
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar("Name cannot be empty", isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      String? uploadedUrl = profileImageUrl;
      
      // Upload new image if picked
      if (_pickedImage != null) {
        debugPrint('Attempting to upload profile image...');
        _showSnackBar("Uploading image...", isError: false);
        
        final url = await _uploadProfileImage(_pickedImage!);
        if (url != null && url.isNotEmpty) {
          uploadedUrl = url;
          debugPrint('Image uploaded successfully: $url');
        } else {
          debugPrint('Image upload returned null or empty URL');
          _showSnackBar("Failed to upload image. Please check your internet connection and try again.", isError: true);
          if (mounted) setState(() => _saving = false);
          return;
        }
      }

      final user = _auth.currentUser!;
      debugPrint('Saving profile data to Firestore...');
      
      await _firestore.collection('caterers').doc(user.uid).set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'description': _aboutUsController.text.trim(),
        'profileImage': uploadedUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update the state properly - only clear picked image after successful upload
      setState(() {
        profileImageUrl = uploadedUrl;
        _pickedImage = null; // Clear the picked image only after successful save
      });

      _showSnackBar("Profile updated successfully!", isError: false);
      debugPrint('Profile saved successfully');
    } catch (e) {
      debugPrint('Error saving profile: $e');
      String errorMessage = "Failed to update profile";
      
      if (e.toString().contains('permission-denied')) {
        errorMessage = "Permission denied. Please check your account permissions.";
      } else if (e.toString().contains('network')) {
        errorMessage = "Network error. Please check your internet connection.";
      } else if (e.toString().contains('storage')) {
        errorMessage = "Storage error. Please try again.";
      }
      
      _showSnackBar(errorMessage, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _onBottomNavTap(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CatererHomePage()),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OrdersPage()),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const EventsPage()),
        );
        break;
      case 3:
        break;
    }
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType type = TextInputType.text,
    bool enabled = true,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: type,
        enabled: enabled,
        maxLines: maxLines,
        style: TextStyle(
          color: enabled ? Colors.black87 : Colors.grey[600],
          fontSize: 16,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: enabled ? kMaincolor : Colors.grey[500],
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(
            icon,
            color: enabled ? kMaincolor : Colors.grey[500],
            size: 22,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: kMaincolor, width: 2),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: enabled ? Colors.white : Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    bool isLoading = false,
    bool isOutlined = false,
  }) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: !isOutlined ? LinearGradient(
          colors: [color, color.withOpacity(0.8)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ) : null,
        borderRadius: BorderRadius.circular(15),
        boxShadow: !isOutlined ? [
          BoxShadow(
            color: color.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ] : null,
        border: isOutlined ? Border.all(color: color, width: 2) : null,
      ),
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading 
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: isOutlined ? color : Colors.white,
                strokeWidth: 2,
              ),
            )
          : Icon(
              icon,
              color: isOutlined ? color : Colors.white,
              size: 22,
            ),
        label: Text(
          isLoading ? "Processing..." : label,
          style: TextStyle(
            color: isOutlined ? color : Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isOutlined ? Colors.transparent : Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  // Helper method to get the current profile image
  ImageProvider<Object>? _getCurrentProfileImage() {
    if (_pickedImage != null) {
      return FileImage(_pickedImage!);
    } else if (profileImageUrl != null && profileImageUrl!.isNotEmpty) {
      return NetworkImage(profileImageUrl!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [kMaincolor.withOpacity(0.1), Colors.white],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text(
                  'Loading Profile...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Profile",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: kMaincolor,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [kMaincolor, kMaincolor.withOpacity(0.8)],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [kMaincolor, kMaincolor.withOpacity(0.8)],
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Profile Picture
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          spreadRadius: 5,
                          blurRadius: 20,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 65,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.grey[300],
                            backgroundImage: _getCurrentProfileImage(),
                            child: _getCurrentProfileImage() == null
                                ? const Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 5,
                          right: 5,
                          child: GestureDetector(
                            onTap: _pickProfileImage,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    spreadRadius: 2,
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                color: kMaincolor,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _nameController.text.isNotEmpty ? _nameController.text : 'Caterer',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _emailController.text,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),

            // Form Section
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Profile Information',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildTextField(
                    label: "Full Name",
                    controller: _nameController,
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: "Email Address",
                    controller: _emailController,
                    icon: Icons.email_outlined,
                    type: TextInputType.emailAddress,
                    enabled: false,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: "Phone Number",
                    controller: _phoneController,
                    icon: Icons.phone_outlined,
                    type: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: "Business Address",
                    controller: _addressController,
                    icon: Icons.location_on_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: "About Us",
                    controller: _aboutUsController,
                    icon: Icons.info_outline,
                    type: TextInputType.multiline,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 30),

                  // Action Buttons Section
                  const Text(
                    'Actions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildActionButton(
                    label: "Save Profile",
                    icon: Icons.save_outlined,
                    onPressed: _saveProfile,
                    color: kMaincolor,
                    isLoading: _saving,
                  ),
                  const SizedBox(height: 16),

                  _buildActionButton(
                    label: "Update Location",
                    icon: Icons.location_on_outlined,
                    onPressed: user == null
                        ? () {}
                        : () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CatererLocationPickPage(userId: user.uid),
                              ),
                            );

                            if (result != null) {
                              await _firestore
                                  .collection('caterers')
                                  .doc(user.uid)
                                  .set({
                                'location': result,
                              }, SetOptions(merge: true));

                              _showSnackBar("Location updated successfully!", isError: false);
                            }
                          },
                    color: Colors.blue,
                    isOutlined: true,
                  ),
                  const SizedBox(height: 16),

                  _buildActionButton(
                    label: "Logout",
                    icon: Icons.logout_outlined,
                    onPressed: () async {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            title: const Text(
                              'Confirm Logout',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            content: const Text('Are you sure you want to logout?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await _auth.signOut();
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(builder: (_) => const LoginPage()),
                                    (route) => false,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  'Logout',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    color: Colors.red,
                    isOutlined: true,
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onBottomNavTap,
        selectedItemColor: kMaincolor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 10,
        backgroundColor: Colors.white,
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
}