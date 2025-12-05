import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterViewModel extends ChangeNotifier {
  final FirebaseAuth _auth;
  final FirebaseFirestore _fs;

  RegisterViewModel({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _fs = firestore ?? FirebaseFirestore.instance;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  /// Registra un usuario y crea su documento en Firestore.
  /// Retorna `null` si todo OK, o un mensaje de error.
  Future<String?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _setLoading(true);

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        return 'No se pudo crear el usuario.';
      }

      // Actualizar displayName y enviar verificación
      await user.updateDisplayName(name);
      await user.sendEmailVerification();

      // Crear documento en Firestore
      await _fs.collection('users').doc(user.uid).set({
        'name': name,
        'email': email.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'verified': false,
      });

      return null;
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'email-already-in-use':
          msg = 'Este correo ya está registrado.';
          break;
        case 'invalid-email':
          msg = 'El correo ingresado no es válido.';
          break;
        case 'weak-password':
          msg = 'La contraseña es demasiado débil (mínimo 6 caracteres).';
          break;
        case 'operation-not-allowed':
          msg = 'El registro con email está deshabilitado en el servidor.';
          break;
        default:
          msg = e.message ?? 'Error desconocido al registrar.';
      }
      return msg;
    } catch (e) {
      debugPrint('register error: $e');
      return 'Error inesperado: $e';
    } finally {
      _setLoading(false);
    }
  }
}
