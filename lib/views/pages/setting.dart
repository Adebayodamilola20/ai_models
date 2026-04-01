import 'package:emerge_x/shared/ProviderX/provider.dart';
import 'package:emerge_x/views/pages/IntroPage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:google_sign_in/google_sign_in.dart' as gauth;
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  final fulnamecontroler = TextEditingController();
  final usernamecontroller = TextEditingController();
  bool _hapticFeedback = true;
  bool _spellCheck = true;
  bool _separateMode = false;
  bool _backgroundConv = false;
  bool _autocomplete = true;
  bool _trending = true;
  bool _followUp = true;
  String _selectedAppearance = "System";

  Future<void> logout(BuildContext context) async {
    try {
      // Reverting to .instance as seen in Sign_inpage.dart
      final googleSignIn = gauth.GoogleSignIn.instance;
      await googleSignIn.signOut();
      await FirebaseAuth.instance.signOut();

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const Intropage()),
          (Route<dynamic> route) => false,
        );
      }

      // Using ScaffoldMessenger since onShowSnackbar is undefined here
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Logged out successfully"),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error logging out: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Map<String, dynamic>> _createPaymentIntent(
    String amount,
    String currency,
  ) async {
    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        'createPaymentIntent',
      );

      final response = await callable.call(<String, dynamic>{
        'amount': amount,
        'currency': currency,
      });

      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      print("Cloud Function Error: $e");
      throw Exception("Failed ov create payment intent");
    }
  }

  Future<void> _makePayment() async {
    final response = await _createPaymentIntent('1000', 'USD');

    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: response['client_secret'],
          merchantDisplayName: 'EmergeX AI',
          style: ThemeMode.dark,
        ),
      );
      await Stripe.instance.presentPaymentSheet();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Payment successful! Welcome to Pro.")),
      );
    } catch (e) {
      if (e is StripeException) {
        print("Error from Stripe : ${e.error.localizedMessage}");
      } else {
        print("UNforseen error: $e");
      }
    }
  }

  @override
  void dispose() {
    fulnamecontroler.dispose();
    usernamecontroller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      "Settings",
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: Icon(
                          Icons.close,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                          size: 20,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(6),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    const SizedBox(height: 20),
                    Consumer<Userprovider>(
                      builder: (context, provider, child) {
                        final firstName = provider.firstname.isNotEmpty
                            ? provider.firstname
                            : "S";
                        final lastName = provider.lastname.isNotEmpty
                            ? provider.lastname
                            : "";
                        final fullName = "$firstName $lastName";
                        final initial =
                            (firstName.isNotEmpty
                                ? firstName.substring(0, 1)
                                : "S") +
                            (lastName.isNotEmpty
                                ? lastName.substring(0, 1)
                                : "D");
                        final username = provider.username.isNotEmpty
                            ? provider.username
                            : "q2xcrnwnz6";

                        return Column(
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundColor: const Color(0xFF545456),
                              child: Text(
                                initial.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 29,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              fullName,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 24,
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              username,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton(
                              onPressed: () {
                                showModalBottomSheet(
                                  isScrollControlled: true,
                                  context: context,
                                  backgroundColor: Colors.transparent,
                                  barrierColor: Colors.black.withOpacity(0.3),
                                  builder: (context) {
                                    return BackdropFilter(
                                      filter: ImageFilter.blur(
                                        sigmaX: 10,
                                        sigmaY: 10,
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                          bottom: MediaQuery.of(
                                            context,
                                          ).viewInsets.bottom,
                                        ),
                                        child: Container(
                                          constraints: BoxConstraints(
                                            maxHeight:
                                                MediaQuery.of(
                                                  context,
                                                ).size.height *
                                                0.8,
                                          ),
                                          width: MediaQuery.of(
                                            context,
                                          ).size.width,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.1,
                                            ),
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                  top: Radius.circular(40.0),
                                                  bottom: Radius.circular(40.0),
                                                ),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(
                                                0.2,
                                              ),
                                            ),
                                          ),
                                          child: SingleChildScrollView(
                                            child: Padding(
                                              padding: const EdgeInsets.all(
                                                19.0,
                                              ),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Stack(
                                                    children: [
                                                      CircleAvatar(
                                                        radius: 60,
                                                        backgroundColor:
                                                            const Color(
                                                              0xFF545456,
                                                            ),
                                                        child: Text(
                                                          initial.toUpperCase(),
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 32,
                                                                color: Colors
                                                                    .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                      ),
                                                      Positioned(
                                                        bottom: 0,
                                                        right: 0,
                                                        child: CircleAvatar(
                                                          radius: 18,
                                                          backgroundColor:
                                                              Colors.black,
                                                          child: const Icon(
                                                            Icons
                                                                .camera_alt_outlined,
                                                            size: 18,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 25),
                                                  _buildLabel("Name"),
                                                  _buildInputField(
                                                    controller:
                                                        fulnamecontroler,
                                                    hintText: "Full Name",
                                                  ),
                                                  const SizedBox(height: 15),
                                                  _buildLabel("Username"),
                                                  _buildInputField(
                                                    controller:
                                                        usernamecontroller,
                                                    hintText: "Username",
                                                  ),
                                                  const SizedBox(height: 20),
                                                  const Padding(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                        ),
                                                    child: Text(
                                                      "Your profile helps people recognize you. Your name and username are also used in the EmergeX app.",
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                        color: Colors.white54,
                                                        fontSize: 13,
                                                        height: 1.4,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 30),
                                                  SizedBox(
                                                    width: 170.0,
                                                    height: 60,
                                                    child: ElevatedButton(
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            Theme.of(
                                                                  context,
                                                                ).brightness ==
                                                                Brightness.dark
                                                            ? Colors.white
                                                            : Colors.black,
                                                        foregroundColor:
                                                            Colors.black,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                28,
                                                              ),
                                                        ),
                                                        elevation: 0,
                                                      ),
                                                      onPressed: () async {
                                                        final navigator =
                                                            Navigator.of(
                                                              context,
                                                            );
                                                        final user =
                                                            FirebaseAuth
                                                                .instance
                                                                .currentUser;
                                                        if (user != null) {
                                                          try {
                                                            await provider.saveUserToFirestore(
                                                              userId: user.uid,
                                                              email: provider
                                                                  .email,
                                                              firstname:
                                                                  fulnamecontroler
                                                                      .text
                                                                      .split(
                                                                        ' ',
                                                                      )
                                                                      .first,
                                                              username:
                                                                  usernamecontroller
                                                                      .text,
                                                              lastname:
                                                                  fulnamecontroler
                                                                      .text
                                                                      .split(
                                                                        ' ',
                                                                      )
                                                                      .skip(1)
                                                                      .join(
                                                                        ' ',
                                                                      ),
                                                            );
                                                            navigator.pop();
                                                          } catch (e) {
                                                            ScaffoldMessenger.of(
                                                              context,
                                                            ).showSnackBar(
                                                              SnackBar(
                                                                content: Text(
                                                                  "Failed to save profile: $e",
                                                                ),
                                                              ),
                                                            );
                                                          }
                                                        }
                                                      },
                                                      child: Text(
                                                        'Save profile',
                                                        style: TextStyle(
                                                          color:
                                                              Theme.of(
                                                                    context,
                                                                  ).brightness ==
                                                                  Brightness
                                                                      .dark
                                                              ? const Color.fromARGB(
                                                                  255,
                                                                  0,
                                                                  0,
                                                                  0,
                                                                )
                                                              : const Color.fromARGB(
                                                                  255,
                                                                  255,
                                                                  255,
                                                                  255,
                                                                ),
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context),
                                                    child: const Text(
                                                      'Cancel',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
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
                                );
                                fulnamecontroler.text = fullName;
                                usernamecontroller.text = username;
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFF38383A),
                                ),
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 8,
                                ),
                                foregroundColor: Colors.white,
                              ),
                              child: Text(
                                "Edit profile",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 30),
                    _buildSectionHeader("Account"),
                    _buildGroup([
                      Consumer<Userprovider>(
                        builder: (c, p, _) {
                          final email = p.email.isNotEmpty
                              ? p.email
                              : "q2xcrnwnz6@privaterelay.appleid.com";
                          return _buildSettingsTile(
                            icon: Icons.email_outlined,
                            title: "Email",
                            subtitle: email,
                            showChevron: false,
                          );
                        },
                      ),
                      _buildSettingsTile(
                        icon: Icons.add_circle_outline,
                        title: "Subscription",
                        trailingText: "Free Plan",
                        showChevron: false,
                      ),
                      // 1. Change your implementation to this:
                      _buildSettingsTile(
                        icon: Icons.auto_awesome_outlined,
                        title: "Upgrade to EmergeX pro",
                        showChevron: false,
                        onTap: () {
                          showModalBottomSheet(
                            isScrollControlled: true,
                            barrierColor: Colors.black.withOpacity(0.3),
                            backgroundColor: Colors.transparent,
                            context: context,
                            builder: (context) {
                              return BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 10,
                                  sigmaY: 10,
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(19.0),
                                  child: Container(
                                    height: 730,
                                    width: MediaQuery.of(context).size.width,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.2),
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: Colors.white24,
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        const Text(
                                          'Upgrade to Pro',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        const Text(
                                          'Get unlimited AI file analysis and faster responses.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                        const SizedBox(height: 30),

                                        // The Pricing Card
                                        Container(
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.05,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color: Colors.blueAccent
                                                  .withOpacity(0.5),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                'Monthly Plan',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                ),
                                              ),
                                              Text(
                                                '\$9.99/mo',
                                                style: TextStyle(
                                                  color: Colors.blueAccent[100],
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        const SizedBox(height: 40),

                                        // The Buy Button
                                        SizedBox(
                                          width: double.infinity,
                                          height: 55,
                                          child: ElevatedButton(
                                            onPressed: () =>
                                                _makePayment(), // This calls your Stripe logic
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.blueAccent,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(15),
                                              ),
                                            ),
                                            child: const Text(
                                              'Subscribe Now',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                      _buildSettingsTile(
                        icon: Icons.refresh,
                        title: "Restore purchases",
                        showChevron: false,
                      ),
                      _buildSettingsTile(
                        icon: Icons.person_outline,
                        title: "Personalization",
                      ),
                      _buildSettingsTile(
                        icon: Icons.notifications_outlined,
                        title: "Notifications",
                      ),
                      _buildSettingsTile(icon: Icons.grid_view, title: "Apps"),

                      _buildSettingsTile(
                        icon: Icons.security,
                        title: "Security",
                      ),
                    ]),

                    const SizedBox(height: 24),
                    _buildSectionHeader("App"),
                    _buildGroup([
                      _buildSettingsTile(
                        icon: Icons.language,
                        title: "App language",
                        trailingText: "English",
                      ),
                      Consumer<Userprovider>(
                        builder: (context, userProvider, child) {
                          String appearance = "System";
                          if (userProvider.themeMode == ThemeMode.light)
                            appearance = "Light";
                          if (userProvider.themeMode == ThemeMode.dark)
                            appearance = "Dark";

                          return _buildSettingsTile(
                            icon: Icons.dark_mode_outlined,
                            title: "Appearance",
                            trailingText: appearance,
                            isDropdown: true,
                            showChevron: false,
                            onTap: () =>
                                _showAppearanceMenu(context, userProvider),
                          );
                        },
                      ),
                      Consumer<Userprovider>(
                        builder: (context, userProvider, child) {
                          return _buildSettingsTile(
                            icon: Icons.color_lens_outlined,
                            title: "Accent color",
                            trailingWidget: _buildColorCircle(
                              userProvider.accentColor,
                            ),
                            trailingText: "",
                            onTap: () =>
                                _showColorPicker(context, userProvider),
                          );
                        },
                      ),
                    ]),

                    const SizedBox(height: 24),
                    _buildSectionHeader("Speech"),
                    _buildGroup([
                      _buildSettingsTile(
                        icon: Icons.language,
                        title: "Main language",
                        isDropdown: true,
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 8),
                      child: Text(
                        "Voice mode",
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _buildGroup([
                      _buildSettingsTile(
                        icon: Icons.graphic_eq,
                        title: "Voice",
                        trailingText: "Spruce",
                      ),
                    ]),
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        "Background conversations keep the conversation going in other apps or while your screen is off.\nLearn more",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),

                    const SizedBox(height: 24),
                    _buildSectionHeader("About"),
                    _buildGroup([
                      _buildSettingsTile(
                        icon: Icons.bug_report_outlined,
                        title: "Report bug",
                        showChevron: false,
                      ),
                      _buildSettingsTile(
                        icon: Icons.help_outline,
                        title: "Help Center",
                        showChevron: false,
                      ),
                      _buildSettingsTile(
                        icon: Icons.description_outlined,
                        title: "Terms of Use",
                        showChevron: false,
                      ),
                      _buildSettingsTile(
                        icon: Icons.lock_outline,
                        title: "Privacy Policy",
                        showChevron: false,
                      ),
                    ]),

                    const SizedBox(height: 24),
                    InkWell(
                      onTap: () => logout(context),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF242426),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text(
                            "Log out",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAppearanceMenu(BuildContext context, Userprovider provider) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) {
        return Center(
          child: Material(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(20),
            elevation: 24,
            child: SizedBox(
              width: 250,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAppearanceOption("System", provider),
                  const Divider(height: 1, color: Colors.white12),
                  _buildAppearanceOption("Dark", provider),
                  const Divider(height: 1, color: Colors.white12),
                  _buildAppearanceOption("Light", provider),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppearanceOption(String label, Userprovider provider) {
    ThemeMode currentMode = provider.themeMode;
    bool isSelected = false;
    if (label == "System" && currentMode == ThemeMode.system) isSelected = true;
    if (label == "Dark" && currentMode == ThemeMode.dark) isSelected = true;
    if (label == "Light" && currentMode == ThemeMode.light) isSelected = true;

    return InkWell(
      onTap: () {
        ThemeMode newMode = ThemeMode.system;
        if (label == "Dark") newMode = ThemeMode.dark;
        if (label == "Light") newMode = ThemeMode.light;
        provider.updateThemeMode(newMode);
        Navigator.pop(context);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Row(
          children: [
            if (isSelected)
              const Icon(Icons.check, color: Colors.white, size: 20)
            else
              const SizedBox(width: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w400,
                decoration: TextDecoration.none,
                fontFamily: '.SF Pro Text',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey[400],
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF242426)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              const Divider(height: 1, color: Colors.white12, indent: 50),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    String? trailingText,
    bool showChevron = true,
    bool isDropdown = false,
    Widget? trailingWidget,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: ListTile(
        leading: Icon(
          icon,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black,
          size: 24,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black,
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailingText != null)
              Text(
                trailingText,
                style: const TextStyle(color: Colors.grey, fontSize: 15),
              ),
            if (trailingWidget != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: trailingWidget,
              ),
            if (isDropdown)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.unfold_more, color: Colors.grey, size: 20),
              ),
            if (showChevron && !isDropdown)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey,
                  size: 14,
                ),
              ),
          ],
        ),
        onTap: onTap ?? () {},
        minLeadingWidth: 20,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        dense: true,
        visualDensity: const VisualDensity(vertical: 0),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: ListTile(
        leading: Icon(icon, color: Colors.white, size: 24),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        trailing: Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.blueAccent,
          activeTrackColor: Colors.green,
        ),
        minLeadingWidth: 20,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        dense: true,
        visualDensity: const VisualDensity(vertical: 0),
      ),
    );
  }

  Widget _buildColorCircle(Color color) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey, width: 2),
      ),
    );
  }

  void _showColorPicker(BuildContext context, Userprovider provider) {
    final List<Color> colors = [
      Colors.transparent, // Represents Default / Glass
      Colors.blue,
      Colors.green,
      Colors.red,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) {
        return Center(
          child: Material(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(20),
            elevation: 24,
            child: Container(
              width: 300,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Choose Accent Color",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 15,
                    runSpacing: 15,
                    alignment: WrapAlignment.center,
                    children: colors.map((color) {
                      final isSelected =
                          provider.accentColor.value == color.value;
                      final isGlass = color == Colors.transparent;
                      return GestureDetector(
                        onTap: () {
                          provider.setAccentColor(color);
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                            color: isGlass
                                ? Colors.white.withOpacity(0.1)
                                : color,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 3)
                                : (isGlass
                                      ? Border.all(
                                          color: Colors.white30,
                                          width: 1,
                                        )
                                      : null),
                            boxShadow: [
                              if (!isGlass)
                                BoxShadow(
                                  color: color.withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                            ],
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white)
                              : (isGlass
                                    ? const Icon(
                                        Icons.blur_on,
                                        color: Colors.white70,
                                        size: 20,
                                      )
                                    : null),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey[600]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
