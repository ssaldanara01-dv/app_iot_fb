import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> initializeAuth() async {
    try {
      _setLoading(true);

      if (_auth.currentUser == null) {
        final cred = await _auth.signInAnonymously();
        debugPrint('Anon UID=${cred.user?.uid}');
      } else {
        debugPrint('Usuario actual=${_auth.currentUser!.uid}');
      }

      await Future.delayed(const Duration(milliseconds: 250));
    } catch (e) {
      debugPrint('Error en anonymous login: $e');
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
