import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_service.dart';

import 'tabs/history_tab.dart';
import 'tabs/home_tab.dart';
import 'tabs/profile_tab.dart';
import 'tabs/schedule_tab.dart';
import 'tabs/settings_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0; // Start with home tab selected (index 1)
  String? _role;
  bool? _firstUser;
  bool _loading = true;

  List<Widget> get _adminPages => [
    HomePage(),
    const ProfilePage(),
    const HistoryPage(),
    SettingsPage(),
  ];

  List<Widget> get _userPages => [
    HomePage(),
    const ProfilePage(),
    SettingsPage(),
  ];

  List<BottomNavigationBarItem> get _adminNavItems => const [
    BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
    BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
    BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
    BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
  ];

  List<BottomNavigationBarItem> get _userNavItems => const [
    BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
    BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
    BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
  ];

  @override
  void initState() {
    super.initState();
    _fetchRole();
  }

  void _showAdminWelcome() {
    if (_role == 'admin' || _firstUser == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Welcome back, Admin! You have full access to all features.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      });
    }
  }

  Future<void> _fetchRole() async {
    try {
      final isAdmin = await UserService.isAdmin();
      final userData = await UserService.getUserData();
      
      setState(() {
        _role = userData?['role'] ?? 'user';
        _firstUser = userData?['firstUser'] ?? false;
        _loading = false;
      });
      
      // Show admin welcome message
      _showAdminWelcome();
    } catch (e) {
      print('Error fetching role: $e');
      setState(() {
        _role = 'user';
        _firstUser = false;
        _loading = false;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    final isAdmin = (_role == 'admin' || _firstUser == true);
    final pages = isAdmin ? _adminPages : _userPages;
    final navItems = isAdmin ? _adminNavItems : _userNavItems;
    
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Text(isAdmin ? 'Admin Dashboard' : 'User Dashboard'),
            if (isAdmin) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'ADMIN',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                await UserService.logoutUser();
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (route) => false,
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Logout error: $e')),
                );
              }
            },
          ),
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: navItems,
      ),
    );
  }
}
