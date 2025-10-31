import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;

  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  // 🎨 Paleta de colores YanaGuard
  final Color azulProfundo = const Color(0xFF1E3A8A);
  final Color naranjaAndino = const Color(0xFFF59E0B);
  final Color verdeQuillu = const Color(0xFF4CAF50);
  final Color beigeCalido = const Color(0xFFF4EBD0);
  final Color azulNoche = const Color(0xFF0F172A);

  // 🔹 REGISTRO DE USUARIO
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final email = _emailCtrl.text.trim();
      final password = _passCtrl.text;
      final name = _nameCtrl.text.trim();

      // Crear usuario
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = cred.user;
      if (user != null) {
        await user.updateDisplayName(name);
        await user.sendEmailVerification();

        // Crear documento en Firestore
        await _fs.collection('users').doc(user.uid).set({
          'name': name,
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
          'verified': false,
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✅ Cuenta creada. Revisa tu correo para verificar tu dirección.',
            ),
          ),
        );

        Navigator.of(context).pop(); // volver al login
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ $msg')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error inesperado: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // 🔹 UI REGISTRO
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: beigeCalido,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [azulProfundo, azulNoche],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              color: Colors.white,
              elevation: 10,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_add_alt_1,
                          size: 80, color: Colors.blueAccent),
                      const SizedBox(height: 16),
                      Text(
                        'Crear cuenta',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: azulProfundo,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Nombre
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.person, color: azulProfundo),
                          labelText: 'Nombre completo',
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: naranjaAndino),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().length < 2)
                            ? 'Ingresa un nombre válido'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // Correo
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.email, color: azulProfundo),
                          labelText: 'Correo electrónico',
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: naranjaAndino),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (v) =>
                            (v == null || !v.contains('@') || !v.contains('.'))
                                ? 'Correo inválido'
                                : null,
                      ),
                      const SizedBox(height: 16),

                      // Contraseña
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: true,
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.lock, color: azulProfundo),
                          labelText: 'Contraseña',
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: naranjaAndino),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 6)
                            ? 'Debe tener al menos 6 caracteres'
                            : null,
                      ),
                      const SizedBox(height: 24),

                      // Botón principal
                      _isLoading
                          ? const CircularProgressIndicator()
                          : SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _register,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: naranjaAndino,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Registrar cuenta',
                                  style: TextStyle(
                                      fontSize: 18, color: Colors.white),
                                ),
                              ),
                            ),

                      const SizedBox(height: 20),

                      // Volver al login
                      TextButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.arrow_back, color: azulProfundo),
                        label: Text(
                          'Volver al login',
                          style: TextStyle(color: azulProfundo),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
