import 'package:flutter/material.dart';

import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'screens/login_page.dart';
import 'screens/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final apiClient = ApiClient();
  final authService = AuthService(apiClient: apiClient);

  runApp(MyApp(apiClient: apiClient, authService: authService));
}

class MyApp extends StatefulWidget {
  final ApiClient apiClient;
  final AuthService authService;

  const MyApp({super.key, required this.apiClient, required this.authService});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    // 🔐 Try to restore saved token + user from SharedPreferences
    _initFuture = widget.authService.restoreSession();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Homemade Food Marketplace',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green),
      home: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          // Still loading saved session → show simple splash
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashPage();
          }

          // Done loading: decide start page based on auth state
          if (widget.authService.isLoggedIn) {
            return AppShell(
              apiClient: widget.apiClient,
              authService: widget.authService,
              initialIndex: 0,
            );
          } else {
            return LoginPage(
              apiClient: widget.apiClient,
              authService: widget.authService,
            );
          }
        },
      ),
    );
  }
}

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
