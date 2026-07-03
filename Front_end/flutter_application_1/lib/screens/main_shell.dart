import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav_bar.dart';
import 'categories_screen.dart';
import 'deals_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.vendeurId,
    required this.numTelephone,
  });

  final String vendeurId;
  final String numTelephone;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(
        vendeurId: widget.vendeurId,
        numTelephone: widget.numTelephone,
        onNavigateToCategories: () => setState(() => _selectedIndex = 3),
        onNavigateToSearch: () => setState(() => _selectedIndex = 1),
      ),
      const SearchScreen(),
      const DealsScreen(),
      const CategoriesScreen(),
      ProfileScreen(numTelephone: widget.numTelephone),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: AppBottomNavBar(
        selectedIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}
