import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class UserController extends GetxController {
  static const _deviceUserCodePref = 'device_user_code';
  static const _fallbackNamePref = 'fallback_name';

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _facebookAuth = FacebookAuth.instance;

  final currentUser = Rx<UserModel?>(null);
  final pendingCode = ''.obs;
  final pendingName = ''.obs;
  final isFallbackRequestPending = false.obs;
  final isLoading = false.obs;
  final errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    checkCurrentUser();
  }

  Future<void> checkCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        final doc = await _firestore
            .collection('users')
            .doc(firebaseUser.uid)
            .get();
        if (doc.exists) {
          currentUser.value = UserModel.fromMap(
            doc.data() as Map<String, dynamic>,
          );
          await prefs.setString(_deviceUserCodePref, firebaseUser.uid);
        }
        return;
      }

      final storedCode = prefs.getString(_deviceUserCodePref);
      if (storedCode != null) {
        final userDoc = await _firestore
            .collection('users')
            .doc(storedCode)
            .get();
        if (userDoc.exists) {
          currentUser.value = UserModel.fromMap(
            userDoc.data() as Map<String, dynamic>,
          );
          return;
        }

        final pendingDoc = await _firestore
            .collection('pending_users')
            .doc(storedCode)
            .get();
        if (pendingDoc.exists) {
          pendingCode.value = storedCode;
          pendingName.value = pendingDoc['name'] ?? '';
          isFallbackRequestPending.value = true;
        }
      }
    } catch (e) {
      errorMessage.value = e.toString();
    }
  }

  Future<bool> loginWithFacebook() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final result = await _facebookAuth.login();

      if (result.status == LoginStatus.success) {
        final credential = FacebookAuthProvider.credential(
          result.accessToken!.tokenString,
        );
        final userCredential = await _auth.signInWithCredential(credential);

        final userData = await _facebookAuth.getUserData(
          fields: 'name,email,picture',
        );

        final user = UserModel(
          uid: userCredential.user!.uid,
          name: userData['name'] ?? userCredential.user!.displayName ?? 'User',
          email: userData['email'] ?? userCredential.user!.email ?? '',
          profilePictureUrl: userData['picture']?['data']?['url'] ?? '',
          expectations: [],
          createdAt: DateTime.now(),
        );

        await _firestore.collection('users').doc(user.uid).set(user.toMap());
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_deviceUserCodePref, user.uid);
        currentUser.value = user;
        isLoading.value = false;
        return true;
      } else if (result.status == LoginStatus.cancelled) {
        errorMessage.value = 'Login cancelled';
      } else {
        errorMessage.value = result.message ?? 'Login failed';
      }
      isLoading.value = false;
      return false;
    } catch (e) {
      errorMessage.value = e.toString();
      isLoading.value = false;
      return false;
    }
  }

  Future<String?> createFallbackRequest(String name) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final code = _generateFallbackCode();
      final prefs = await SharedPreferences.getInstance();

      await _firestore.collection('pending_users').doc(code).set({
        'name': name,
        'code': code,
        'requestedAt': DateTime.now(),
      });

      await prefs.setString(_deviceUserCodePref, code);
      await prefs.setString(_fallbackNamePref, name);

      pendingCode.value = code;
      pendingName.value = name;
      isFallbackRequestPending.value = true;
      isLoading.value = false;
      return code;
    } catch (e) {
      errorMessage.value = e.toString();
      isLoading.value = false;
      return null;
    }
  }

  /// Create a new user with a generated code and save directly to `users` collection.
  /// Returns the generated code on success, or null on failure.
  Future<String?> createUser(String name) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final code = _generateFallbackCode();

      final user = UserModel(
        uid: code,
        name: name,
        email: '',
        profilePictureUrl: '',
        expectations: [],
        createdAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(code).set(user.toMap());

      isLoading.value = false;
      return code;
    } catch (e) {
      errorMessage.value = e.toString();
      isLoading.value = false;
      return null;
    }
  }

  String _generateFallbackCode() {
    final random = Random.secure();
    final digits = random.nextInt(900000) + 100000;
    return 'WC$digits';
  }

  Future<void> addExpectation(String expectation) async {
    try {
      if (currentUser.value != null) {
        final updatedExpectations = [
          ...currentUser.value!.expectations,
          expectation,
        ];
        await _firestore.collection('users').doc(currentUser.value!.uid).update(
          {'expectations': updatedExpectations},
        );

        currentUser.value = currentUser.value!.copyWith(
          expectations: updatedExpectations,
        );
      }
    } catch (e) {
      errorMessage.value = e.toString();
    }
  }

  Future<void> removeExpectation(String expectation) async {
    try {
      if (currentUser.value != null) {
        final updatedExpectations = [...currentUser.value!.expectations];
        updatedExpectations.remove(expectation);
        await _firestore.collection('users').doc(currentUser.value!.uid).update(
          {'expectations': updatedExpectations},
        );

        currentUser.value = currentUser.value!.copyWith(
          expectations: updatedExpectations,
        );
      }
    } catch (e) {
      errorMessage.value = e.toString();
    }
  }

  Future<void> logout() async {
    try {
      isLoading.value = true;
      if (_auth.currentUser != null) {
        await _auth.signOut();
        await _facebookAuth.logOut();
      }
      currentUser.value = null;
      isFallbackRequestPending.value = false;
      pendingCode.value = '';
      pendingName.value = '';
      isLoading.value = false;
    } catch (e) {
      errorMessage.value = e.toString();
      isLoading.value = false;
    }
  }
}
