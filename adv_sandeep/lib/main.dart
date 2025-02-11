import 'package:adv_sandeep/data_list_screen.dart';
import 'package:adv_sandeep/upload_page.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Admin Panel',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: const AdminPanel(),
    );
  }
}

class AdminPanel extends StatefulWidget {
  const AdminPanel({Key? key}) : super(key: key);

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const UploadPage(),
    const DataListScreen(),
    const AboutPage(),
  ];

  // Define custom colors
  final Color sidebarColor =
      const Color(0xFFFF5722); // SmartTime Orange/Tiger color
  final Color selectedItemColor = Colors.white;
  final Color unselectedItemColor = Colors.white70;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Enhanced Sidebar
          Container(
            width: 250,
            color: sidebarColor,
            child: Column(
              children: [
                // Admin Panel Header
                Container(
                  padding: const EdgeInsets.all(20),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.admin_panel_settings,
                        color: Colors.white,
                        size: 32,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Admin Panel',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24, height: 1),
                // Navigation Items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _buildNavItem(
                        icon: Icons.upload_file,
                        label: 'Upload File',
                        index: 0,
                      ),
                      _buildNavItem(
                        icon: Icons.list_alt,
                        label: 'View Data List',
                        index: 1,
                      ),
                      _buildNavItem(
                        icon: Icons.info_outline,
                        label: 'About Us',
                        index: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Main content area
          Expanded(
            child: Column(
              children: [
                // Page Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 3,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(
                        _getPageTitle(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // Page Content
                Expanded(
                  child: Container(
                    color: Colors.grey[50],
                    child: _pages[_selectedIndex],
                  ),
                ),
                // Enhanced Footer
                Container(
                  width: double.infinity,
                  color: const Color.fromARGB(255, 44, 43, 43),
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 16,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.copyright,
                        size: 16,
                        color: Colors.white,
                      ),
                      SizedBox(width: 8),
                      Text(
                        '2024 All rights reserved - ADV. Sandeep Waghmare',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color:
                isSelected ? Colors.white.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          margin: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? selectedItemColor : unselectedItemColor,
                size: 24,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? selectedItemColor : unselectedItemColor,
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getPageTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Upload File';
      case 1:
        return 'View Data List';
      case 2:
        return 'About Us';
      default:
        return 'Admin Panel';
    }
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'About Us',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Welcome to our admin panel. This platform is designed to help you manage and analyze your data efficiently. Our team is dedicated to providing you with the best tools and experience possible.',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
