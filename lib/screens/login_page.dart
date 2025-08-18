import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

import 'package:lankacater/constants/colors.dart';
import 'package:lankacater/pages/reset_password_page.dart';
import 'register_page.dart';
import '../pages/choose_role_page.dart';
import '../pages/caterer_home_page.dart';
import '../pages/caterer_form_page.dart';
import '../pages/customer_home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    return emailRegex.hasMatch(email);
  }

  Future<void> _navigateBasedOnRole(User user) async {
    try {
      // Check if caterer profile exists first
      final catererDoc = await FirebaseFirestore.instance
          .collection('caterers')
          .doc(user.uid)
          .get();

      if (catererDoc.exists) {
        // Returning caterer → Home
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CatererHomePage()),
        );
        return;
      }

      // Check user's role
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final role = userDoc.data()?['role'];

      if (role == 'Customer') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CustomerHomePage()),
        );
      } else if (role == 'Cater') {
        // First-time caterer → show form
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CatererFormPage()),
        );
      } else {
        // Role not selected → choose role
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ChooseRolePage()),
        );
      }
    } catch (e) {
      if (kDebugMode) print('Navigation error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error checking user role.")),
      );
    }
  }

  Future<void> _signInWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (!_isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid email address.")),
      );
      return;
    }

    try {
      await FirebaseAnalytics.instance.logLogin(loginMethod: 'email');
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user != null) {
        await _navigateBasedOnRole(user);
      }
    } catch (e) {
      if (kDebugMode) print('Email login error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login failed. Please check credentials.")),
      );
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;
      if (user != null) {
        await _navigateBasedOnRole(user);
      }
    } catch (e) {
      if (kDebugMode) print('Google sign-in error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Google Sign-In failed.")),
      );
    }
  }

  void _goToResetPasswordPage() {
    final email = _emailController.text.trim();
    if (!_isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid email address to reset.")),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ResetPasswordPage(initialEmail: email)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: kMaincolor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/onboarding');
          },
        ),
        title: const Text(
          'LOGIN',
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'example@email.com',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _goToResetPasswordPage,
                  child: const Text('Forgot password ?', style: TextStyle(color: Colors.black54)),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _signInWithEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kMaincolor,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 4,
                ),
                child: const Text('Sign in', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
              const SizedBox(height: 20),
              const Divider(),
              const Center(child: Text("You can connect with")),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _signInWithGoogle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: Image.asset('assests/images/ggl.png', height: 24),
                label: const Text("Sign Up with Google", style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don’t have an account? "),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterPage()),
                    ),
                    child: Text("Sign up here", style: TextStyle(color: kMaincolor)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
