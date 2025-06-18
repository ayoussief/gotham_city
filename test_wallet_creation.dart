import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart';

Future<void> main() async {
  print('Testing basic wallet functionality...');
  
  try {
    // Test basic cryptographic functions
    print('Testing seed generation...');
    final seed = _generateSeed();
    print('✅ Generated seed: ${seed.split(' ').take(3).join(' ')}...');
    
    // Test private key derivation
    print('Testing private key derivation...');
    final privateKey = _derivePrivateKeyFromSeed(seed);
    print('✅ Derived private key: ${privateKey.substring(0, 8)}...');
    
    // Test address generation
    print('Testing address generation...');
    final address = _deriveAddressFromPrivateKey(privateKey);
    print('✅ Generated address: $address');
    
    // Test wallet.dat creation
    print('Testing wallet.dat creation...');
    await _testWalletDatCreation(seed, privateKey, address);
    print('✅ Wallet.dat created successfully');
    
    print('\n🎉 Basic wallet functionality test completed successfully!');
    
  } catch (e, stackTrace) {
    print('❌ Error during wallet test: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}

String _generateSeed() {
  final words = [
    'abandon', 'ability', 'able', 'about', 'above', 'absent', 'absorb', 'abstract',
    'absurd', 'abuse', 'access', 'accident', 'account', 'accuse', 'achieve', 'acid',
    'acoustic', 'acquire', 'across', 'act', 'action', 'actor', 'actress', 'actual'
  ];
  
  final random = Random.secure();
  final seedWords = <String>[];
  
  for (int i = 0; i < 12; i++) {
    seedWords.add(words[random.nextInt(words.length)]);
  }
  
  return seedWords.join(' ');
}

String _derivePrivateKeyFromSeed(String seed) {
  final seedBytes = utf8.encode(seed);
  final hash = sha256.convert(seedBytes);
  return hash.toString();
}

String _deriveAddressFromPrivateKey(String privateKey) {
  // Simplified address derivation - in real implementation would use proper Bitcoin address derivation
  final keyBytes = utf8.encode(privateKey);
  final hash = sha256.convert(keyBytes);
  final addressHash = hash.toString().substring(0, 34);
  return 'gotham1$addressHash';
}

Future<void> _testWalletDatCreation(String seed, String privateKey, String address) async {
  // Create test wallet directory
  final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
  final walletDir = join(homeDir, '.gotham_test');
  final dir = Directory(walletDir);
  
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  
  // Create wallet.dat structure
  final walletData = {
    'version': 1,
    'created_at': DateTime.now().millisecondsSinceEpoch,
    'network': 'gotham',
    'wallet_descriptor': {
      'type': 'hd',
      'seed_phrase': seed,
      'derivation_path': "m/44'/0'/0'",
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'label': 'Test HD Wallet',
    },
    'master_seed': seed,
    'master_private_key': privateKey,
    'address_index': 1,
    'addresses': {
      address: {
        'private_key': privateKey,
        'public_key': 'pub_$privateKey',
        'derivation_index': 0,
        'label': 'Address 0',
        'is_change': false,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      }
    },
    'private_keys': {address: privateKey},
    'public_keys': {address: 'pub_$privateKey'},
    'watch_addresses': <String>[],
    'transactions': <String, Map<String, dynamic>>{},
    'utxos': <String, Map<String, dynamic>>{},
    'metadata': {
      'label': 'Test Gotham City Wallet',
      'last_backup': null,
      'last_sync': null,
    },
  };
  
  // Save wallet.dat
  final walletFile = File(join(walletDir, 'wallet.dat'));
  final jsonString = jsonEncode(walletData);
  final bytes = utf8.encode(jsonString);
  final encodedData = base64Encode(bytes);
  
  await walletFile.writeAsString(encodedData);
  
  // Verify file was created
  final stat = await walletFile.stat();
  print('   Created wallet.dat: ${stat.size} bytes');
  
  // Test reading it back
  final readData = await walletFile.readAsString();
  final decodedBytes = base64Decode(readData);
  final decodedJson = utf8.decode(decodedBytes);
  final parsedData = jsonDecode(decodedJson);
  
  print('   Verified wallet data: ${parsedData['addresses'].length} addresses');
  
  // Clean up test directory
  await dir.delete(recursive: true);
}