import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  print('🧹 Clearing old wallet data...');
  
  try {
    // Clear SharedPreferences wallet data
    final prefs = await SharedPreferences.getInstance();
    
    // Remove all wallet-related keys
    await prefs.remove('gotham_wallet');
    await prefs.remove('gotham_selected_wallet_id');
    await prefs.remove('gotham_wallet_list');
    
    // Remove individual wallet data (we'll clear all keys starting with gotham_wallet_)
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith('gotham_wallet_')) {
        await prefs.remove(key);
        print('Removed: $key');
      }
    }
    
    print('✅ SharedPreferences cleared');
    
    // Clear wallet files
    final walletDir = Directory('/home/amr/.gotham/wallets');
    if (await walletDir.exists()) {
      await walletDir.delete(recursive: true);
      print('✅ Wallet directory cleared');
    }
    
    // Clear wallet.dat
    final walletDat = File('/home/amr/.gotham/wallet.dat');
    if (await walletDat.exists()) {
      await walletDat.delete();
      print('✅ wallet.dat cleared');
    }
    
    print('🎉 All wallet data cleared successfully!');
    print('You can now start fresh with Gotham addresses.');
    
  } catch (e) {
    print('❌ Error clearing wallet data: $e');
  }
}