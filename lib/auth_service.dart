import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign up with email and password
  Future<User?> signUp(String email, String password, String name) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = userCredential.user;

      // Add user to Firestore collection with the name
      if (user != null) {
        await _firestore.collection('PoliceUsers').doc(user.uid).set({
          'name': name, // Store name
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
          'role': 'police', // Add role or other default fields if needed
        });
      }
      return user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        if (kDebugMode) {
          print('Email is already in use.');
        }
      } else if (e.code == 'weak-password') {
        print('The password provided is too weak.');
      }
      return null;
    } catch (e) {
      print('Error signing up: $e');
      return null;
    }
  }
  // Sign in with email and password
Future<User?> signIn(String email, String password) async {
  try {
    UserCredential userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return userCredential.user;
  } on FirebaseAuthException catch (e) {
    if (e.code == 'user-not-found') {
      print('No user found for that email.');
    } else if (e.code == 'wrong-password') {
      print('Wrong password provided.');
    }
    return null;
  } catch (e) {
    print('Error signing in: $e');
    return null;
  }
}
}

