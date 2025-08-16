import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Screens and Pages
import 'package:lankacater/screens/login_page.dart';
import 'package:lankacater/pages/choose_role_page.dart';
import 'package:lankacater/pages/customer_home_page.dart';
import 'package:lankacater/pages/caterer_home_page.dart';
import 'package:lankacater/pages/caterer_form_page.dart';
import 'package:lankacater/pages/reset_password_page.dart';
import 'package:lankacater/screens/onboard_screen.dart';

// Quick Actions Pages
import 'package:lankacater/pages/orders_page.dart';
import 'package:lankacater/pages/event_page.dart';
import 'package:lankacater/pages/manage_menu_page.dart';
import 'package:lankacater/pages/manage_gallery_page.dart';
import 'package:lankacater/pages/caterer_profile_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  static final FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LankaCater',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Inter'),
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/choose_role': (context) => const ChooseRolePage(),
        '/customer_home': (context) => const CustomerHomePage(),
        '/caterer_home': (context) => const CatererHomePage(),
        '/caterer_form': (context) => const CatererFormPage(),
        '/reset_password': (context) =>
            const ResetPasswordPage(initialEmail: ''),
        '/onboarding': (context) => const OnboardingScreen(),

        // ✅ Home alias route - will redirect based on role
        '/home': (context) => const HomeRedirectPage(),

        // Quick Actions & Bottom Nav Pages
        '/orders': (context) => const OrdersPage(),
        '/events': (context) => const EventsPage(),
        '/manage-menu': (context) => const ManageMenuPage(),
        '/manage-gallery': (context) => const ManageGalleryPage(),
        '/edit-profile': (context) => const ProfilePage(),
      },
      navigatorObservers: [
        FirebaseAnalyticsObserver(analytics: analytics),
      ],
    );
  }
}

/// Decides whether to go to Caterer or Customer home
class HomeRedirectPage extends StatelessWidget {
  const HomeRedirectPage({super.key});

  Future<Widget> _getHomePage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const OnboardingScreen();

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final role = userDoc.data()?['role'];

    if (role == 'Cater') {
      final catererDoc = await FirebaseFirestore.instance
          .collection('caterers')
          .doc(user.uid)
          .get();
      return catererDoc.exists
          ? const CatererHomePage()
          : const CatererFormPage();
    } else if (role == 'Customer') {
      return const CustomerHomePage();
    } else {
      return const ChooseRolePage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _getHomePage(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return snapshot.data!;
        }
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<Widget> _getLandingPage() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return const OnboardingScreen();

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final role = userDoc.data()?['role'];

    if (role == 'Cater') {
      final catererDoc = await FirebaseFirestore.instance
          .collection('caterers')
          .doc(user.uid)
          .get();
      return catererDoc.exists
          ? const CatererHomePage()
          : const CatererFormPage();
    } else if (role == 'Customer') {
      return const CustomerHomePage();
    } else {
      return const ChooseRolePage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _getLandingPage(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return snapshot.data!;
        } else {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
      },
    );
  }
}
