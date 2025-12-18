import 'package:ai_models/views/pages/chat_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'dart:ui';

class SignInpage extends StatefulWidget {
  const SignInpage({super.key});

  @override
  State<SignInpage> createState() => _SignInpageState();
}

class _SignInpageState extends State<SignInpage> {
  final emailcontroller = TextEditingController();
  final passwordcontroller = TextEditingController();
  bool obsecurePassword = true;
  final formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    emailcontroller.dispose();
    passwordcontroller.dispose();
    super.dispose();
  }

  Future<void> loginwithEmailandPassword() async {
    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: emailcontroller.text.trim(),
            password: passwordcontroller.text.trim(),
          );
      print('Login successful: ${userCredential.user?.email}');
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      throw e.message ?? 'Login failed';
    } catch (e) {
      print('General Error: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text(
              'Contact us',
              style: TextStyle(color: Colors.white70),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Continue with Password',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 50),

                _buildTextField(
                  controller: emailcontroller,
                  hintText: 'Email',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 20),

                _buildTextField(
                  controller: passwordcontroller,
                  hintText: 'Password',
                  obscureText: obsecurePassword,
                  onToggleVisibility: () {
                    setState(() => obsecurePassword = !obsecurePassword);
                  },
                ),
                const SizedBox(height: 40),

                ElevatedButton(
                  onPressed: () async {
                    
                    if (!formKey.currentState!.validate()) {
                      print('Form validation failed');
                      return;
                    }

                    print('Form validated, attempting login...');
                    print('Email: ${emailcontroller.text.trim()}');

                    final navigator = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);

                    // Show loading dialog
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      barrierColor: Colors.black.withOpacity(0.3),
                      builder: (context) {
                        return BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                          child: Center(
                            child: Lottie.asset(
                              'assets/images/Loading animation blue.json',
                              width: 120,
                              height: 120,
                              fit: BoxFit.contain,
                            ),
                          ),
                        );
                      },
                    );

                    try {
                      await loginwithEmailandPassword();
                      navigator.pop(); 

                      
                      navigator.pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const ChatScreen(),
                        ),
                        (Route<dynamic> route) => false,
                      );
                    } catch (e) {
                      navigator.pop(); // Close loading dialog

                      // Show error message
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text("Login failed: ${e.toString()}"),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5379F6),
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Login',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    TextInputType? keyboardType,
    VoidCallback? onToggleVisibility,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF262626),
        borderRadius: BorderRadius.circular(25),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey[400]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 20,
          ),
          suffixIcon: onToggleVisibility != null
              ? IconButton(
                  icon: Icon(
                    obscureText
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey,
                    size: 20,
                  ),
                  onPressed: onToggleVisibility,
                )
              : null,
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter $hintText';
          }
          if (hintText == 'Email' && !value.contains('@')) {
            return 'Please enter a valid email';
          }
          return null;
        },
      ),
    );
  }
}