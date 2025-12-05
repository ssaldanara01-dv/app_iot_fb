import 'package:app_iot_db/views/pairing/pairing_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'viewmodels/auth_viewmodel.dart';
import 'views/auth/login_page.dart';
import 'views/dashboard/dashboard_page.dart';
import 'services/device/pairing_service.dart';
import 'views/main_menu/main_menu_page.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthViewModel>(
          create: (_) => AuthViewModel()..initializeAuth(),
        ),
        StreamProvider<User?>.value(
          value: FirebaseAuth.instance.authStateChanges(),
          initialData: FirebaseAuth.instance.currentUser,
        ),
      ],
      child: MaterialApp(
        title: 'Security IoT',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.teal,
        ),
        initialRoute: '/',
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
