import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path_lib; 
import 'package:lankacater/constants/colors.dart';
import 'package:geocoding/geocoding.dart';

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
  final locationController = TextEditingController();
  final serviceAreaController = TextEditingController();

  String catererName = 'Caterer';
  bool isLoading = false;

  List<File> galleryImages = [];
  File? menuImage;
  File? logoImage;

  final ImagePicker picker = ImagePicker();

  final Map<String, List<String>> eventCategories = {
    'Celebrations': [
      "Weddings",
      "Anniversary",
      "Birthday Parties",
      "Christmas",
      "Puberty Engagement",
    ],
    'Corporate & Formal': [
      "Corporate",
      "Opening Ceremonies",
      "Cocktail Parties",
    ],
    'Religious & Cultural': [
      "Pirith Ceremonies Catering",
      "Alms Giving Ceremonies",
      "Church Event Catering",
    ],
  };

  Set<String> selectedEventTypes = {};

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

  Future<String> uploadImage(File imageFile, String folderPath) async {
    final ext = path_lib.extension(imageFile.path);
    final ref = FirebaseStorage.instance
        .ref()
        .child('caterers/$folderPath/${DateTime.now().millisecondsSinceEpoch}$ext');
    await ref.putFile(imageFile);
    return await ref.getDownloadURL();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedEventTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one event type")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in.");

      // ✅ Upload images
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

      // ✅ Geocode location to get latitude & longitude
      double? latitude;
      double? longitude;

      try {
        List<Location> locations = await locationFromAddress(locationController.text.trim());
        if (locations.isNotEmpty) {
          latitude = locations.first.latitude;
          longitude = locations.first.longitude;
        }
      } catch (e) {
        latitude = null;
        longitude = null;
      }

      // Save caterer profile
      await FirebaseFirestore.instance.collection('caterers').doc(uid).set({
        'businessName': businessNameController.text.trim(),
        'contact': phoneController.text.trim(),
        'email': emailController.text.trim(),
        'address': addressController.text.trim(),
        'businessType': businessTypeController.text.trim(),
        'cateredEventTypes': selectedEventTypes.toList(),
        'gallery': galleryUrls,
        'menu': menuUrl ?? '',
        'logo': logoUrl ?? '',
        'location': locationController.text.trim(),
        'serviceArea': serviceAreaController.text.trim(),
        'latitude': latitude ?? 0.0,
        'longitude': longitude ?? 0.0,
        'createdAt': Timestamp.now(),
      });

      // Save role
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'role': 'caterer',
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile saved successfully!")),
      );

      // Navigate to Caterer Home
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
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        title,
        style: const TextStyle(
            fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  Widget _buildImagePreview(List<File> files, void Function(int) onDelete) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: files.asMap().entries.map((entry) {
        int index = entry.key;
        File file = entry.value;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(file, width: 110, height: 110, fit: BoxFit.cover),
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
                  radius: 14,
                  backgroundColor: Colors.redAccent,
                  child: Icon(Icons.close, size: 18, color: Colors.white),
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
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(file, width: 110, height: 110, fit: BoxFit.cover),
        ),
        Positioned(
          top: -8,
          right: -8,
          child: InkWell(
            onTap: onRemove,
            child: const CircleAvatar(
              radius: 14,
              backgroundColor: Colors.redAccent,
              child: Icon(Icons.close, size: 18, color: Colors.white),
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
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: kMaincolor, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

  Widget _buildEventTypesGroupedCheckboxes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Event Types Catered",
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        ...eventCategories.entries.map((entry) {
          return Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ExpansionTile(
              title: Text(
                entry.key,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: Colors.black87),
              ),
              childrenPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: entry.value.map((event) {
                final isSelected = selectedEventTypes.contains(event);
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(event),
                  value: isSelected,
                  activeColor: kMaincolor,
                  onChanged: (bool? checked) {
                    setState(() {
                      if (checked == true) {
                        selectedEventTypes.add(event);
                      } else {
                        selectedEventTypes.remove(event);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          );
        }),
        if (selectedEventTypes.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              "Please select at least one event type",
              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: kMaincolor,
        centerTitle: true,
        title: const Text(
          'Caterer Profile',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () =>
              Navigator.pushReplacementNamed(context, '/choose_role'),
        ),
        elevation: 4,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
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
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Let your food take the spotlight — create your profile and get discovered!",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 15, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle("Business Details"),
                _buildCard(
                  child: Column(
                    children: [
                      _buildField(businessNameController,
                          "Business or Owner's Name",
                          hint: "e.g. Priyanjalee Caterers"),
                      _buildField(phoneController, "Phone Number",
                          keyboardType: TextInputType.phone,
                          hint: "07X XXX XXXX"),
                      _buildField(emailController, "Business Email",
                          isEmail: true, hint: "example@email.com"),
                      _buildField(addressController, "Business Address",
                          maxLines: 2, hint: "No.123, Street, City"),
                      _buildField(businessTypeController, "Business Type",
                          hint: "Individual / Team / Restaurant-based"),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildCard(child: _buildEventTypesGroupedCheckboxes()),
                const SizedBox(height: 16),
                _buildSectionTitle("Location & Service"),
                _buildCard(
                  child: Column(
                    children: [
                      _buildField(locationController, "Location",
                          hint: "City or Town"),
                      _buildField(serviceAreaController, "Service Area",
                          hint: "Colombo, Gampaha, etc."),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildSectionTitle("Gallery"),
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildImagePreview(
                          galleryImages, (index) => galleryImages.removeAt(index)),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: pickGalleryImages,
                        icon: const Icon(Icons.photo_library, color: Colors.white),
                        label: const Text("Add Gallery Images",
                            style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: kMaincolor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildSectionTitle("Menu"),
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSingleImagePreview(
                          menuImage, () => setState(() => menuImage = null)),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () =>
                            pickImage((file) => setState(() => menuImage = file)),
                        icon: const Icon(Icons.restaurant_menu, color: Colors.white),
                        label: const Text("Pick Menu Image",
                            style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: kMaincolor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildSectionTitle("Logo"),
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSingleImagePreview(
                          logoImage, () => setState(() => logoImage = null)),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () =>
                            pickImage((file) => setState(() => logoImage = file)),
                        icon: const Icon(Icons.branding_watermark,
                            color: Colors.white),
                        label: const Text("Pick Logo Image",
                            style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: kMaincolor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                Center(
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kMaincolor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 50, vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 4,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 3),
                          )
                        : const Text(
                            'SAVE AND CONTINUE',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
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
    locationController.dispose();
    serviceAreaController.dispose();
    super.dispose();
  }
}
