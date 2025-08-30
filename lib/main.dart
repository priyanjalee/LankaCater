import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Screens and Pages
import 'package:lankacater/screens/login_page.dart';
import 'package:lankacater/pages/choose_role_page.dart';
import 'package:lankacater/pages/customer_home_page.dart';
import 'package:lankacater/pages/caterer_home_page.dart';
import 'package:lankacater/pages/caterer_form_page.dart';
import 'package:lankacater/pages/reset_password_page.dart';
import 'package:lankacater/screens/onboard_screen.dart';
import 'package:lankacater/pages/customer_profile_page.dart';
import 'package:lankacater/pages/caterer_profile_page.dart';

// Quick Actions Pages
import 'package:lankacater/pages/orders_page.dart';
import 'package:lankacater/pages/event_page.dart';
import 'package:lankacater/pages/manage_menu_page.dart';
import 'package:lankacater/pages/manage_gallery_page.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Handling a background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Request permission for iOS
  await FirebaseMessaging.instance.requestPermission();

  // Background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

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
        '/home': (context) => const HomeRedirectPage(),

        // Quick Actions & Bottom Nav Pages
        '/orders': (context) => const OrdersPage(),
        '/events': (context) => const EventsPage(),
        '/manage-menu': (context) => const ManageMenuPage(),
        '/manage-gallery': (context) => const ManageGalleryPage(),

        // Profile Pages
        '/customer-profile': (context) => const CustomerProfilePage(),
        '/caterer-profile': (context) => const CatererProfilePage(),
      },
      navigatorObservers: [
        FirebaseAnalyticsObserver(analytics: analytics),
      ],
    );
  }
}

/// Shared helper function to determine landing/home page
Future<Widget> getLandingOrHomePage() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return const OnboardingScreen();

  // Save FCM token for the current user
  final fcmToken = await FirebaseMessaging.instance.getToken();
  if (fcmToken != null) {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'fcmToken': fcmToken,
    }, SetOptions(merge: true));
  }

  // Check if caterer profile exists
  final catererDoc =
      await FirebaseFirestore.instance.collection('caterers').doc(user.uid).get();
  if (catererDoc.exists) return const CatererHomePage();

  // Check user's role
  final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
  final role = userDoc.data()?['role'];

  if (role == 'Customer') return const CustomerHomePage();
  if (role == 'Cater') return const CatererFormPage();

  return const ChooseRolePage();
}

/// Wrapper to decide landing page after login
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: getLandingOrHomePage(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return snapshot.data ?? const OnboardingScreen();
        } else {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
      },
    );
  }
}

/// Decides whether to go to Caterer or Customer home (used for /home route)
class HomeRedirectPage extends StatelessWidget {
  const HomeRedirectPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: getLandingOrHomePage(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return snapshot.data ?? const OnboardingScreen();
        }
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
