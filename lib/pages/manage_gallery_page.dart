import 'package:flutter/material.dart';
import '../../constants/colors.dart';

class ManageGalleryPage extends StatelessWidget {
  const ManageGalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Gallery"),
        backgroundColor: kMaincolor,
      ),
      body: const Center(
        child: Text(
          "Upload and showcase photos of your dishes here.",
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
