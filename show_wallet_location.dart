import 'dart:io';

// Simple script to show where wallet files are stored
void main() async {
  // Get user's home directory
  final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
  final walletDir = '$homeDir/.gotham';
  
  print('=== Gotham City Wallet Storage Locations ===');
  print('');
  print('Wallet Directory: $walletDir');
  print('Main wallet.dat file: $walletDir/wallet.dat');
  print('Backup wallet.dat.bak file: $walletDir/wallet.dat.bak');
  print('Named wallet files: $walletDir/[wallet_name].dat');
  print('');
  
  // Check if directory exists
  final dir = Directory(walletDir);
  if (await dir.exists()) {
    print('✅ Wallet directory exists');
    
    final walletFile = File('$walletDir/wallet.dat');
    final backupFile = File('$walletDir/wallet.dat.bak');
    
    if (await walletFile.exists()) {
      final stat = await walletFile.stat();
      print('✅ wallet.dat exists (${stat.size} bytes, modified: ${stat.modified})');
    } else {
      print('❌ wallet.dat does not exist');
    }
    
    if (await backupFile.exists()) {
      final stat = await backupFile.stat();
      print('✅ wallet.dat.bak exists (${stat.size} bytes, modified: ${stat.modified})');
    } else {
      print('❌ wallet.dat.bak does not exist');
    }
    
    // List all files in the wallet directory
    print('');
    print('Files in wallet directory:');
    final files = <FileSystemEntity>[];
    await for (final entity in dir.list()) {
      if (entity is File) {
        files.add(entity);
      }
    }
    
    if (files.isEmpty) {
      print('  (No files found)');
    } else {
      files.sort((a, b) => a.path.compareTo(b.path));
      for (final file in files) {
        final stat = await file.stat();
        final fileName = file.path.split('/').last;
        final fileType = fileName.endsWith('.dat') ? '📄 Wallet' : '📄';
        print('  $fileType $fileName (${stat.size} bytes, ${stat.modified})');
      }
    }
  } else {
    print('❌ Wallet directory does not exist yet');
    print('   Directory will be created when you first create a wallet');
  }
  
  print('');
  print('=== How It Works ===');
  print('1. Each wallet gets its own [name].dat file');
  print('2. The main wallet.dat contains the currently active wallet');
  print('3. SharedPreferences stores the wallet list and selected wallet ID');
  print('4. When you switch wallets, the selected wallet is copied to wallet.dat');
  print('');
  print('=== Backup Instructions ===');
  print('1. Copy the entire ~/.gotham directory to a secure location');
  print('2. Or use the "Backup Wallet" feature in Settings');
  print('3. Keep your seed phrase written down separately');
  print('4. Each wallet file contains: keys, seed phrase, and metadata');
  print('5. Never share your private keys or seed phrase!');
}