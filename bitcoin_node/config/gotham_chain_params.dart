// Gotham Chain Parameters
// Define your fork's specific network parameters

class GothamChainParams {
  // Network Magic Bytes (4 bytes that identify Gotham network messages)
  // From chainparams.cpp: pchMessageStart[0] = 0x47; // 'G', pchMessageStart[1] = 0x4f; // 'O', etc.
  static const List<int> networkMagic = [0x47, 0x4f, 0x54, 0x48]; // "GOTH"
  
  // Default P2P Port
  static const int defaultPort = 8334; // From chainparams.cpp: nDefaultPort = 8334;
  
  // Default RPC Port
  static const int defaultRpcPort = 8332; // From chainparamsbase.cpp: CreateBaseChainParams("", 8332)
  
  // Genesis Block Information
  // From chainparams.cpp: assert(consensus.hashGenesisBlock == uint256{"0000000034e273438482c41f148e67d4a0f9494b44cd88c2ec5b57d4b1fd06ac"});
  static const String genesisBlockHash = "0000000034e273438482c41f148e67d4a0f9494b44cd88c2ec5b57d4b1fd06ac";
  static const int genesisTimestamp = 1750097736; // From CreateGenesisBlock(1750097736, ...)
  static const String genesisMerkleRoot = "99963e155b129514a4c6361543693255d247e540c995b0925c089e22cd642be4"; // From assert
  static const int genesisNonce = 2423956811; // From CreateGenesisBlock(..., 2423956811, ...)
  static const int genesisBits = 0x1d00ffff; // From CreateGenesisBlock(..., 0x1d00ffff, ...)
  
  // Genesis block message - From chainparams.cpp
  static const String genesisMessage = "Gotham 16/Jun/2025 Arkhams gates swing open. The asylum is now the warden.";
  
  // Network Identifiers
  static const String networkName = "gotham";
  static const String addressPrefix = "1"; // From base58Prefixes[PUBKEY_ADDRESS] = std::vector<unsigned char>(1,0);
  static const String scriptPrefix = "3"; // From base58Prefixes[SCRIPT_ADDRESS] = std::vector<unsigned char>(1,5);
  
  // DNS Seeds - Currently empty in the source, will need to be added by Gotham network
  static const List<String> dnsSeeds = [
    // No DNS seeds defined in current chainparams - add when available
  ];
  
  // Hard-coded peer bootstrap list from chainparamsseeds.h (decoded from BIP155 format)
  // These are real Gotham network seed nodes
  static const List<String> bootstrapPeers = [
    // IPv4 addresses from chainparams_seed_main (sample - full list has 100+ nodes)
    "252.16.239.167:8334",
    "252.31.34.195:8334", 
    "252.50.44.22:8334",
    "252.112.222.157:8334",
    "252.119.137.193:8334",
    // Add more as needed from the full seed list
  ];
  
  // Checkpoints for faster sync (block height -> block hash)
  static const Map<int, String> checkpoints = {
    0: genesisBlockHash,
    // Add more checkpoints as your Gotham chain grows
    // 1000: "checkpoint_hash_at_height_1000",
    // 10000: "checkpoint_hash_at_height_10000",
  };
  
  // Protocol Version
  static const int protocolVersion = 70015;
  
  // Service Flags
  static const int nodeNetwork = 1;
  static const int nodeWitness = 8;
  static const int nodeCompactFilters = 1024; // BIP157 support
  
  // Block Time Target (in seconds) - From chainparams.cpp
  static const int blockTimeTarget = 600; // 10 minutes: consensus.nPowTargetSpacing = 10 * 60;
  
  // Difficulty Adjustment - From chainparams.cpp
  static const int difficultyAdjustmentInterval = 2016; // blocks
  static const int difficultyAdjustmentTimespan = 14 * 24 * 60 * 60; // two weeks: consensus.nPowTargetTimespan
  
  // Maximum target (difficulty 1) - From chainparams.cpp
  static const String maxTarget = "00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff"; // consensus.powLimit
  
  // Subsidy halving - From chainparams.cpp
  static const int subsidyHalvingInterval = 210000; // consensus.nSubsidyHalvingInterval = 210000;
  
  // BIP157/158 Filter Parameters
  static const int filterType = 0; // Basic filter
  static const int filterP = 19; // False positive rate parameter
  static const int filterM = 784931; // Hash function count parameter
  
  // Wallet-specific parameters
  static const int bip44CoinType = 1; // Gotham's coin type (to be registered)
  static const String bech32Hrp = "gt"; // From chainparams.cpp: bech32_hrp = "gt";
  
  // Fee estimation
  static const int defaultFeePerByte = 1; // satoshis per byte
  static const int minRelayFee = 1000; // minimum relay fee in satoshis
  
  // Block size limits
  static const int maxBlockSize = 1000000; // 1MB (adjust for Gotham)
  static const int maxBlockWeight = 4000000; // 4M weight units
  
  // Validation parameters
  static const int coinbaseMaturity = 100; // blocks before coinbase can be spent
  static const int maxReorgDepth = 6; // maximum reorg depth to handle
  
  // Network timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration messageTimeout = Duration(seconds: 60);
  static const Duration syncTimeout = Duration(minutes: 5);
  
  // User agent string
  static String get userAgent => "/GothamSPV:1.0.0/";
  
  // Get network magic as bytes
  static List<int> get networkMagicBytes => networkMagic;
  
  // Validate if a block hash matches a checkpoint
  static bool isValidCheckpoint(int height, String blockHash) {
    if (!checkpoints.containsKey(height)) return true;
    return checkpoints[height] == blockHash;
  }
  
  // Get the closest checkpoint before a given height
  static MapEntry<int, String>? getClosestCheckpoint(int height) {
    int closestHeight = -1;
    String? closestHash;
    
    for (var entry in checkpoints.entries) {
      if (entry.key <= height && entry.key > closestHeight) {
        closestHeight = entry.key;
        closestHash = entry.value;
      }
    }
    
    return closestHeight >= 0 ? MapEntry(closestHeight, closestHash!) : null;
  }
  
  // Calculate next difficulty target
  static BigInt calculateNextTarget(BigInt currentTarget, int actualTimespan) {
    // Limit adjustment to 4x up or 1/4 down
    int targetTimespan = difficultyAdjustmentInterval * blockTimeTarget;
    
    if (actualTimespan < targetTimespan ~/ 4) {
      actualTimespan = targetTimespan ~/ 4;
    }
    if (actualTimespan > targetTimespan * 4) {
      actualTimespan = targetTimespan * 4;
    }
    
    BigInt newTarget = currentTarget * BigInt.from(actualTimespan) ~/ BigInt.from(targetTimespan);
    BigInt maxTargetBig = BigInt.parse(maxTarget, radix: 16);
    
    return newTarget > maxTargetBig ? maxTargetBig : newTarget;
  }
}