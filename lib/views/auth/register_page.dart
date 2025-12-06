import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/register_viewmodel.dart';
import 'package:app_iot_db/theme/app_colors.dart';

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

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _onRegisterPressed(RegisterViewModel vm) async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;

    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    final res = await vm.register(name: name, email: email, password: password);
    if (res == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '✅ Cuenta creada. Revisa tu correo para verificar tu dirección.',
          ),
        ),
      );
      Navigator.of(context).pop(); // volver al login
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('⚠️ $res')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<RegisterViewModel>(
      create: (_) => RegisterViewModel(),
      child: Consumer<RegisterViewModel>(
        builder: (context, vm, child) {
          return Scaffold(
            backgroundColor: AppColors.beigeCalido,
            body: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.azulProfundo, AppColors.azulNoche],
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
                                color: AppColors.azulProfundo,
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Nombre
                            TextFormField(
                              controller: _nameCtrl,
                              decoration: InputDecoration(
                                prefixIcon: Icon(Icons.person, color: AppColors.azulProfundo),
                                labelText: 'Nombre completo',
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: AppColors.naranjaAndino),
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
                                prefixIcon: Icon(Icons.email, color: AppColors.azulProfundo),
                                labelText: 'Correo electrónico',
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: AppColors.naranjaAndino),
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
                                prefixIcon: Icon(Icons.lock, color: AppColors.azulProfundo),
                                labelText: 'Contraseña',
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: AppColors.naranjaAndino),
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
                            vm.isLoading
                                ? const CircularProgressIndicator()
                                : SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton(
                                      onPressed: () => _onRegisterPressed(vm),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.naranjaAndino,
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
                              icon: Icon(Icons.arrow_back, color: AppColors.azulProfundo),
                              label: Text(
                                'Volver al login',
                                style: TextStyle(color: AppColors.azulProfundo),
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
        },
      ),
    );
  }
}
