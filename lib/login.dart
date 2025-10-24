import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'register.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  final _auth = FirebaseAuth.instance;

  // 🎨 Paleta de colores YanaGuard
  final Color azulProfundo = const Color(0xFF1E3A8A);
  final Color naranjaAndino = const Color(0xFFF59E0B);
  final Color verdeQuillu = const Color(0xFF4CAF50);
  final Color beigeCalido = const Color(0xFFF4EBD0);
  final Color azulNoche = const Color(0xFF0F172A);

  // 🔹 LOGIN NORMAL CON CORREO Y CONTRASEÑA
  Future<void> _login() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    Future<UserCredential> attemptSignIn() {
      return _auth.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
    }

    bool retried = false;

    try {
      await attemptSignIn();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/menu');
    } on TypeError catch (e) {
      debugPrint('TypeError durante login con correo: $e');

      if (!retried) {
        retried = true;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Error transitorio de autenticación. Reintentando automáticamente...'),
              duration: Duration(seconds: 3),
            ),
          );
        }

        await Future.delayed(const Duration(seconds: 1));

        try {
          await attemptSignIn();
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/menu');
          return;
        } catch (e2) {
          debugPrint('Retry después de TypeError falló: $e2');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'No fue posible iniciar sesión. Intenta cerrar la app y abrirla de nuevo.\nDetalle: $e2'),
              ),
            );
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Error de autenticación')),
      );
    } catch (e) {
      debugPrint('Error inesperado durante login: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error inesperado: $e')),
        );
      }
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // 🔹 LOGIN CON GOOGLE (reparado)
  Future<void> _signInWithGoogle() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final googleSignIn = GoogleSignIn();
    bool retried = false;

    Future<void> doSignIn() async {
      try {
        await googleSignIn.disconnect();
      } catch (_) {}
      try {
        await googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/menu');
    }

    try {
      await doSignIn();
    } on TypeError catch (e) {
      debugPrint('TypeError GoogleSignIn (capturado): $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Error transitorio en Google Sign-In. Reintentando...'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      if (!retried) {
        retried = true;
        await Future.delayed(const Duration(seconds: 1));
        try {
          await doSignIn();
        } catch (e2) {
          debugPrint('Retry after TypeError falló: $e2');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error con Google (intento fallido): $e2'),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error general en GoogleSignIn: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error con Google: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🔹 RESTABLECER CONTRASEÑA
  Future<void> _showResetPasswordDialog(BuildContext context) async {
    final TextEditingController emailCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: beigeCalido,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            "Restablecer contraseña",
            style: TextStyle(color: azulProfundo, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: emailCtrl,
            decoration: InputDecoration(
              labelText: "Ingresa tu correo",
              prefixIcon: Icon(Icons.email, color: naranjaAndino),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: naranjaAndino),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancelar", style: TextStyle(color: azulProfundo)),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = emailCtrl.text.trim();
                if (email.isEmpty || !email.contains('@')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ingresa un correo válido')),
                  );
                  return;
                }

                try {
                  await FirebaseAuth.instance.sendPasswordResetEmail(
                    email: email,
                  );
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        backgroundColor: beigeCalido,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        title: Text(
                          "Correo enviado",
                          style: TextStyle(color: naranjaAndino),
                        ),
                        content: Text(
                          "Hemos enviado un enlace a:\n\n"
                          "$email\n\n📩 Si no lo ves, revisa también la carpeta de SPAM.",
                          style: const TextStyle(fontSize: 16),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              "Entendido",
                              style: TextStyle(color: azulProfundo),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                } on FirebaseAuthException catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.message}')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: naranjaAndino),
              child: const Text("Enviar"),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // 🔹 UI DEL LOGIN
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.transparent,
                      backgroundImage: const AssetImage(
                        'assets/yanaguard_icon_login.png',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'YanaGuard',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: azulProfundo,
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _emailCtrl,
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
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    TextField(
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
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _showResetPasswordDialog(context),
                        child: Text(
                          "¿Olvidaste tu contraseña?",
                          style: TextStyle(color: naranjaAndino),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: naranjaAndino,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Iniciar Sesión',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: OutlinedButton.icon(
                                  icon: Image.asset(
                                    'assets/google_logo.jpg',
                                    height: 24,
                                  ),
                                  label: Text(
                                    'Iniciar con Google',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: azulProfundo,
                                    ),
                                  ),
                                  onPressed: _signInWithGoogle,
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: azulProfundo),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterPage(),
                          ),
                        );
                      },
                      child: Text(
                        '¿No tienes cuenta? Regístrate aquí',
                        style: TextStyle(color: verdeQuillu),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
