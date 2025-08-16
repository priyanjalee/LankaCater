import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../constants/colors.dart';

class ManageMenuPage extends StatefulWidget {
  const ManageMenuPage({super.key});

  @override
  State<ManageMenuPage> createState() => _ManageMenuPageState();
}

class _ManageMenuPageState extends State<ManageMenuPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _menuItems = [];

  String? get uid => _auth.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (uid != null) _loadMenuItems();
    });
  }

  Future<void> _loadMenuItems() async {
    final currentUid = uid;
    if (currentUid == null) return;

    try {
      final snapshot = await _firestore
          .collection('caterers')
          .doc(currentUid)
          .collection('menus')
          .get();

      setState(() {
        _menuItems = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] ?? '',
            'price': data['price'] ?? 0.0,
            'imageUrl': data['imageUrl'] ?? '',
            'description': data['description'] ?? '',
          };
        }).toList();
      });
    } catch (e) {
      print('Error loading menu items: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load menu items: $e')),
      );
    }
  }

  Future<void> _addMenuItem() async {
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    final nameController = TextEditingController();
    final descController = TextEditingController();
    final priceController = TextEditingController();
    File? image;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateSB) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: const Text(
              "Add Menu Item",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final picked =
                            await _picker.pickImage(source: ImageSource.gallery);
                        if (picked != null) {
                          setStateSB(() => image = File(picked.path));
                        }
                      },
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: image != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(image!, fit: BoxFit.cover),
                              )
                            : const Icon(Icons.camera_alt,
                                color: Colors.grey, size: 40),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    TextField(
                      controller: descController,
                      decoration:
                          const InputDecoration(labelText: 'Description'),
                    ),
                    TextField(
                      controller: priceController,
                      decoration: const InputDecoration(labelText: 'Price'),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: kMaincolor, foregroundColor: Colors.white),
                onPressed: () async {
                  final name = nameController.text.trim();
                  final description = descController.text.trim();
                  final price =
                      double.tryParse(priceController.text.trim()) ?? 0.0;

                  if (name.isEmpty || price <= 0 || image == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Please enter valid details and select an image')),
                    );
                    return;
                  }

                  Navigator.pop(context);

                  await _uploadMenuItem(name, description, price, image!);

                  nameController.dispose();
                  descController.dispose();
                  priceController.dispose();
                },
                child: const Text("Add"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _uploadMenuItem(
      String name, String description, double price, File image) async {
    final currentUid = uid;
    if (currentUid == null) return;

    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('caterers/$currentUid/menus/$fileName');
      await ref.putFile(image);
      final imageUrl = await ref.getDownloadURL();

      final docRef = await _firestore
          .collection('caterers')
          .doc(currentUid)
          .collection('menus')
          .add({
        'name': name,
        'description': description,
        'price': price,
        'imageUrl': imageUrl,
      });

      setState(() {
        _menuItems.add({
          'id': docRef.id,
          'name': name,
          'description': description,
          'price': price,
          'imageUrl': imageUrl,
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Menu item added successfully')),
      );
    } catch (e) {
      print('Error uploading menu item: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add menu item: $e')),
      );
    }
  }

  Future<void> _deleteMenuItem(int index) async {
    final currentUid = uid;
    if (currentUid == null) return;

    try {
      final item = _menuItems[index];

      await _firestore
          .collection('caterers')
          .doc(currentUid)
          .collection('menus')
          .doc(item['id'])
          .delete();

      if (item['imageUrl'] != null && item['imageUrl'] != '') {
        try {
          await _storage.refFromURL(item['imageUrl']).delete();
        } catch (_) {}
      }

      setState(() => _menuItems.removeAt(index));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Menu item deleted')),
      );
    } catch (e) {
      print('Error deleting menu item: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete menu item: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please log in to manage menus'),
        ),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text(
          "Manage Menus",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: kMaincolor,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
              onPressed: _addMenuItem,
              icon: const Icon(Icons.add, color: Colors.white))
        ],
      ),
      body: _menuItems.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.fastfood, size: 100, color: Colors.grey[300]),
                    const SizedBox(height: 20),
                    const Text(
                      "No menu items yet",
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Add your first menu item so customers can see it!",
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      onPressed: _addMenuItem,
                      icon: const Icon(Icons.add),
                      label: const Text(
                        "Add Menu Item",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kMaincolor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _menuItems.length,
              itemBuilder: (context, index) {
                final item = _menuItems[index];
                final price = item['price'] ?? 0.0;

                return Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image
                        (item['imageUrl'] != null && item['imageUrl'] != '')
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  item['imageUrl'],
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(Icons.fastfood, size: 70, color: Colors.grey),
                        const SizedBox(width: 12),
                        // Name & description
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['name'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item['description'] ?? '',
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Trailing price & delete
                        Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Rs. ${(price as num).toStringAsFixed(2)}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 10),
                            IconButton(
                              padding: EdgeInsets.zero,
                              iconSize: 24,
                              onPressed: () => _deleteMenuItem(index),
                              icon: const Icon(Icons.delete, color: Colors.red),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kMaincolor,
        onPressed: _addMenuItem,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
