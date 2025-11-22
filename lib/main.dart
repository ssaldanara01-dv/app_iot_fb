import 'package:app_iot_db/pairing_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'login.dart';
import 'main_menu.dart';
import 'dashboard.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa Firebase con las opciones generadas (firebase_options.dart)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Imprimir lista de apps y databaseURL para verificar que apuntas al proyecto correcto
  print('Firebase apps: ${Firebase.apps}');
  try {
    print('databaseURL: ${Firebase.app().options.databaseURL}');
  } catch (e) {
    print('No se pudo obtener databaseURL: $e');
  }

  final auth = FirebaseAuth.instance;
  try {
    if (auth.currentUser == null) {
      final cred = await auth.signInAnonymously();
      print('Auth anónimo realizado uid=${cred.user?.uid}');
    } else {
      print('Usuario ya autenticado uid=${auth.currentUser!.uid}');
    }
    // pequeño margen para que la sesión se estabilice en el SDK
    await Future.delayed(const Duration(milliseconds: 250));
  } catch (e) {
    // No bloqueamos el arranque si falla (la app seguirá, pero las lecturas RTDB con reglas que requieren auth fallarán).
    print('Aviso: signInAnonymously falló o fue cancelado: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamProvider<User?>.value(
      value: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      child: MaterialApp(
        title: 'Security IoT',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(primarySwatch: Colors.teal),
        routes: {
          '/': (context) {
            final user = Provider.of<User?>(context);
            return user == null ? const LoginPage() : const MainMenuPage();
          },
          '/login': (context) => const LoginPage(),
          '/main': (context) => const MainMenuPage(),
          '/dashboard': (context) => const DashboardPage(),
          '/pairing': (context) => const PairingPage(),
        },
      ),
    );
  }
}
