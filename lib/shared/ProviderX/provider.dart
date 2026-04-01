import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Userprovider extends ChangeNotifier {
  String username;
  String email;
  String firstname;
  String lastname;
  ThemeMode _themeMode = ThemeMode.system;
  Color _accentColor = Colors.transparent; // Default to glass/transparent

  Userprovider({
    this.username = "",
    this.email = "",
    this.firstname = "",
    this.lastname = "",
  }) {
    _loadThemeFromPrefs();
    _loadAccentColor();
  }

  Color get accentColor => _accentColor;

  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    notifyListeners();
    final preds = await SharedPreferences.getInstance();
    await preds.setString('accent_color', color.value.toRadixString(16));
  }

  Future<void> _loadAccentColor() async {
    final prefs = await SharedPreferences.getInstance();
    String? colorHex = prefs.getString('accent_color');
    if (colorHex != null) {
      _accentColor = Color(int.parse(colorHex, radix: 16));
      notifyListeners();
    }
  }


  ThemeMode get themeMode => _themeMode;

  Future<void> updateThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
  }

  Future<void> _loadThemeFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString('theme_mode');
    if (themeName != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (m) => m.name == themeName,
        orElse: () => ThemeMode.system,
      );
      notifyListeners();
    }
  }

  void changeUserName({required String newUser}) {
    username = newUser;
    notifyListeners();
  }

  void changeEmail({required String newEmail}) {
    email = newEmail;
    notifyListeners();
  }

  void changefirstName({required String newName}) {
    firstname = newName;
    notifyListeners();
  }

  void changeLastName({required String newLast}) {
    lastname = newLast;
    notifyListeners();
  }

  Future<void> saveUserToFirestore({
    required String userId,
    required String email,
    required String firstname,
    required String username,
    required String lastname,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'email': email,
        'first name': firstname,
        'username': username,
        'lastname': lastname,
      });
      this.username = username;
      this.firstname = firstname;
      this.email = email;
      this.lastname = lastname;
      notifyListeners();
    } catch (e) {
      print('Error saving user to Firestore: $e');
      rethrow;
    }
  }

  Future<void> loadUserData({required String userId}) async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        username = data['username'] ?? '';
        firstname = data['first name'] ?? '';
        email = data['email'] ?? '';
        lastname = data['lastname'] ?? '';
      }
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      notifyListeners();
    }
  }

  void clearUserData() {
    username = "";
    email = "";
    firstname = "";
    lastname = "";
    notifyListeners();
  }
}
