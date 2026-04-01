import 'dart:ui';
import 'package:emerge_x/views/pages/Interface_signup.dart';
import 'package:emerge_x/views/pages/Sign_inpage.dart';
import 'package:emerge_x/views/chat/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:get/state_manager.dart';
import 'package:provider/provider.dart';
import 'package:emerge_x/shared/ProviderX/provider.dart';
import 'package:lottie/lottie.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class Intropage extends StatefulWidget {
  const Intropage({super.key});

  @override
  State<Intropage> createState() => _IntropageState();
}

class _IntropageState extends State<Intropage> with TickerProviderStateMixin {
  late AnimationController _controller;
  int _currentIndex = 0;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late AnimationController _animationControler;

  final List<String> _phrases = [
    "EmergeX",
    "Design with intent",
    "Build the future",
    "Let's Invent",
    "Let's Chit-chat",
    "Let's Create",
    "Let's Discover",
    "Let's Explore"
    "Let's Design",
    "Let's Go",
  ];

  @override
  void initState() {
    super.initState();

    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 3500),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            setState(() {
              _currentIndex = (_currentIndex + 1) % _phrases.length;
            });
            _controller.forward(from: 0);
          }
        });
    _controller.forward();

    _animationControler = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationControler,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationControler,
            curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
          ),
        );
    _animationControler.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isConfirmed = true;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  Future<void> signInWithGoogle() async {
    final userprovider = Provider.of<Userprovider>(context, listen: false);
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.authenticate();
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

          String lastname =
              appleCredential.familyName ??
              user.displayName?.split(' ').skip(1).join(' ') ??
              '';
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
     backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      body: FadeTransition(
        opacity: _fadeAnimation,

        child: SlideTransition(
          position: _slideAnimation,
          child: Stack(
            children: [
              Center(
                child: Positioned(
                  top: MediaQuery.of(context).size.height * 0.05,
                  left: 0,
                  right: 0,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      const double stageWidth = 300.0;
                      const double circleRadius =
                          10.0; // CHANGE THIS value to make the circle bigger (e.g. 10.0). Note: If you make it too big, it might clip at the edges.

                      double circleX = 150.0;

                      if (_controller.value <= 0.4) {
                        final double progress = Curves.easeOutQuart.transform(
                          (_controller.value / 0.4).clamp(0.0, 1.0),
                        );

                        circleX = 160.0 - (320.0 * progress);
                      } else if (_controller.value <= 0.55) {
                        circleX = -160.0;
                      } else if (_controller.value <= 0.95) {
                        final double progress = Curves.easeInOutQuad.transform(
                          ((_controller.value - 0.55) / 0.4).clamp(0.0, 1.0),
                        );
                        circleX = -160.0 + (320.0 * progress);
                      } else {
                        circleX = 160.0;
                      }

                      double gradientStop = (circleX + 160.0) / 320.0;
                      gradientStop = gradientStop.clamp(0.0, 1.0);

                      return SizedBox(
                        width: 350,
                        height: 60,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // The Text with Mask
                            ShaderMask(
                              shaderCallback: (rect) {
                                return LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  stops: [gradientStop, gradientStop + 0.01],
                                  colors: const [
                                    Colors.transparent,
                                    Colors.white,
                                  ],
                                ).createShader(rect);
                              },
                              blendMode: BlendMode.dstIn,
                              child: Center(
                                child: Text(
                                  _phrases[_currentIndex],
                                  textAlign: TextAlign.center,
                                  style:  TextStyle(
                                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                                    fontSize: 34, // Big bold text
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),

                            // The Circle
                            Positioned(
                              left: (320.0 / 2) + circleX - circleRadius,
                              child: Container(
                                width: circleRadius * 3,
                                height: circleRadius * 3,
                                decoration:  BoxDecoration(
                                 color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white54,
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              Container(width: double.infinity),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  padding: EdgeInsets.fromLTRB(24, 32, 24, 48),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark ?  Color.fromARGB(255, 20, 20, 22) : Colors.black,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(37),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                                filter: ImageFilter.blur(
                                  sigmaX: 5.0,
                                  sigmaY: 5.0,
                                ),
                                child: Lottie.asset(
                                  'assets/images/Loading animation blue.json',
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.contain,
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
                                  content: Text(
                                    "Apple sign-in failed: ${e.toString()}",
                                  ),
                                ),
                              );
                            }
                          }
                        },

                        child: Container(
                          width: double.infinity,
                          height: 49,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image(
                                image: AssetImage(
                                  'assets/images/apple-logo.png',
                                ),
                                width: 24,
                                height: 24,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Continue with Apple',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black,
                                  fontSize: 17,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 14),
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
                                filter: ImageFilter.blur(
                                  sigmaX: 5.0,
                                  sigmaY: 5.0,
                                ),
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
                                  content: Text(
                                    "Google sign-in failed: ${e.toString()}",
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          height: 49,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1E),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Color(0xFF1C1C1E)),
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
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 14),
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
                          backgroundColor: Color(0xFF1C1C1E),
                          foregroundColor: Colors.black,
                          minimumSize: const Size(double.infinity, 49),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(
                              color: Color(0xFF1C1C1E),
                              width: 1,
                            ),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            SizedBox(width: 12),
                            Text(
                              'Log in',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Sign Up Button
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) {
                                return ChatScreen();
                              },
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          minimumSize: const Size(double.infinity, 49),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(
                              color: Color.fromARGB(255, 150, 150, 150),
                              width: 1,
                            ),
                          ),
                        ),
                        child: const Text(
                          'Sign up',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color.fromARGB(255, 255, 255, 255),
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
