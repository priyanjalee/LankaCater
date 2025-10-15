import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:lankacater/constants/colors.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with TickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _rePasswordController = TextEditingController();
  
  final _formKey = GlobalKey<FormState>();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _rePasswordFocusNode = FocusNode();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isPasswordVisible = false;
  bool _isRePasswordVisible = false;
  bool _acceptTerms = false;
  bool _isAnimationInitialized = false;

  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupAnimations();
    });
  }

  void _setupAnimations() {
    if (!mounted) return;
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
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

  @override
  void dispose() {
    _animationController?.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _rePasswordController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _phoneFocusNode.dispose();
    _passwordFocusNode.dispose();
    _rePasswordFocusNode.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    return emailRegex.hasMatch(email);
  }

  bool _isValidPhoneNumber(String phone) {
    final phoneRegex = RegExp(r'^(\+94|0)?[0-9]{9,10}$');
    return phoneRegex.hasMatch(phone.replaceAll(' ', ''));
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (!_acceptTerms) {
      _showErrorSnackBar("Please accept the Terms & Conditions");
      return;
    }

    _dismissKeyboard();

    if (_isLoading) return;

    setState(() => _isLoading = true);

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    try {
      await FirebaseAnalytics.instance.logSignUp(signUpMethod: 'email');
      
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await userCredential.user?.updateDisplayName(name);

      // Save user to Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'name': name,
        'email': email,
        'phone': phone,
        'role': 'customer',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _showSuccessSnackBar("Registration successful! Welcome to LankaCater!");
        
        // Navigate after a brief delay to show success message
        await Future.delayed(const Duration(seconds: 1));
        
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/customer_form');
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String message = "Registration failed. Please try again.";
        switch (e.code) {
          case 'weak-password':
            message = "Password is too weak. Use at least 6 characters.";
            break;
          case 'email-already-in-use':
            message = "An account already exists with this email address.";
            break;
          case 'invalid-email':
            message = "Please enter a valid email address.";
            break;
          case 'operation-not-allowed':
            message = "Email registration is not enabled. Contact support.";
            break;
          case 'network-request-failed':
            message = "Network error. Please check your internet connection.";
            break;
        }
        _showErrorSnackBar(message);
      }
    } catch (e) {
      if (kDebugMode) print('Registration error: $e');
      if (mounted) {
        _showErrorSnackBar("An unexpected error occurred. Please try again.");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signUpWithGoogle() async {
    if (_isGoogleLoading) return;
    
    _dismissKeyboard();
    
    setState(() => _isGoogleLoading = true);
    
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      
      if (googleUser == null) {
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

      await FirebaseAnalytics.instance.logSignUp(signUpMethod: 'google');
      final userCredential = await _auth.signInWithCredential(credential);
      
      final user = userCredential.user;
      if (user != null && mounted) {
        // Save user to Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': user.displayName ?? 'Google User',
          'email': user.email ?? '',
          'phone': '',
          'role': 'customer',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        _showSuccessSnackBar("Registration successful! Welcome to LankaCater!");
        
        await Future.delayed(const Duration(seconds: 1));
        
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/customer_form');
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String message = "Google Sign-Up failed. Please try again.";
        switch (e.code) {
          case 'account-exists-with-different-credential':
            message = "An account already exists with this email using a different sign-in method.";
            break;
          case 'invalid-credential':
            message = "Invalid Google credentials. Please try again.";
            break;
          case 'operation-not-allowed':
            message = "Google Sign-Up is not enabled. Contact support.";
            break;
          case 'network-request-failed':
            message = "Network error. Please check your internet connection.";
            break;
        }
        _showErrorSnackBar(message);
      }
    } catch (e) {
      if (kDebugMode) print('Google sign-up error: $e');
      if (mounted) {
        _showErrorSnackBar("Google Sign-Up failed. Please try again.");
      }
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
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

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildAnimatedContent() {
    if (!_isAnimationInitialized || _fadeAnimation == null || _slideAnimation == null) {
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
        const SizedBox(height: 30),
        
        // Welcome Text
        Text(
          'Create your account',
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
          'Join LankaCater and discover amazing food experiences',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            height: 1.4,
          ),
        ),
        const SizedBox(height: 40),

        // Registration Form Card
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
                // Name Field
                _buildTextField(
                  controller: _nameController,
                  focusNode: _nameFocusNode,
                  label: 'Full Name',
                  hint: 'W.K.C.P. Bandara',
                  prefixIcon: Icons.person_outline,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_emailFocusNode),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your full name';
                    }
                    if (value.trim().length < 2) {
                      return 'Name must be at least 2 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                
                // Email Field
                _buildTextField(
                  controller: _emailController,
                  focusNode: _emailFocusNode,
                  label: 'Email Address',
                  hint: 'example@email.com',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_phoneFocusNode),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email address';
                    }
                    if (!_isValidEmail(value.trim())) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                
                // Phone Field
                _buildTextField(
                  controller: _phoneController,
                  focusNode: _phoneFocusNode,
                  label: 'Phone Number',
                  hint: '077 123 4567',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocusNode),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your phone number';
                    }
                    if (!_isValidPhoneNumber(value.trim())) {
                      return 'Please enter a valid phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                
                // Password Field
                _buildTextField(
                  controller: _passwordController,
                  focusNode: _passwordFocusNode,
                  label: 'Password',
                  hint: 'Create a strong password',
                  prefixIcon: Icons.lock_outlined,
                  obscureText: !_isPasswordVisible,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_rePasswordFocusNode),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: Colors.grey[600],
                      size: 22,
                    ),
                    onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                
                // Confirm Password Field
                _buildTextField(
                  controller: _rePasswordController,
                  focusNode: _rePasswordFocusNode,
                  label: 'Confirm Password',
                  hint: 'Re-enter your password',
                  prefixIcon: Icons.lock_outline,
                  obscureText: !_isRePasswordVisible,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _register(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isRePasswordVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: Colors.grey[600],
                      size: 22,
                    ),
                    onPressed: () => setState(() => _isRePasswordVisible = !_isRePasswordVisible),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 24),
                
                // Terms & Conditions Checkbox
                Row(
                  children: [
                    Checkbox(
                      value: _acceptTerms,
                      onChanged: (value) => setState(() => _acceptTerms = value ?? false),
                      activeColor: kMaincolor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _acceptTerms = !_acceptTerms),
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                            children: [
                              const TextSpan(text: 'I agree to the '),
                              TextSpan(
                                text: 'Terms & Conditions',
                                style: TextStyle(
                                  color: kMaincolor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const TextSpan(text: ' and '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: TextStyle(
                                  color: kMaincolor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Sign Up Button
                ElevatedButton(
                  onPressed: (_isLoading || _isGoogleLoading) ? null : _register,
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
                          'Create Account',
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
                'Or sign up with',
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
        
        // Google Sign Up Button
        ElevatedButton.icon(
          onPressed: (_isGoogleLoading || _isLoading) ? null : _signUpWithGoogle,
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
            _isGoogleLoading ? 'Signing up...' : 'Continue with Google',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Sign In Link
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Already have an account? ",
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            GestureDetector(
              onTap: () {
                _dismissKeyboard();
                Navigator.pop(context);
              },
              child: Text(
                "Sign In",
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

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    TextInputAction textInputAction = TextInputAction.next,
    Function(String)? onFieldSubmitted,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(
          prefixIcon,
          color: kMaincolor,
          size: 22,
        ),
        suffixIcon: suffixIcon,
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
              Navigator.pop(context);
            },
          ),
          title: const Text(
            'Create Account',
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