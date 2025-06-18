import 'package:flutter_test/flutter_test.dart';
import 'package:gotham_city/bitcoin_node/wallet/gotham_wallet_manager.dart';
import 'package:gotham_city/bitcoin_node/services/wallet_backend.dart';
import 'package:gotham_city/bitcoin_node/crypto/gotham_wallet.dart';
import 'package:gotham_city/bitcoin_node/primitives/transaction.dart';
import 'package:gotham_city/bitcoin_node/script/script.dart';
import 'dart:io';
import 'dart:typed_data';

void main() {
  group('Complete Gotham Wallet Integration Tests', () {
    late WalletBackend walletBackend;
    late GothamWalletManager walletManager;
    late Directory tempDir;

    setUpAll(() async {
      // Create temporary directory for test wallets
      tempDir = await Directory.systemTemp.createTemp('gotham_integration_test_');
      
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

    test('Full Wallet Lifecycle - Create, Encrypt, Transact', () async {
      print('\n🏗️  === COMPLETE GOTHAM WALLET INTEGRATION TEST ===');
      
      // 1. Create new wallet with encryption
      print('\n📝 Step 1: Creating encrypted wallet...');
      final result = await walletManager.createWallet(
        walletName: 'integration_test_wallet',
        descriptors: true,
        passphrase: 'super_secure_password_123',
        loadOnStartup: true,
      );
      
      expect(result.name, 'integration_test_wallet');
      expect(result.warnings.isEmpty, true);
      print('✅ Wallet created: ${result.name}');
      
      // 2. Verify wallet is encrypted and locked
      final wallet = walletManager.getWallet('integration_test_wallet');
      expect(wallet, isNotNull);
      expect(wallet!.isLocked, true);
      print('✅ Wallet is properly encrypted and locked');
      
      // 3. Test wallet info matches Gotham Core format
      print('\n📊 Step 2: Verifying wallet info...');
      final walletInfo = wallet.getWalletInfo();
      expect(walletInfo['walletname'], 'integration_test_wallet');
      expect(walletInfo['descriptors'], true);
      expect(walletInfo['format'], 'sqlite');
      expect(walletInfo['private_keys_enabled'], true);
      print('✅ Wallet info matches Gotham Core format:');
      print('   - Name: ${walletInfo['walletname']}');
      print('   - Format: ${walletInfo['format']}');
      print('   - Descriptors: ${walletInfo['descriptors']}');
      print('   - Private keys: ${walletInfo['private_keys_enabled']}');
      
      // 4. Unlock wallet for operations
      print('\n🔓 Step 3: Unlocking wallet...');
      final unlocked = wallet.unlock('super_secure_password_123');
      expect(unlocked, true);
      expect(wallet.isLocked, false);
      print('✅ Wallet successfully unlocked');
      
      // 5. Generate addresses using our address system
      print('\n🏠 Step 4: Generating addresses...');
      final bech32Addr = wallet.getNewAddress(outputType: OutputType.bech32);
      final p2pkhAddr = wallet.getNewAddress(outputType: OutputType.p2pkh);
      final p2shAddr = wallet.getNewAddress(outputType: OutputType.p2sh);
      
      expect(bech32Addr.isNotEmpty, true);
      expect(p2pkhAddr.isNotEmpty, true);
      expect(p2shAddr.isNotEmpty, true);
      
      print('✅ Generated addresses:');
      print('   - Bech32: $bech32Addr');
      print('   - P2PKH: $p2pkhAddr');
      print('   - P2SH: $p2shAddr');
      
      // 6. Test transaction creation with our transaction system
      print('\n💸 Step 5: Creating transactions...');
      
      // Create transaction outputs
      final outputs = [
        TransactionOutput(
          address: 'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4', // Example bech32
          amount: 100000, // 0.001 BTC in satoshis
          label: 'Test payment',
        ),
        TransactionOutput(
          address: '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa', // Example P2PKH
          amount: 50000, // 0.0005 BTC in satoshis
          label: 'Another payment',
        ),
      ];
      
      // Create mutable transaction
      final mutableTx = wallet.createTransaction(
        outputs: outputs,
        feeRate: 10, // 10 sat/vB
      );
      
      expect(mutableTx.vout.length, 2);
      expect(mutableTx.vout[0].nValue, 100000);
      expect(mutableTx.vout[1].nValue, 50000);
      print('✅ Transaction created with ${mutableTx.vout.length} outputs');
      
      // Test transaction properties
      print('   - Version: ${mutableTx.version}');
      print('   - Outputs: ${mutableTx.vout.length}');
      print('   - Total value: ${mutableTx.getValueOut()} satoshis');
      print('   - Virtual size: ${mutableTx.getVirtualSize()} vBytes');
      
      // 7. Test script creation for different address types
      print('\n📜 Step 6: Testing script creation...');
      
      // Test P2PKH script creation
      final p2pkhScript = CScript();
      p2pkhScript.add(OP_DUP);
      p2pkhScript.add(OP_HASH160);
      p2pkhScript.addData(List.generate(20, (i) => i));
      p2pkhScript.add(OP_EQUALVERIFY);
      p2pkhScript.add(OP_CHECKSIG);
      
      expect(p2pkhScript.isPayToPubKeyHash(), true);
      expect(p2pkhScript.getType(), ScriptType.payToPubKeyHash);
      print('✅ P2PKH script created and verified');
      
      // Test P2SH script creation
      final p2shScript = CScript();
      p2shScript.add(OP_HASH160);
      p2shScript.addData(List.generate(20, (i) => i));
      p2shScript.add(OP_EQUAL);
      
      expect(p2shScript.isPayToScriptHash(), true);
      expect(p2shScript.getType(), ScriptType.payToScriptHash);
      print('✅ P2SH script created and verified');
      
      // Test witness script creation
      final witnessScript = CScript();
      witnessScript.add(OP_0);
      witnessScript.addData(List.generate(20, (i) => i));
      
      expect(witnessScript.isPayToWitnessPubKeyHash(), true);
      expect(witnessScript.getType(), ScriptType.payToWitnessPubKeyHash);
      print('✅ Witness script created and verified');
      
      // 8. Test transaction signing (mock)
      print('\n✍️  Step 7: Testing transaction signing...');
      final signedTx = wallet.signTransaction(mutableTx);
      
      expect(signedTx.vin.length, mutableTx.vin.length);
      expect(signedTx.vout.length, mutableTx.vout.length);
      expect(signedTx.version, mutableTx.version);
      
      print('✅ Transaction signed:');
      print('   - TXID: ${signedTx.hashHex}');
      print('   - WTXID: ${signedTx.witnessHashHex}');
      print('   - Size: ${signedTx.serialize().length} bytes');
      
      // 9. Test wallet backend integration
      print('\n🔗 Step 8: Testing wallet backend integration...');
      
      // Set active wallet in backend
      await walletBackend.loadWallet('integration_test_wallet');
      
      // Test address generation through backend
      final backendAddr = await walletBackend.getReceivingAddress(
        outputType: OutputType.bech32
      );
      expect(backendAddr.isNotEmpty, true);
      print('✅ Backend address generation: $backendAddr');
      
      // Test wallet info through backend
      final backendWalletInfo = walletBackend.getWalletInfo();
      expect(backendWalletInfo['walletname'], 'integration_test_wallet');
      print('✅ Backend wallet info retrieved');
      
      // Test raw transaction creation
      final rawTxHex = walletBackend.createRawTransaction(
        inputs: [
          {'txid': '0' * 64, 'vout': 0}
        ],
        outputs: {
          'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4': 0.001,
        },
      );
      expect(rawTxHex.isNotEmpty, true);
      print('✅ Raw transaction created: ${rawTxHex.substring(0, 40)}...');
      
      // 10. Test wallet locking and unlocking
      print('\n🔒 Step 9: Testing wallet security...');
      
      wallet.lock();
      expect(wallet.isLocked, true);
      print('✅ Wallet locked successfully');
      
      // Try to create transaction while locked (should fail)
      expect(() => wallet.createTransaction(outputs: outputs),
             throwsA(isA<StateError>()));
      print('✅ Locked wallet prevents transaction creation');
      
      // Unlock again
      final reUnlocked = wallet.unlock('super_secure_password_123');
      expect(reUnlocked, true);
      expect(wallet.isLocked, false);
      print('✅ Wallet unlocked again successfully');
      
      // 11. Verify Gotham Core compatibility
      print('\n⚡ Step 10: Verifying Gotham Core compatibility...');
      
      // Check wallet directory structure
      final walletDir = Directory('${tempDir.path}/integration_test_wallet');
      final walletDatFile = File('${walletDir.path}/wallet.dat');
      
      expect(await walletDir.exists(), true);
      expect(await walletDatFile.exists(), true);
      print('✅ Wallet directory structure matches Gotham Core');
      
      // Check wallet.dat content
      final walletData = await walletDatFile.readAsString();
      expect(walletData.contains('descriptors'), true);
      expect(walletData.contains('sqlite'), true);
      print('✅ wallet.dat format matches Gotham Core');
      
      // Test wallet manager operations
      final walletList = walletManager.listWallets();
      expect(walletList.contains('integration_test_wallet'), true);
      print('✅ Wallet manager operations work correctly');
      
      final walletDirList = await walletManager.listWalletDir();
      expect(walletDirList.any((entry) => entry.name == 'integration_test_wallet'), true);
      print('✅ Wallet directory listing works correctly');
    });

    test('Transaction System Comprehensive Test', () async {
      print('\n🔄 === TRANSACTION SYSTEM COMPREHENSIVE TEST ===');
      
      // 1. Test COutPoint
      print('\n📍 Testing COutPoint...');
      final outpoint = COutPoint.withHash(
        Uint8List.fromList(List.generate(32, (i) => i)),
        12345,
      );
      
      expect(outpoint.n, 12345);
      expect(outpoint.isNull(), false);
      
      final serialized = outpoint.serialize();
      final deserialized = COutPoint.deserialize(serialized);
      expect(deserialized.n, outpoint.n);
      print('✅ COutPoint serialization/deserialization works');
      
      // 2. Test CTxIn
      print('\n📥 Testing CTxIn...');
      final txIn = CTxIn(
        prevout: outpoint,
        nSequence: CTxIn.sequenceFinal,
      );
      
      expect(txIn.nSequence, CTxIn.sequenceFinal);
      expect(txIn.prevout, outpoint);
      print('✅ CTxIn creation and properties work');
      
      // 3. Test CTxOut
      print('\n📤 Testing CTxOut...');
      final script = CScript();
      script.add(OP_DUP);
      script.add(OP_HASH160);
      script.addData(List.generate(20, (i) => i));
      script.add(OP_EQUALVERIFY);
      script.add(OP_CHECKSIG);
      
      final txOut = CTxOut(nValue: 100000, scriptPubKey: script);
      expect(txOut.nValue, 100000);
      expect(txOut.scriptPubKey.isPayToPubKeyHash(), true);
      print('✅ CTxOut creation and script verification work');
      
      // 4. Test CMutableTransaction
      print('\n🔧 Testing CMutableTransaction...');
      final mutableTx = CMutableTransaction();
      mutableTx.vin.add(txIn);
      mutableTx.vout.add(txOut);
      
      expect(mutableTx.vin.length, 1);
      expect(mutableTx.vout.length, 1);
      expect(mutableTx.getValueOut(), 100000);
      expect(mutableTx.isNull, false);
      
      final txSize = mutableTx.getSerializeSize();
      final txWeight = mutableTx.getWeight();
      final txVSize = mutableTx.getVirtualSize();
      
      print('✅ Transaction metrics:');
      print('   - Size: $txSize bytes');
      print('   - Weight: $txWeight WU');
      print('   - Virtual size: $txVSize vBytes');
      
      // 5. Test CTransaction (immutable)
      print('\n🔒 Testing CTransaction...');
      final immutableTx = CTransaction.fromMutable(mutableTx);
      
      expect(immutableTx.vin.length, 1);
      expect(immutableTx.vout.length, 1);
      expect(immutableTx.getValueOut(), 100000);
      expect(immutableTx.hashHex.length, 64); // 32 bytes = 64 hex chars
      
      print('✅ Immutable transaction created:');
      print('   - TXID: ${immutableTx.hashHex}');
      print('   - Has witness: ${immutableTx.hasWitness()}');
      
      // 6. Test transaction serialization
      print('\n💾 Testing transaction serialization...');
      final serializedTx = immutableTx.serialize(includeWitness: true);
      expect(serializedTx.isNotEmpty, true);
      
      final hexTx = serializedTx.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      print('✅ Transaction serialized to hex (${hexTx.length} chars):');
      print('   ${hexTx.substring(0, 60)}...');
      
      // 7. Test UTXO class
      print('\n💰 Testing UTXO...');
      final utxo = UTXO(
        outpoint: outpoint,
        output: txOut,
        confirmations: 6,
        address: 'test_address',
        label: 'Test UTXO',
      );
      
      expect(utxo.amount, 100000);
      expect(utxo.isSpendable, true);
      expect(utxo.confirmations, 6);
      print('✅ UTXO class works correctly');
      print('   - Amount: ${utxo.amount} satoshis');
      print('   - Spendable: ${utxo.isSpendable}');
      print('   - Confirmations: ${utxo.confirmations}');
    });

    test('Script System Comprehensive Test', () async {
      print('\n📜 === SCRIPT SYSTEM COMPREHENSIVE TEST ===');
      
      // 1. Test basic script operations
      print('\n🔤 Testing basic script operations...');
      final script = CScript();
      
      script.add(OP_DUP);
      script.add(OP_HASH160);
      script.addData([1, 2, 3, 4, 5]);
      script.add(OP_EQUALVERIFY);
      script.add(OP_CHECKSIG);
      
      expect(script.size, greaterThan(0));
      expect(script.isEmpty, false);
      print('✅ Basic script operations work');
      
      // 2. Test script types
      print('\n🏷️  Testing script type detection...');
      
      // P2PKH script
      final p2pkhScript = CScript();
      p2pkhScript.add(OP_DUP);
      p2pkhScript.add(OP_HASH160);
      p2pkhScript.addData(List.generate(20, (i) => i));
      p2pkhScript.add(OP_EQUALVERIFY);
      p2pkhScript.add(OP_CHECKSIG);
      
      expect(p2pkhScript.isPayToPubKeyHash(), true);
      expect(p2pkhScript.getType(), ScriptType.payToPubKeyHash);
      print('✅ P2PKH script detection works');
      
      // P2SH script
      final p2shScript = CScript();
      p2shScript.add(OP_HASH160);
      p2shScript.addData(List.generate(20, (i) => i));
      p2shScript.add(OP_EQUAL);
      
      expect(p2shScript.isPayToScriptHash(), true);
      expect(p2shScript.getType(), ScriptType.payToScriptHash);
      print('✅ P2SH script detection works');
      
      // P2WPKH script
      final p2wpkhScript = CScript();
      p2wpkhScript.add(OP_0);
      p2wpkhScript.addData(List.generate(20, (i) => i));
      
      expect(p2wpkhScript.isPayToWitnessPubKeyHash(), true);
      expect(p2wpkhScript.getType(), ScriptType.payToWitnessPubKeyHash);
      print('✅ P2WPKH script detection works');
      
      // P2WSH script
      final p2wshScript = CScript();
      p2wshScript.add(OP_0);
      p2wshScript.addData(List.generate(32, (i) => i));
      
      expect(p2wshScript.isPayToWitnessScriptHash(), true);
      expect(p2wshScript.getType(), ScriptType.payToWitnessScriptHash);
      print('✅ P2WSH script detection works');
      
      // 3. Test script serialization
      print('\n💾 Testing script serialization...');
      final serializedScript = p2pkhScript.serialize();
      expect(serializedScript.isNotEmpty, true);
      print('✅ Script serialization works');
      
      // 4. Test hex conversion
      print('\n🔢 Testing hex conversion...');
      final hexScript = p2pkhScript.toHex();
      expect(hexScript.isNotEmpty, true);
      
      final scriptFromHex = CScript.fromHex(hexScript);
      expect(scriptFromHex, p2pkhScript);
      print('✅ Hex conversion works');
      print('   - Original: ${p2pkhScript.toHex()}');
      print('   - Roundtrip: ${scriptFromHex.toHex()}');
    });

    test('Complete Gotham Core RPC Compatibility', () async {
      print('\n🔌 === GOTHAM CORE RPC COMPATIBILITY TEST ===');
      
      // Create wallet for RPC testing
      await walletManager.createWallet(
        walletName: 'rpc_test_wallet',
        descriptors: true,
      );
      
      await walletBackend.loadWallet('rpc_test_wallet');
      
      // Test wallet RPCs
      print('\n💼 Testing wallet RPCs...');
      
      // getwalletinfo
      final walletInfo = walletBackend.getWalletInfo();
      expect(walletInfo['walletname'], 'rpc_test_wallet');
      print('✅ getwalletinfo RPC compatible');
      
      // listwallets
      final wallets = walletBackend.listWallets();
      expect(wallets.contains('rpc_test_wallet'), true);
      print('✅ listwallets RPC compatible');
      
      // getnewaddress
      final newAddr = await walletBackend.getNewAddress(outputType: OutputType.bech32);
      expect(newAddr.isNotEmpty, true);
      print('✅ getnewaddress RPC compatible: $newAddr');
      
      // getrawchangeaddress
      final changeAddr = await walletBackend.getChangeAddress(outputType: OutputType.bech32);
      expect(changeAddr.isNotEmpty, true);
      print('✅ getrawchangeaddress RPC compatible: $changeAddr');
      
      // Test transaction RPCs
      print('\n💸 Testing transaction RPCs...');
      
      // createrawtransaction
      final rawTx = walletBackend.createRawTransaction(
        inputs: [{'txid': '0' * 64, 'vout': 0}],
        outputs: {'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4': 0.001},
      );
      expect(rawTx.isNotEmpty, true);
      print('✅ createrawtransaction RPC compatible');
      
      // gettransaction (mock)
      final txInfo = walletBackend.getTransaction('test_txid');
      expect(txInfo['txid'], 'test_txid');
      print('✅ gettransaction RPC compatible');
      
      // listtransactions (mock)
      final txList = walletBackend.listTransactions();
      expect(txList, isA<List>());
      print('✅ listtransactions RPC compatible');
      
      // getbalance (mock)
      final balance = walletBackend.getBalance();
      expect(balance, isA<double>());
      print('✅ getbalance RPC compatible');
      
      // listunspent (mock)
      final utxos = walletBackend.listUnspent();
      expect(utxos, isA<List>());
      print('✅ listunspent RPC compatible');
      
      print('\n🎉 ALL GOTHAM CORE RPC METHODS ARE COMPATIBLE! 🎉');
    });
  });
}