import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:lankacater/constants/colors.dart';

class ChooseRolePage extends StatefulWidget {
  const ChooseRolePage({super.key});

  @override
  State<ChooseRolePage> createState() => _ChooseRolePageState();
}

class _ChooseRolePageState extends State<ChooseRolePage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _saveRole(BuildContext context, String role) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Show modern loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(kMaincolor),
                  strokeWidth: 3,
                ),
                const SizedBox(height: 16),
                Text(
                  'Setting up your profile...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      try {
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
      } catch (e) {
        Navigator.pop(context); // Dismiss loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required String role,
    required List<Color> gradientColors,
    required int index,
  }) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 600 + (index * 200)),
          tween: Tween<double>(begin: 0.0, end: 1.0),
          curve: Curves.elasticOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Material(
                  elevation: 0,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _saveRole(context, role),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          colors: [Colors.white, Colors.grey[50]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: Colors.grey[200]!,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: kMaincolor.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: gradientColors,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: gradientColors[0].withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Icon(
                              icon,
                              size: 32,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2D3748),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  description,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey[600],
                                    height: 1.4,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: kMaincolor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.arrow_forward_ios,
                              color: kMaincolor,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: kMaincolor,
        automaticallyImplyLeading: false,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/login');
          },
        ),
        title: const Text(
          'Choose Your Role',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [kMaincolor, kMaincolor.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 40),
              
              // Header Section
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [kMaincolor, kMaincolor.withOpacity(0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: kMaincolor.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person_pin_circle,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Welcome to LankaCater!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Choose your role to get started with the perfect catering experience',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        height: 1.5,
                        letterSpacing: 0.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 50),
              
              // Role Cards
              _buildRoleCard(
                context: context,
                title: 'Customer',
                description: 'Discover and order from the best caterers in your area',
                icon: Icons.person_outline,
                role: 'Customer',
                gradientColors: [
                  const Color(0xFF667eea),
                  const Color(0xFF764ba2),
                ],
                index: 0,
              ),
              
              const SizedBox(height: 20),
              
              _buildRoleCard(
                context: context,
                title: 'Caterer',
                description: 'Showcase your services and grow your catering business',
                icon: Icons.restaurant_menu_outlined,
                role: 'Cater',
                gradientColors: [
                  const Color(0xFFf093fb),
                  const Color(0xFFf5576c),
                ],
                index: 1,
              ),
              
              const SizedBox(height: 40),
              
              // Footer
              FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  'You can always change this later in settings',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}