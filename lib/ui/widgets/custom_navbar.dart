import 'dart:ui';

import 'package:el_race/core/ui/adaptive_glass.dart';
import 'package:flutter/material.dart';

class CustomBottomNavbar extends StatefulWidget {
  final int currentIndex;
  final Function(int) onItemTapped;
  final dynamic loginResponseModel;

  const CustomBottomNavbar({
    super.key,
    required this.currentIndex,
    required this.onItemTapped,
    this.loginResponseModel,
  });

  @override
  CustomBottomNavbarState createState() => CustomBottomNavbarState();
}

class CustomBottomNavbarState extends State<CustomBottomNavbar> {
  void _onItemTapped(int index) {
    if (index == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This page is in progress')),
      );
    }
    widget.onItemTapped(index);
  }

  Widget _navItem(String assetPath, int index) {
    final bool selected = index == widget.currentIndex;
    final Color iconColor = selected ? const Color(0xFF151544) : Colors.black54;

    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(index),
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 70, // match navbar height to center vertically
          child: Center(
            child: Image.asset(
              assetPath,
              color: iconColor,
              height: 22,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // SafeArea will automatically add viewPadding.bottom
    // No need to add it manually to avoid double padding
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(
          left: 16.0,
          right: 16.0,
          bottom: 12.0, // Extra padding only, SafeArea handles system bar
        ),
        child: AdaptiveGlassLayer(
          borderRadius: BorderRadius.circular(70.0),
          sigma: 8,
          fallbackColor: Colors.white.withValues(alpha: 0.88),
          fallbackBorder: Border.all(
            color: Colors.white.withValues(alpha: 0.28),
            width: 1.0,
          ),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(70.0),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.28),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _navItem('assets/png/icons/message.png', 0),
                _navItem('assets/png/icons/home.png', 1),
                _navItem('assets/png/icons/phone.png', 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
