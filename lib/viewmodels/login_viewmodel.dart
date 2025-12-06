import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isDisposed = false; // <-- protección

  void _setLoading(bool v) {
    if (_isDisposed) return; // <-- evita notify después del dispose
    _isLoading = v;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  /// Login con email/password.
  Future<String?> loginWithEmail(String email, String password) async {
    _setLoading(true);
    bool retried = false;

    Future<UserCredential> attemptSignIn() {
      return _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    }

    try {
      await attemptSignIn();
      if (_isDisposed) return 'cancelled';
      return null;
    } on TypeError catch (e) {
      debugPrint('TypeError durante login con correo: $e');
      if (!retried) {
        retried = true;
        await Future.delayed(const Duration(seconds: 1));
        if (_isDisposed) return 'cancelled';
        try {
          await attemptSignIn();
          if (_isDisposed) return 'cancelled';
          return null;
        } catch (e2) {
          debugPrint('Retry después de TypeError falló: $e2');
          return 'No fue posible iniciar sesión. Intenta de nuevo más tarde.';
        }
      } else {
        return 'Error inesperado en el flujo de autenticación.';
      }
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Error de autenticación';
    } catch (e) {
      debugPrint('Error inesperado durante login: $e');
      return 'Error inesperado: $e';
    } finally {
      _setLoading(false);
    }
  }

  /// Login con Google
  Future<String?> signInWithGoogle() async {
    _setLoading(true);
    bool retried = false;

    Future<void> doSignIn() async {
      try {
        await _googleSignIn.disconnect();
      } catch (_) {}
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw 'cancelled';

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
    }

    try {
      await doSignIn();
      if (_isDisposed) return 'cancelled';
      return null;
    } on String catch (s) {
      if (s == 'cancelled') return 'cancelled';
      return 'Error en Google Sign-In: $s';
    } on TypeError catch (e) {
      debugPrint('TypeError GoogleSignIn (capturado): $e');
      if (!retried) {
        retried = true;
        await Future.delayed(const Duration(seconds: 1));
        if (_isDisposed) return 'cancelled';
        try {
          await doSignIn();
          if (_isDisposed) return 'cancelled';
          return null;
        } catch (e2) {
          debugPrint('Retry after TypeError falló: $e2');
          return 'Error en Google Sign-In (intento fallido).';
        }
      }
      return 'Error transitorio en Google Sign-In.';
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Error en autenticación con Google';
    } catch (e) {
      debugPrint('Error general en GoogleSignIn: $e');
      return 'Error con Google: $e';
    } finally {
      _setLoading(false);
    }
  }

  /// Reset password
  Future<String?> sendPasswordReset(String email) async {
    if (email.isEmpty || !email.contains('@')) {
      return 'Ingresa un correo válido';
    }
    _setLoading(true);
    try {
      await _auth.sendPasswordResetEmail(email: email);
      if (_isDisposed) return 'cancelled';
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Error al enviar correo de recuperación';
    } catch (e) {
      debugPrint('Error en sendPasswordReset: $e');
      return 'Error inesperado: $e';
    } finally {
      _setLoading(false);
    }
  }
}
