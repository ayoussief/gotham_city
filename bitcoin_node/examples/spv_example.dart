// Example usage of the Gotham SPV Client
// This demonstrates how to initialize and use the SPV client

import '../services/spv_client.dart';
import '../services/wallet_backend.dart';
import '../config/gotham_chain_params.dart';

void main() async {
  print('🦇 Gotham SPV Client Example');
  print('Network: ${GothamChainParams.networkName.toUpperCase()}');
  print('Genesis: ${GothamChainParams.genesisMessage}');
  print('');

  // Initialize the SPV client
  final spvClient = SPVClient();
  final walletBackend = WalletBackend();

  try {
    print('📱 Initializing SPV client...');
    await spvClient.initialize();
    
    print('💰 Initializing wallet...');
    await walletBackend.initialize();
    
    // Create or restore wallet
    print('🔑 Creating new wallet...');
    final seed = await walletBackend.createNewWallet();
    print('Seed (KEEP SAFE): ${seed.substring(0, 20)}...');
    
    // Generate receiving address
    final address = await walletBackend.getNewAddress();
    print('📬 Receiving address: $address');
    
    // Start syncing with Gotham network
    print('🌐 Starting sync with Gotham network...');
    await spvClient.startSync();
    
    // Listen to sync status
    spvClient.syncStatusStream.listen((status) {
      print('📊 Sync Status: ${status.toString()}');
    });
    
    // Listen to new transactions
    spvClient.newTransactionsStream.listen((txids) {
      print('💸 New transactions: ${txids.length}');
      for (final txid in txids) {
        print('  - $txid');
      }
    });
    
    // Check balance periodically
    while (true) {
      await Future.delayed(Duration(seconds: 30));
      
      final balance = await walletBackend.getBalance();
      print('💰 Current balance: ${balance.toStringAsFixed(8)} GTC');
      
      if (balance > 0) {
        print('🎉 You have Gotham coins!');
        
        // Example: Send transaction (uncomment to test)
        /*
        try {
          final txid = await walletBackend.sendTransaction(
            'gt1qrecipient...', // Replace with actual address
            0.001, // Amount in GTC
            0.00001 // Fee rate
          );
          print('📤 Transaction sent: $txid');
        } catch (e) {
          print('❌ Send failed: $e');
        }
        */
      }
    }
    
  } catch (e) {
    print('❌ Error: $e');
  }
}

// Example of wallet operations
class WalletExample {
  final WalletBackend _wallet = WalletBackend();
  
  Future<void> demonstrateWalletFeatures() async {
    await _wallet.initialize();
    
    // Create new wallet
    print('Creating new HD wallet...');
    final seed = await _wallet.createNewWallet();
    print('Mnemonic seed: $seed');
    
    // Generate addresses
    print('\nGenerating addresses:');
    for (int i = 0; i < 5; i++) {
      final address = await _wallet.getNewAddress();
      print('Address $i: $address');
    }
    
    // Check balance
    final balance = await _wallet.getBalance();
    print('\nWallet balance: ${balance.toStringAsFixed(8)} GTC');
    
    // Get UTXOs
    final utxos = await _wallet.getUTXOs();
    print('Available UTXOs: ${utxos.length}');
    
    // Get transaction history
    final history = await _wallet.getTransactionHistory();
    print('Transaction history: ${history.length} transactions');
    
    // Estimate fee
    final fee = await _wallet.estimateFee(2, 2, 0.00001); // 2 inputs, 2 outputs
    print('Estimated fee: ${fee.toStringAsFixed(8)} GTC');
  }
}

// Example of SPV client monitoring
class SPVMonitor {
  final SPVClient _spv = SPVClient();
  
  Future<void> startMonitoring() async {
    await _spv.initialize();
    
    // Monitor connection status
    _spv.connectionStream.listen((connected) {
      print('🌐 Connection: ${connected ? "CONNECTED" : "DISCONNECTED"}');
    });
    
    // Monitor sync progress
    _spv.syncStatusStream.listen((status) {
      if (status.isSyncing) {
        print('⏳ Syncing: ${(status.syncProgress * 100).toStringAsFixed(1)}%');
        print('   Height: ${status.currentHeight}/${status.targetHeight}');
        print('   Filters: ${status.filtersDownloaded}');
      }
    });
    
    // Monitor new blocks
    _spv.newHeadersStream.listen((headers) {
      print('🧱 New blocks: ${headers.length}');
      for (final header in headers) {
        print('   Block ${header.height}: ${header.hash.substring(0, 16)}...');
      }
    });
    
    // Start syncing
    await _spv.startSync();
    
    // Keep monitoring
    while (true) {
      await Future.delayed(Duration(minutes: 1));
      
      print('\n📊 SPV Status:');
      print('   Connected: ${_spv.isConnected}');
      print('   Syncing: ${_spv.isSyncing}');
      print('   Height: ${_spv.currentHeight}');
      print('   Progress: ${(_spv.syncProgress * 100).toStringAsFixed(1)}%');
    }
  }
}

// Network information display
void displayNetworkInfo() {
  print('🌐 Gotham Network Information:');
  print('   Name: ${GothamChainParams.networkName}');
  print('   Magic: ${GothamChainParams.networkMagic.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
  print('   P2P Port: ${GothamChainParams.defaultPort}');
  print('   RPC Port: ${GothamChainParams.defaultRpcPort}');
  print('   Genesis: ${GothamChainParams.genesisBlockHash}');
  print('   Timestamp: ${DateTime.fromMillisecondsSinceEpoch(GothamChainParams.genesisTimestamp * 1000)}');
  print('   Bech32 HRP: ${GothamChainParams.bech32Hrp}');
  print('   Block Time: ${GothamChainParams.blockTimeTarget}s');
  print('   Difficulty Adjustment: ${GothamChainParams.difficultyAdjustmentInterval} blocks');
  print('   Halving Interval: ${GothamChainParams.subsidyHalvingInterval} blocks');
  print('');
}