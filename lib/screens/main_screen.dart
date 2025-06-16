import 'package:flutter/material.dart';
import 'wallet_screen.dart';
import 'jobs_screen.dart';
import 'post_job_screen.dart';
import 'transactions_screen.dart';
import 'node_status_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const WalletScreen(),
    const JobsScreen(),
    const TransactionsScreen(),
    const PostJobScreen(),
    const NodeStatusScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1A1A1A),
        selectedItemColor: const Color(0xFFFFD700),
        unselectedItemColor: Colors.white54,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Wallet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.work),
            label: 'Jobs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle),
            label: 'Post Job',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.hub),
            label: 'Node',
          ),
        ],
      ),
    );
  }
}