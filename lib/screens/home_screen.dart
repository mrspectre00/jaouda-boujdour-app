import 'package:flutter/material.dart';
import '../services/supabase_client.dart';
import 'login_screen.dart';
import 'markets_screen.dart';
import 'inventory_screen.dart';
import 'profile_screen.dart';
import 'end_day_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String _userName = 'Loading...';
  bool _isManagement = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final response =
          await supabase
              .from('users')
              .select('full_name, role')
              .eq('id', userId)
              .single();

      if (mounted) {
        setState(() {
          _userName = response['full_name'] as String;
          _isManagement = response['role'] == 'management';
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> managementOptions = <Widget>[
      const MarketsScreen(), // Shows all markets
      const InventoryScreen(), // Shows all inventory
      const ProfileScreen(),
    ];

    final List<Widget> vendorOptions = <Widget>[
      const MarketsScreen(), // Shows only assigned markets
      const InventoryScreen(), // Shows only assigned inventory
      const ProfileScreen(),
    ];

    final List<BottomNavigationBarItem> managementNavItems = [
      const BottomNavigationBarItem(icon: Icon(Icons.store), label: 'Markets'),
      const BottomNavigationBarItem(
        icon: Icon(Icons.inventory),
        label: 'Inventory',
      ),
      const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
    ];

    final List<BottomNavigationBarItem> vendorNavItems = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.store),
        label: 'My Markets',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.inventory),
        label: 'My Inventory',
      ),
      const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isManagement ? 'Management Dashboard' : 'Vendor Dashboard',
        ),
        actions: [
          if (!_isManagement) // Only show end day for vendors
            IconButton(
              icon: const Icon(Icons.nightlight_round),
              tooltip: 'End Day',
              onPressed: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const EndDayScreen()));
              },
            ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _signOut),
        ],
      ),
      body:
          _isManagement
              ? managementOptions.elementAt(_selectedIndex)
              : vendorOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: _isManagement ? managementNavItems : vendorNavItems,
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }
}
