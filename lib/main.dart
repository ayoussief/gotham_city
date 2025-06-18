import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'screens/main_screen.dart';
import 'screens/wallet_selector_screen.dart';

void main() {
  runApp(const GothamCityApp());
}

class GothamCityApp extends StatelessWidget {
  const GothamCityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gotham City',
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
      routes: {
        '/main': (context) => const MainScreen(),
        '/wallet-selector': (context) => const WalletSelectorScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkWalletStatus();
  }

  Future<void> _checkWalletStatus() async {
    // Give splash screen a moment to show
    await Future.delayed(const Duration(milliseconds: 1000));
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final selectedWalletId = prefs.getString('gotham_selected_wallet_id');
      final currentWallet = prefs.getString('gotham_wallet');
      
      if (mounted) {
        if (selectedWalletId != null && currentWallet != null) {
          // User has a selected wallet, go to main screen
          Navigator.of(context).pushReplacementNamed('/main');
        } else {
          // No wallet selected, show wallet selector
          Navigator.of(context).pushReplacementNamed('/wallet-selector');
        }
      }
    } catch (e) {
      print('Error checking wallet status: $e');
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/wallet-selector');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkGray,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.account_balance_wallet,
              size: 80,
              color: AppTheme.accentGold,
            ),
            const SizedBox(height: 24),
            Text(
              'Gotham City',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: AppTheme.accentGold,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Initializing...',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
              color: AppTheme.accentGold,
            ),
          ],
        ),
      ),
    );
  }
}
