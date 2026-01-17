import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';

// ✅ change these imports if your files are in different folders
import 'home_page.dart';
import 'search_page.dart';
import 'public_product_list_page.dart';
import 'profile_page.dart';

class AppShell extends StatefulWidget {
  final ApiClient apiClient;
  final AuthService authService;
  final int initialIndex;

  const AppShell({
    super.key,
    required this.apiClient,
    required this.authService,
    this.initialIndex = 0,
  });

  static _AppShellState? of(BuildContext context) {
    return context.findAncestorStateOfType<_AppShellState>();
  }

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  void setTab(int index) {
    if (!mounted) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      // If your HomePage constructor is different, change this line only.
      HomePage(apiClient: widget.apiClient, authService: widget.authService),

      SearchPage(apiClient: widget.apiClient, authService: widget.authService),

      PublicProductListPage(
        apiClient: widget.apiClient,
        authService: widget.authService,
      ),

      ProfilePage(apiClient: widget.apiClient, authService: widget.authService),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setTab(i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(
            icon: Icon(Icons.fastfood_outlined),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
