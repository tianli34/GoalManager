import 'package:flutter/material.dart';

import 'goals/goals_screen.dart';
import 'now/now_screen.dart';
import 'review/review_screen.dart';
import 'settings/settings_screen.dart';

/// 底部四个入口：当下 / 目标 / 回顾 / 设置。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const List<Widget> _pages = <Widget>[
    NowScreen(),
    GoalsScreen(),
    ReviewScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int index) =>
            setState(() => _index = index),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: '当下',
          ),
          NavigationDestination(
            icon: Icon(Icons.flag_outlined),
            selectedIcon: Icon(Icons.flag),
            label: '目标',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_toggle_off_outlined),
            selectedIcon: Icon(Icons.history_toggle_off),
            label: '回顾',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
