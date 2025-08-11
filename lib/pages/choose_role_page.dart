import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:lankacater/constants/colors.dart';

class ChooseRolePage extends StatelessWidget {
  const ChooseRolePage({super.key});

  Future<void> _saveRole(BuildContext context, String role) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      // Save role to 'users' collection
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      await userRef.set({'role': role}, SetOptions(merge: true));

      // Log to analytics
      await FirebaseAnalytics.instance
          .logEvent(name: 'role_selected', parameters: {'role': role});

      Navigator.pop(context); // Dismiss loading dialog

      // Navigate based on role
      if (role == 'Customer') {
        Navigator.pushReplacementNamed(context, '/customer_home');
      } else {
        // Check if Caterer profile exists in 'caterers' collection
        final catererRef =
            FirebaseFirestore.instance.collection('caterers').doc(user.uid);
        final catererDoc = await catererRef.get();

        if (catererDoc.exists) {
          Navigator.pushReplacementNamed(context, '/caterer_home');
        } else {
          Navigator.pushReplacementNamed(context, '/caterer_form');
        }
      }
    }
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required String role,
  }) {
    return GestureDetector(
      onTap: () => _saveRole(context, role),
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: kMaincolor.withOpacity(0.2),
                child: Icon(icon, size: 30, color: kMaincolor),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: kMaincolor)),
                    const SizedBox(height: 4),
                    Text(description,
                        style:
                            const TextStyle(fontSize: 14, color: Colors.grey)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: kMaincolor, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: kMaincolor,
        automaticallyImplyLeading: false,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/login');
          },
        ),
        title: const Text(
          'Choose Your Role',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Text(
              'Select your role to continue:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            _buildRoleCard(
              context: context,
              title: 'Customer',
              description: 'Looking to order from the best caterers nearby.',
              icon: Icons.person,
              role: 'Customer',
            ),
            const SizedBox(height: 20),
            _buildRoleCard(
              context: context,
              title: 'Caterer',
              description: 'Provide catering services and grow your business.',
              icon: Icons.restaurant_menu,
              role: 'Cater',
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
