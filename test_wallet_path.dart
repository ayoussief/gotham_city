import 'dart:io';
import 'lib/bitcoin_node/services/wallet_storage.dart';

Future<void> main() async {
  final walletStorage = WalletStorage();
  
  try {
    // Initialize wallet storage
    await walletStorage.initialize();
    
    // Get wallet directory and file path
    final walletDir = await walletStorage.walletDirectory;
    final walletPath = await walletStorage.walletFilePath;
    final backupPath = await walletStorage.walletBackupPath;
    
    print('Wallet Directory: $walletDir');
    print('Wallet File: $walletPath');
    print('Backup File: $backupPath');
    
    // Check if files exist
    final walletFile = File(walletPath);
    final backupFile = File(backupPath);
    
    print('\nFile Status:');
    print('wallet.dat exists: ${await walletFile.exists()}');
    print('wallet.dat.bak exists: ${await backupFile.exists()}');
    
    if (await walletFile.exists()) {
      final stat = await walletFile.stat();
      print('wallet.dat size: ${stat.size} bytes');
      print('wallet.dat modified: ${stat.modified}');
    }
    
    // Show wallet info if available
    final walletInfo = walletStorage.getWalletInfo();
    if (walletInfo.isNotEmpty) {
      print('\nWallet Info:');
      print('Version: ${walletInfo['wallet_version']}');
      print('Format: ${walletInfo['format']}');
      print('Balance: ${(walletInfo['balance'] / 100000000).toStringAsFixed(8)} GTC');
      print('Transactions: ${walletInfo['tx_count']}');
      print('Addresses: ${walletInfo['key_pool_size']}');
    }
    
  } catch (e) {
    print('Error: $e');
  }
}