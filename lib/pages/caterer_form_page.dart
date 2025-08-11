import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lankacater/constants/colors.dart';

class CatererFormPage extends StatefulWidget {
  const CatererFormPage({super.key});

  @override
  State<CatererFormPage> createState() => _CatererFormPageState();
}

class _CatererFormPageState extends State<CatererFormPage> {
  final _formKey = GlobalKey<FormState>();

  final businessNameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final addressController = TextEditingController();
  final businessTypeController = TextEditingController();
  final eventTypesController = TextEditingController();
  final locationController = TextEditingController();
  final serviceAreaController = TextEditingController();

  String catererName = 'Caterer';
  bool isLoading = false;

  List<File> galleryImages = [];
  File? menuImage;
  File? logoImage;

  final ImagePicker picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    businessNameController.addListener(() {
      setState(() {
        catererName = businessNameController.text.trim().isEmpty
            ? 'Caterer'
            : businessNameController.text.trim();
      });
    });
  }

  Future<void> pickGalleryImages() async {
    final List<XFile> pickedFiles = await picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        galleryImages.addAll(pickedFiles.map((e) => File(e.path)));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${pickedFiles.length} images added to gallery")),
      );
    }
  }

  Future<void> pickImage(Function(File) onPicked) async {
    final XFile? file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      onPicked(File(file.path));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Image selected successfully")),
      );
    }
  }

  Future<String> uploadImage(File imageFile, String path) async {
    final ref = FirebaseStorage.instance
        .ref()
        .child('caterers/$path/${DateTime.now().millisecondsSinceEpoch}');
    await ref.putFile(imageFile);
    return await ref.getDownloadURL();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in.");

      List<String> galleryUrls = [];
      for (File file in galleryImages) {
        String url = await uploadImage(file, "$uid/gallery");
        galleryUrls.add(url);
      }

      String? menuUrl;
      if (menuImage != null) {
        menuUrl = await uploadImage(menuImage!, "$uid/menu");
      }

      String? logoUrl;
      if (logoImage != null) {
        logoUrl = await uploadImage(logoImage!, "$uid/logo");
      }

      await FirebaseFirestore.instance.collection('caterers').doc(uid).set({
        'businessName': businessNameController.text.trim(),
        'contact': phoneController.text.trim(),
        'email': emailController.text.trim(),
        'address': addressController.text.trim(),
        'businessType': businessTypeController.text.trim(),
        'cateredEventTypes': eventTypesController.text.trim(),
        'gallery': galleryUrls,
        'menu': menuUrl ?? '',
        'logo': logoUrl ?? '',
        'location': locationController.text.trim(),
        'serviceArea': serviceAreaController.text.trim(),
        'createdAt': Timestamp.now(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile saved successfully!")),
      );
      Navigator.pushReplacementNamed(context, '/caterer_home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving profile: $e')),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(Icons.star, color: kMaincolor, size: 20),
          const SizedBox(width: 6),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildImagePreview(List<File> files, void Function(int) onDelete) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: files.asMap().entries.map((entry) {
        int index = entry.key;
        File file = entry.value;
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(file, width: 100, height: 100, fit: BoxFit.cover),
            ),
            Positioned(
              top: -8,
              right: -8,
              child: InkWell(
                onTap: () {
                  setState(() => onDelete(index));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Image removed")),
                  );
                },
                child: const CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.red,
                  child: Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildSingleImagePreview(File? file, VoidCallback onRemove) {
    if (file == null) return const SizedBox();
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(file, width: 100, height: 100, fit: BoxFit.cover),
        ),
        Positioned(
          top: -8,
          right: -8,
          child: InkWell(
            onTap: onRemove,
            child: const CircleAvatar(
              radius: 12,
              backgroundColor: Colors.red,
              child: Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label, {
    TextInputType keyboardType = TextInputType.text,
    bool isEmail = false,
    int maxLines = 1,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        validator: (val) {
          if (val == null || val.trim().isEmpty) {
            return 'Please enter $label';
          }
          if (isEmail && !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(val.trim())) {
            return 'Enter a valid email address';
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kMaincolor,
        centerTitle: true,
        title: const Text(
          'Caterer Profile',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pushReplacementNamed(context, '/choose_role'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    Text(
                      "Welcome $catererName 👋",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      "Let your food take the spotlight — create your profile and get discovered!",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _buildSectionTitle("Business Details"),
              _buildField(businessNameController, "Business or Owner's Name", hint: "e.g. Priyanjalee Caterers"),
              _buildField(phoneController, "Phone Number", keyboardType: TextInputType.phone, hint: "07X XXX XXXX"),
              _buildField(emailController, "Business Email", isEmail: true, hint: "example@email.com"),
              _buildField(addressController, "Business Address", maxLines: 2, hint: "No.123, Street, City"),
              _buildField(businessTypeController, "Business Type", hint: "Individual / Team / Restaurant-based"),
              _buildField(eventTypesController, "Event Types Catered", hint: "Weddings, Pirith, Birthday Parties"),
              _buildField(locationController, "Location", hint: "City or Town"),
              _buildField(serviceAreaController, "Service Area", hint: "Colombo, Gampaha, etc."),

              _buildSectionTitle("Gallery"),
              _buildImagePreview(galleryImages, (index) => galleryImages.removeAt(index)),
              ElevatedButton.icon(
                onPressed: pickGalleryImages,
                icon: const Icon(Icons.photo_library, color: Colors.white),
                label: const Text("Add Gallery Images", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: kMaincolor),
              ),

              _buildSectionTitle("Menu"),
              _buildSingleImagePreview(menuImage, () => setState(() => menuImage = null)),
              ElevatedButton.icon(
                onPressed: () => pickImage((file) => setState(() => menuImage = file)),
                icon: const Icon(Icons.restaurant_menu, color: Colors.white),
                label: const Text("Pick Menu Image", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: kMaincolor),
              ),

              _buildSectionTitle("Logo"),
              _buildSingleImagePreview(logoImage, () => setState(() => logoImage = null)),
              ElevatedButton.icon(
                onPressed: () => pickImage((file) => setState(() => logoImage = file)),
                icon: const Icon(Icons.branding_watermark, color: Colors.white),
                label: const Text("Pick Logo Image", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: kMaincolor),
              ),

              const SizedBox(height: 30),
              Center(
                child: ElevatedButton(
                  onPressed: isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kMaincolor,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'SAVE AND CONTINUE',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    businessNameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    addressController.dispose();
    businessTypeController.dispose();
    eventTypesController.dispose();
    locationController.dispose();
    serviceAreaController.dispose();
    super.dispose();
  }
}
