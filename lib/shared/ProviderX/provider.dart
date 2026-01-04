import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Userprovider extends ChangeNotifier {
  String username;
  String email;
  String firstname;
  String lastname;

  Userprovider({
    this.username = "",
    this.email = "",
    this.firstname = "",
    this.lastname = "",
  });

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
