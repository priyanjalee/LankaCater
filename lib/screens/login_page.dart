import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/services.dart';

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

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isAnimationInitialized = false;
  
  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupAnimations();
      _setupKeyboardListeners();
    });
  }

  void _setupAnimations() {
    if (!mounted) return;
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController!,
      curve: const Interval(0.0, 0.8, curve: Curves.easeInOut),
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController!,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutBack),
    ));
    
    setState(() {
      _isAnimationInitialized = true;
    });
    
    _animationController!.forward();
  }

  void _setupKeyboardListeners() {
    _emailFocusNode.addListener(() {
      if (!_emailFocusNode.hasFocus) {
        FocusScope.of(context).requestFocus(FocusNode());
      }
    });
    
    _passwordFocusNode.addListener(() {
      if (!_passwordFocusNode.hasFocus) {
        FocusScope.of(context).requestFocus(FocusNode());
      }
    });
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    return emailRegex.hasMatch(email);
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
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
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const CatererHomePage()),
          );
        }
        return;
      }

      // Check user's role
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final role = userDoc.data()?['role'];

      if (!mounted) return;

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
      if (mounted) {
        _showErrorSnackBar("Error checking user role. Please try again.");
      }
    }
  }

  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    
    _dismissKeyboard();
    
    if (_isLoading) return; // Prevent multiple calls
    
    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      await FirebaseAnalytics.instance.logLogin(loginMethod: 'email');
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user != null && mounted) {
        await _navigateBasedOnRole(user);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String message = "Login failed. Please check your credentials.";
        switch (e.code) {
          case 'user-not-found':
            message = "No user found with this email address.";
            break;
          case 'wrong-password':
            message = "Incorrect password. Please try again.";
            break;
          case 'invalid-email':
            message = "Please enter a valid email address.";
            break;
          case 'user-disabled':
            message = "This account has been disabled. Contact support.";
            break;
          case 'too-many-requests':
            message = "Too many failed attempts. Please try again later.";
            break;
          case 'invalid-credential':
            message = "Invalid credentials. Please check your email and password.";
            break;
          case 'network-request-failed':
            message = "Network error. Please check your internet connection.";
            break;
        }
        _showErrorSnackBar(message);
      }
    } catch (e) {
      if (kDebugMode) print('Email login error: $e');
      if (mounted) {
        _showErrorSnackBar("An unexpected error occurred. Please try again.");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_isGoogleLoading) return; // Prevent multiple calls
    
    _dismissKeyboard();
    
    setState(() => _isGoogleLoading = true);
    
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      
      if (googleUser == null) {
        // User cancelled the sign-in
        if (mounted) {
          setState(() => _isGoogleLoading = false);
        }
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAnalytics.instance.logLogin(loginMethod: 'google');
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      
      final user = userCredential.user;
      if (user != null && mounted) {
        await _navigateBasedOnRole(user);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String message = "Google Sign-In failed. Please try again.";
        switch (e.code) {
          case 'account-exists-with-different-credential':
            message = "An account already exists with this email using a different sign-in method.";
            break;
          case 'invalid-credential':
            message = "Invalid Google credentials. Please try again.";
            break;
          case 'operation-not-allowed':
            message = "Google Sign-In is not enabled. Contact support.";
            break;
          case 'user-disabled':
            message = "Your account has been disabled. Contact support.";
            break;
          case 'network-request-failed':
            message = "Network error. Please check your internet connection.";
            break;
        }
        _showErrorSnackBar(message);
      }
    } catch (e) {
      if (kDebugMode) print('Google sign-in error: $e');
      if (mounted) {
        _showErrorSnackBar("Google Sign-In failed. Please try again.");
      }
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  void _goToResetPasswordPage() {
    _dismissKeyboard();
    
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showErrorSnackBar("Please enter your email address first.");
      return;
    }
    if (!_isValidEmail(email)) {
      _showErrorSnackBar("Please enter a valid email address.");
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResetPasswordPage(initialEmail: email),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Widget _buildAnimatedContent() {
    if (!_isAnimationInitialized || _fadeAnimation == null || _slideAnimation == null) {
      // Return non-animated version while animations are initializing
      return _buildMainContent();
    }
    
    return FadeTransition(
      opacity: _fadeAnimation!,
      child: SlideTransition(
        position: _slideAnimation!,
        child: _buildMainContent(),
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 40),
        
        // Welcome Text
        Text(
          'Sign in to your account',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your credentials to continue',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            height: 1.4,
          ),
        ),
        const SizedBox(height: 50),

        // Login Form Card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.08),
                spreadRadius: 0,
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                spreadRadius: 0,
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Email Field
                TextFormField(
                  controller: _emailController,
                  focusNode: _emailFocusNode,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  onFieldSubmitted: (_) {
                    FocusScope.of(context).requestFocus(_passwordFocusNode);
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!_isValidEmail(value.trim())) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    hintText: 'Enter your email',
                    prefixIcon: Icon(
                      Icons.email_outlined,
                      color: kMaincolor,
                      size: 22,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: kMaincolor, width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Password Field
                TextFormField(
                  controller: _passwordController,
                  focusNode: _passwordFocusNode,
                  obscureText: !_isPasswordVisible,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) {
                    _signInWithEmail();
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    prefixIcon: Icon(
                      Icons.lock_outlined,
                      color: kMaincolor,
                      size: 22,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: Colors.grey[600],
                        size: 22,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: kMaincolor, width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
                
                // Forgot Password
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _goToResetPasswordPage,
                    style: TextButton.styleFrom(
                      foregroundColor: kMaincolor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Sign In Button
                ElevatedButton(
                  onPressed: (_isLoading || _isGoogleLoading) 
                      ? null 
                      : _signInWithEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kMaincolor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[400],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                    shadowColor: kMaincolor.withOpacity(0.3),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Divider
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Or continue with',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Google Sign In Button
        ElevatedButton.icon(
          onPressed: (_isGoogleLoading || _isLoading) 
              ? null 
              : _signInWithGoogle,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            disabledBackgroundColor: Colors.grey[100],
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey[300]!),
            ),
            elevation: 0,
          ),
          icon: _isGoogleLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                  ),
                )
              : Image.asset(
                  'assests/images/ggl.png',
                  height: 20,
                  width: 20,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.account_circle,
                      size: 20,
                      color: Colors.grey[600],
                    );
                  },
                ),
          label: Text(
            _isGoogleLoading ? 'Signing in...' : 'Continue with Google',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Sign Up Link
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Don't have an account? ",
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            GestureDetector(
              onTap: () {
                _dismissKeyboard();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RegisterPage(),
                  ),
                );
              },
              child: Text(
                "Sign Up",
                style: TextStyle(
                  color: kMaincolor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 32),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _dismissKeyboard,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: kMaincolor,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
            onPressed: () {
              _dismissKeyboard();
              Navigator.pushReplacementNamed(context, '/onboarding');
            },
          ),
          title: const Text(
            'Welcome Back',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: _buildAnimatedContent(),
            ),
          ),
        ),
      ),
    );
  }
}