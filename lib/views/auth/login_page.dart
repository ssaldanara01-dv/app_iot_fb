import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/login_viewmodel.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  // 🎨 Paleta YanaGuard (se mantiene para la UI)
  final Color azulProfundo = const Color(0xFF1E3A8A);
  final Color naranjaAndino = const Color(0xFFF59E0B);
  final Color verdeQuillu = const Color(0xFF4CAF50);
  final Color beigeCalido = const Color(0xFFF4EBD0);
  final Color azulNoche = const Color(0xFF0F172A);

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _onLoginPressed(LoginViewModel vm) async {
    final email = _emailCtrl.text;
    final pass = _passCtrl.text;

    final error = await vm.loginWithEmail(email, pass);
    if (error == null) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/main');
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error == 'cancelled' ? 'Acción cancelada' : error),
        ),
      );
    }
  }

  Future<void> _onGooglePressed(LoginViewModel vm) async {
    final error = await vm.signInWithGoogle();
    if (error == null) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/main');
    } else if (error != 'cancelled') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
    // si fue 'cancelled' el usuario canceló, no mostramos snackbar
  }

  Future<void> _showResetPasswordDialog(LoginViewModel vm) async {
    final TextEditingController emailCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: beigeCalido,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              onPressed: () {
                emailCtrl.dispose();
                Navigator.pop(context);
              },
              child: Text("Cancelar", style: TextStyle(color: azulProfundo)),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = emailCtrl.text.trim();
                final res = await vm.sendPasswordReset(email);
                if (res == null) {
                  Navigator.pop(context);
                  if (!mounted) return;
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
                          "Hemos enviado un enlace a:\n\n$email\n\n📩 Si no lo ves, revisa también la carpeta de SPAM.",
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
                } else {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(res)),
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
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LoginViewModel>(
      create: (_) => LoginViewModel(),
      child: Consumer<LoginViewModel>(
        builder: (context, vm, child) {
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
                            backgroundImage:
                                const AssetImage('assets/icons/yanaguard_icon_login.png'),
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
                              onPressed: () => _showResetPasswordDialog(vm),
                              child: Text(
                                "¿Olvidaste tu contraseña?",
                                style: TextStyle(color: naranjaAndino),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          vm.isLoading
                              ? const CircularProgressIndicator()
                              : Column(
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: ElevatedButton(
                                        onPressed: () => _onLoginPressed(vm),
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
                                          'assets/images/google_logo.jpg',
                                          height: 24,
                                        ),
                                        label: Text(
                                          'Iniciar con Google',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: azulProfundo,
                                          ),
                                        ),
                                        onPressed: () => _onGooglePressed(vm),
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
        },
      ),
    );
  }
}
