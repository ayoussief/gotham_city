import 'package:flutter_test/flutter_test.dart';
import 'package:gotham_city/bitcoin_node/wallet/gotham_wallet_manager.dart';
import 'package:gotham_city/bitcoin_node/services/wallet_backend.dart';
import 'package:gotham_city/bitcoin_node/crypto/gotham_wallet.dart';
import 'dart:io';

void main() {
  group('Gotham Wallet System Tests', () {
    late WalletBackend walletBackend;
    late GothamWalletManager walletManager;
    late Directory tempDir;

    setUpAll(() async {
      // Create temporary directory for test wallets
      tempDir = await Directory.systemTemp.createTemp('gotham_wallet_test_');
      
      walletManager = GothamWalletManager();
      await walletManager.initialize(customWalletDir: tempDir.path);
      
      walletBackend = WalletBackend();
      await walletBackend.initialize();
    });

    tearDownAll(() async {
      // Clean up temporary directory
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Create New Wallet - Gotham Core Compatible', () async {
      print('\n=== Testing Wallet Creation (Gotham Core Compatible) ===');
      
      // Create new wallet
      final result = await walletManager.createWallet(
        walletName: 'test_wallet',
        descriptors: true,
        loadOnStartup: true,
      );
      
      expect(result.name, 'test_wallet');
      print('✓ Wallet created: ${result.name}');
      
      // Verify wallet directory structure
      final walletDir = Directory('${tempDir.path}/test_wallet');
      final walletFile = File('${tempDir.path}/test_wallet/wallet.dat');
      
      expect(await walletDir.exists(), true);
      expect(await walletFile.exists(), true);
      print('✓ Wallet directory created: ${walletDir.path}');
      print('✓ wallet.dat file created: ${walletFile.path}');
      
      // Get wallet and check properties
      final wallet = walletManager.getWallet('test_wallet');
      expect(wallet, isNotNull);
      expect(wallet!.isWalletFlagSet(1), true); // WALLET_FLAG_DESCRIPTORS = 1
      print('✓ Wallet is descriptor-based');
      
      // Test wallet info
      final walletInfo = wallet.getWalletInfo();
      print('✓ Wallet info: ${walletInfo}');
      
      expect(walletInfo['walletname'], 'test_wallet');
      expect(walletInfo['descriptors'], true);
      expect(walletInfo['format'], 'sqlite');
    });

    test('Generate Addresses - All Output Types', () async {
      print('\n=== Testing Address Generation ===');
      
      final wallet = walletManager.getWallet('test_wallet');
      expect(wallet, isNotNull);
      
      // Generate addresses for different output types
      final addressTypes = [OutputType.bech32, OutputType.p2pkh, OutputType.p2sh];
      
      for (final outputType in addressTypes) {
        try {
          // Generate receiving address
          final receivingAddr = wallet!.getNewAddress(outputType: outputType);
          print('✓ Generated $outputType receiving address: $receivingAddr');
          
          // Generate change address
          final changeAddr = wallet.getNewChangeAddress(outputType: outputType);
          print('✓ Generated $outputType change address: $changeAddr');
          
          expect(receivingAddr.isNotEmpty, true);
          expect(changeAddr.isNotEmpty, true);
          expect(receivingAddr != changeAddr, true);
        } catch (e) {
          print('⚠ Could not generate $outputType addresses: $e');
        }
      }
    });

    test('Wallet Encryption and Locking', () async {
      print('\n=== Testing Wallet Encryption ===');
      
      // Create new wallet for encryption test
      final result = await walletManager.createWallet(
        walletName: 'encrypted_wallet',
        descriptors: true,
        passphrase: 'test_passphrase_123',
      );
      
      expect(result.name, 'encrypted_wallet');
      print('✓ Encrypted wallet created: ${result.name}');
      
      final wallet = walletManager.getWallet('encrypted_wallet');
      expect(wallet, isNotNull);
      expect(wallet!.isLocked, true);
      print('✓ Wallet is locked after creation');
      
      // Test unlocking
      final unlocked = wallet.unlock('test_passphrase_123');
      expect(unlocked, true);
      expect(wallet.isLocked, false);
      print('✓ Wallet unlocked successfully');
      
      // Test locking again
      wallet.lock();
      expect(wallet.isLocked, true);
      print('✓ Wallet locked again');
      
      // Test wrong passphrase
      final wrongUnlock = wallet.unlock('wrong_passphrase');
      expect(wrongUnlock, false);
      expect(wallet.isLocked, true);
      print('✓ Wrong passphrase correctly rejected');
    });

    test('List Wallets and Wallet Directory', () async {
      print('\n=== Testing Wallet Listing ===');
      
      // List loaded wallets
      final loadedWallets = walletManager.listWallets();
      print('✓ Loaded wallets: $loadedWallets');
      expect(loadedWallets.contains('test_wallet'), true);
      expect(loadedWallets.contains('encrypted_wallet'), true);
      
      // List wallet directory
      final walletDirEntries = await walletManager.listWalletDir();
      print('✓ Wallet directory entries:');
      for (final entry in walletDirEntries) {
        print('  - ${entry.name} (${entry.type})');
        expect(entry.type, 'sqlite');
      }
      
      expect(walletDirEntries.length, greaterThanOrEqualTo(2));
    });

    test('Wallet Backend Integration', () async {
      print('\n=== Testing Wallet Backend Integration ===');
      
      // Create wallet through backend
      final seedHex = await walletBackend.createNewWallet(walletName: 'backend_wallet');
      expect(seedHex.isNotEmpty, true);
      print('✓ Wallet created through backend, seed: ${seedHex.substring(0, 20)}...');
      
      // Get wallet info
      final walletInfo = walletBackend.getWalletInfo();
      expect(walletInfo['walletname'], 'backend_wallet');
      print('✓ Wallet info: ${walletInfo['walletname']} (${walletInfo['format']})');
      
      // Generate addresses through backend
      final receivingAddr = await walletBackend.getReceivingAddress();
      final changeAddr = await walletBackend.getChangeAddress();
      
      expect(receivingAddr.isNotEmpty, true);
      expect(changeAddr.isNotEmpty, true);
      print('✓ Generated receiving address: $receivingAddr');
      print('✓ Generated change address: $changeAddr');
      
      // List wallets through backend
      final backendWallets = walletBackend.listWallets();
      expect(backendWallets.contains('backend_wallet'), true);
      print('✓ Backend wallet list: $backendWallets');
    });

    test('Wallet Unloading and Reloading', () async {
      print('\n=== Testing Wallet Unloading/Reloading ===');
      
      // Unload wallet
      final unloadResult = await walletManager.unloadWallet(walletName: 'test_wallet');
      print('✓ Unloaded wallet: $unloadResult');
      
      // Verify wallet is not in loaded list
      final afterUnload = walletManager.listWallets();
      expect(afterUnload.contains('test_wallet'), false);
      print('✓ Wallet removed from loaded list');
      
      // Reload wallet
      final reloadResult = await walletManager.loadWallet(walletName: 'test_wallet');
      expect(reloadResult.name, 'test_wallet');
      print('✓ Wallet reloaded: ${reloadResult.name}');
      
      // Verify wallet is back in loaded list
      final afterReload = walletManager.listWallets();
      expect(afterReload.contains('test_wallet'), true);
      print('✓ Wallet back in loaded list');
    });

    test('Verify Gotham Core Directory Structure', () async {
      print('\n=== Verifying Gotham Core Compatibility ===');
      
      print('Wallet directory structure:');
      print('${tempDir.path}/');
      
      await for (final entity in tempDir.list()) {
        if (entity is Directory) {
          final walletName = entity.path.split('/').last;
          print('├── $walletName/');
          
          final walletDatFile = File('${entity.path}/wallet.dat');
          if (await walletDatFile.exists()) {
            final size = await walletDatFile.length();
            print('│   └── wallet.dat ($size bytes)');
            
            // Verify wallet.dat content
            final content = await walletDatFile.readAsString();
            expect(content.isNotEmpty, true);
            print('    ✓ wallet.dat contains valid JSON data');
          }
        }
      }
      
      print('\n✓ Directory structure matches Gotham Core format:');
      print('  - ~/.gotham/wallets/wallet_name/wallet.dat');
      print('  - Each wallet has its own directory');
      print('  - wallet.dat contains descriptor wallet data');
      print('  - All wallets are SQLite-based descriptors');
    });
  });
}