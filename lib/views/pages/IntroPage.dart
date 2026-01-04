import 'dart:ui';
import 'package:ai_models/views/pages/Interface_signup.dart';
import 'package:ai_models/views/pages/Sign_inpage.dart';
import 'package:ai_models/views/pages/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:ai_models/shared/ProviderX/provider.dart';
import 'package:lottie/lottie.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class Intropage extends StatefulWidget {
  const Intropage({super.key});

  @override
  State<Intropage> createState() => _IntropageState();
}

class _IntropageState extends State<Intropage> {
  bool _isConfirmed = true;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  Future<void> signInWithGoogle() async {
    final userprovider = Provider.of<Userprovider>(context, listen: false);
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn
          .authenticate();
      if (googleUser == null) {
        throw Exception("Sign-in cancelled by user.");
      }
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);
      final User? user = userCredential.user;
      if (user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!userDoc.exists) {
          String username = user.email!.split('@').first;
          String firstname = user.displayName?.split(' ').first ?? 'User';
          String lastname =
              user.displayName?.split(' ').skip(1).join(' ') ?? '';
          String email = user.email ?? '';

          await userprovider.saveUserToFirestore(
            userId: user.uid,
            username: username,
            firstname: firstname,
            lastname: lastname,
            email: email,
          );
        } else {
          await userprovider.loadUserData(userId: user.uid);
        }
      }
    } catch (e) {
      print('Error signing in with Google: $e ');
      rethrow;
    }
  }

  Future<void> signInWithApple() async {
    final userProvider = Provider.of<Userprovider>(context, listen: false);
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final AuthCredential credential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!userDoc.exists) {
          String username = user.email?.split('@').first ?? 'apple_user';
          String firstname =
              appleCredential.givenName ?? user.displayName ?? 'User';
          String email = appleCredential.email ?? user.email ?? '';

          String lastname = appleCredential.familyName ?? user.displayName?.split(' ').skip(1).join(' ') ?? '';
          await userProvider.saveUserToFirestore(
            userId: user.uid,
            username: username,
            firstname: firstname,
            lastname: lastname,
            email: email,
          );
        } else {
          await userProvider.loadUserData(userId: user.uid);
        }
      }
    } catch (e) {
      print('Error sigining in with Apple: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: Text(
              'Contact us',
              style: TextStyle(
                fontWeight: FontWeight.w400,
                letterSpacing: 0.5,
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Logo Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.chat_bubble_rounded,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),

              // App Name
              const Text(
                'CogiChat',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 36,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),

              const Spacer(flex: 3),

              // Button 1: Continue with Google
              InkWell(
                onTap: () async {
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);

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
                    await signInWithGoogle();
                    if (navigator.mounted) navigator.pop();

                    if (navigator.mounted) {
                      navigator.pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const ChatScreen(),
                        ),
                        (Route<dynamic> route) => false,
                      );
                    }
                  } catch (e) {
                    if (navigator.mounted) {
                      navigator.pop();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text("Google sign-in failed: ${e.toString()}"),
                        ),
                      );
                    }
                  }
                },
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image(
                        image: AssetImage('assets/images/search.png'),
                        width: 24,
                        height: 24,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Continue with Google',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              InkWell(
                onTap: () async {
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);

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
                    await signInWithApple();
                    if (navigator.mounted) navigator.pop();

                    if (navigator.mounted) {
                      navigator.pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const ChatScreen(),
                        ),
                        (Route<dynamic> route) => false,
                      );
                    }
                  } catch (e) {
                    if (navigator.mounted) {
                      navigator.pop();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text("Apple sign-in failed: ${e.toString()}"),
                        ),
                      );
                    }
                  }
                },
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image(
                        image: AssetImage('assets/images/apple-logo.png'),
                        width: 24,
                        height: 24,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Continue with Apple',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Button 3: Continue with Password
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) {
                        return SignInpage();
                      },
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.lock_outline, size: 24, color: Colors.black87),
                    SizedBox(width: 12),
                    Text(
                      'Continue with Password',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Sign Up Button
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) {
                        return InterfaceSignup();
                      },
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: const Text(
                  'Sign up',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              SizedBox(height: 12,),
              

              const Spacer(),

              // Checkbox and Policy Text Section
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _isConfirmed,
                      onChanged: (bool? newValue) {
                        setState(() {
                          _isConfirmed = newValue ?? false;
                        });
                      },
                      activeColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        text:
                            'I confirm that I have read and agree to CogiChat\'s ',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                          height: 1.4,
                        ),
                        children: <TextSpan>[
                          const TextSpan(
                            text: 'Terms of Use',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const TextSpan(text: ' and '),
                          const TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
