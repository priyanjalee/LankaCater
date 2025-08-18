import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../constants/colors.dart';

class ManageGalleryPage extends StatefulWidget {
  const ManageGalleryPage({super.key});

  @override
  State<ManageGalleryPage> createState() => _ManageGalleryPageState();
}

class _ManageGalleryPageState extends State<ManageGalleryPage> {
  final ImagePicker _picker = ImagePicker();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> _uploadImage() async {
    try {
      final XFile? pickedFile =
          await _picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        final user = _auth.currentUser;
        if (user == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("User not logged in")),
          );
          return;
        }

        final uid = user.uid;
        final storageRef = _storage
            .ref()
            .child("caterers/$uid/gallery/${DateTime.now().millisecondsSinceEpoch}.jpg");

        await storageRef.putFile(File(pickedFile.path));
        final downloadUrl = await storageRef.getDownloadURL();

        await _firestore
            .collection("caterers")
            .doc(uid)
            .collection("gallery")
            .add({"url": downloadUrl, "uploadedAt": Timestamp.now()});
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: $e")),
      );
    }
  }

  Future<void> _deleteImage(String docId, String imageUrl) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();

      await _firestore
          .collection("caterers")
          .doc(user.uid)
          .collection("gallery")
          .doc(docId)
          .delete();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Delete failed: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("User not logged in")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Manage Gallery",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        backgroundColor: kMaincolor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection("caterers")
            .doc(user.uid)
            .collection("gallery")
            .orderBy("uploadedAt", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            // CENTERED GALLERY ICON FOR EMPTY STATE
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 100,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "No photos yet.\nTap the button below to add your first dish!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }

          final images = snapshot.data!.docs;

          return GridView.builder(
            padding: const EdgeInsets.all(14),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 0.95,
            ),
            itemCount: images.length,
            itemBuilder: (context, index) {
              final doc = images[index];
              final data = doc.data() as Map<String, dynamic>;
              final imageUrl = data['url'];

              return GestureDetector(
                onTap: () {
                  // Fullscreen preview
                  showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(imageUrl, fit: BoxFit.cover),
                      ),
                    ),
                  );
                },
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.antiAlias,
                  shadowColor: Colors.grey.shade300,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: GestureDetector(
                          onTap: () => _deleteImage(doc.id, imageUrl),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: const EdgeInsets.all(6),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kMaincolor,
        onPressed: _uploadImage,
        icon: const Icon(Icons.add_photo_alternate, color: Colors.white),
        label: const Text(
          "Add Photo",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
