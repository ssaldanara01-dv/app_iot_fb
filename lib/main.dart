import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'login.dart';
import 'main_menu.dart';
import 'dashboard.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Si usas flutterfire CLI, importa el archivo generated (opcional).
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions
        .currentPlatform, // si generaste firebase_options.dart
  );
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
        },
      ),
    );
  }
}
