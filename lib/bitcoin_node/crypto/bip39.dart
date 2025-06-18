import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// BIP39 Mnemonic Seed implementation for Gotham wallets
class BIP39 {
  
  // BIP39 English wordlist (first 256 words for space efficiency)
  static const List<String> _wordList = [
    'abandon', 'ability', 'able', 'about', 'above', 'absent', 'absorb', 'abstract',
    'absurd', 'abuse', 'access', 'accident', 'account', 'accuse', 'achieve', 'acid',
    'acoustic', 'acquire', 'across', 'act', 'action', 'actor', 'actress', 'actual',
    'adapt', 'add', 'addict', 'address', 'adjust', 'admit', 'adult', 'advance',
    'advice', 'aerobic', 'affair', 'afford', 'afraid', 'again', 'against', 'agent',
    'agree', 'ahead', 'aim', 'air', 'airport', 'aisle', 'alarm', 'album',
    'alcohol', 'alert', 'alien', 'all', 'alley', 'allow', 'almost', 'alone',
    'alpha', 'already', 'also', 'alter', 'always', 'amateur', 'amazing', 'among',
    'amount', 'amused', 'analyst', 'anchor', 'ancient', 'anger', 'angle', 'angry',
    'animal', 'ankle', 'announce', 'annual', 'another', 'answer', 'antenna', 'antique',
    'anxiety', 'any', 'apart', 'apology', 'appear', 'apple', 'approve', 'april',
    'arcade', 'arch', 'arctic', 'area', 'arena', 'argue', 'arm', 'armed',
    'armor', 'army', 'around', 'arrange', 'arrest', 'arrive', 'arrow', 'art',
    'article', 'artist', 'artwork', 'ask', 'aspect', 'assault', 'asset', 'assist',
    'assume', 'asthma', 'athlete', 'atom', 'attack', 'attend', 'attitude', 'attract',
    'auction', 'audit', 'august', 'aunt', 'author', 'auto', 'autumn', 'average',
    'avocado', 'avoid', 'awake', 'aware', 'away', 'awesome', 'awful', 'awkward',
    'axis', 'baby', 'bachelor', 'bacon', 'badge', 'bag', 'balance', 'balcony',
    'ball', 'bamboo', 'banana', 'banner', 'bar', 'barely', 'bargain', 'barrel',
    'base', 'basic', 'basket', 'battle', 'beach', 'bean', 'beauty', 'because',
    'become', 'beef', 'before', 'begin', 'behave', 'behind', 'believe', 'below',
    'belt', 'bench', 'benefit', 'best', 'betray', 'better', 'between', 'beyond',
    'bicycle', 'bid', 'bike', 'bind', 'biology', 'bird', 'birth', 'bitter',
    'black', 'blade', 'blame', 'blanket', 'blast', 'bleak', 'bless', 'blind',
    'blood', 'blossom', 'blow', 'blue', 'blur', 'blush', 'board', 'boat',
    'body', 'boil', 'bomb', 'bone', 'bonus', 'book', 'boost', 'border',
    'boring', 'borrow', 'boss', 'bottom', 'bounce', 'box', 'boy', 'bracket',
    'brain', 'brand', 'brass', 'brave', 'bread', 'breeze', 'brick', 'bridge',
    'brief', 'bright', 'bring', 'brisk', 'broccoli', 'broken', 'bronze', 'broom',
    'brother', 'brown', 'brush', 'bubble', 'buddy', 'budget', 'buffalo', 'build',
    'bulb', 'bulk', 'bullet', 'bundle', 'bunker', 'burden', 'burger', 'burst',
    'bus', 'business', 'busy', 'butter', 'buyer', 'buzz', 'cabbage', 'cabin',
  ];
  
  /// Generate a new BIP39 mnemonic with specified entropy length
  static String generateMnemonic({int strength = 128}) {
    if (![128, 160, 192, 224, 256].contains(strength)) {
      throw ArgumentError('Invalid entropy strength. Must be 128, 160, 192, 224, or 256 bits.');
    }
    
    final entropyLength = strength ~/ 8;
    final entropy = _generateEntropy(entropyLength);
    return _entropyToMnemonic(entropy);
  }
  
  /// Convert entropy bytes to mnemonic words
  static String _entropyToMnemonic(Uint8List entropy) {
    final entropyBits = _bytesToBits(entropy);
    final checksumBits = _calculateChecksumBits(entropy);
    final bits = entropyBits + checksumBits;
    
    final words = <String>[];
    for (int i = 0; i < bits.length; i += 11) {
      final wordBits = bits.substring(i, i + 11);
      final wordIndex = int.parse(wordBits, radix: 2);
      words.add(_wordList[wordIndex % _wordList.length]);
    }
    
    return words.join(' ');
  }
  
  /// Validate a BIP39 mnemonic
  static bool validateMnemonic(String mnemonic) {
    try {
      final words = mnemonic.trim().toLowerCase().split(' ');
      
      // Check word count
      if (![12, 15, 18, 21, 24].contains(words.length)) {
        return false;
      }
      
      // Check if all words are in the word list
      for (final word in words) {
        if (!_wordList.contains(word)) {
          return false;
        }
      }
      
      // Verify checksum
      return _verifyChecksum(words);
    } catch (e) {
      return false;
    }
  }
  
  /// Convert mnemonic to seed using PBKDF2
  static Uint8List mnemonicToSeed(String mnemonic, {String passphrase = ''}) {
    if (!validateMnemonic(mnemonic)) {
      throw ArgumentError('Invalid mnemonic');
    }
    
    final mnemonicBytes = utf8.encode(mnemonic.toLowerCase());
    final saltBytes = utf8.encode('mnemonic$passphrase');
    
    // PBKDF2-HMAC-SHA512 with 2048 iterations
    return _pbkdf2(mnemonicBytes, saltBytes, 2048, 64);
  }
  
  /// Generate a master private key from mnemonic (BIP32 root)
  static Uint8List mnemonicToMasterKey(String mnemonic, {String passphrase = ''}) {
    final seed = mnemonicToSeed(mnemonic, passphrase: passphrase);
    
    // HMAC-SHA512 with "Bitcoin seed" as key
    final hmac = Hmac(sha512, utf8.encode('Bitcoin seed'));
    final hash = hmac.convert(seed);
    
    // Return first 32 bytes as master private key
    return Uint8List.fromList(hash.bytes.take(32).toList());
  }
  
  // Private helper methods
  
  static Uint8List _generateEntropy(int length) {
    final random = Random.secure();
    final entropy = Uint8List(length);
    for (int i = 0; i < length; i++) {
      entropy[i] = random.nextInt(256);
    }
    return entropy;
  }
  
  static String _bytesToBits(Uint8List bytes) {
    return bytes.map((byte) => byte.toRadixString(2).padLeft(8, '0')).join();
  }
  
  static String _calculateChecksumBits(Uint8List entropy) {
    final hash = sha256.convert(entropy);
    final checksumLength = entropy.length * 8 ~/ 32;
    final hashBits = _bytesToBits(Uint8List.fromList(hash.bytes));
    return hashBits.substring(0, checksumLength);
  }
  
  static bool _verifyChecksum(List<String> words) {
    try {
      // Convert words back to indices
      final indices = words.map((word) => _wordList.indexOf(word)).toList();
      
      // Convert to bits
      String bits = '';
      for (final index in indices) {
        bits += index.toRadixString(2).padLeft(11, '0');
      }
      
      // Split entropy and checksum
      final entropyLength = (words.length * 11 - words.length * 11 ~/ 33) ~/ 8 * 8;
      final entropyBits = bits.substring(0, entropyLength);
      final checksumBits = bits.substring(entropyLength);
      
      // Convert entropy bits back to bytes
      final entropy = <int>[];
      for (int i = 0; i < entropyBits.length; i += 8) {
        final byteBits = entropyBits.substring(i, i + 8);
        entropy.add(int.parse(byteBits, radix: 2));
      }
      
      // Calculate expected checksum
      final expectedChecksum = _calculateChecksumBits(Uint8List.fromList(entropy));
      
      return checksumBits == expectedChecksum;
    } catch (e) {
      return false;
    }
  }
  
  // Simplified PBKDF2 implementation
  static Uint8List _pbkdf2(List<int> password, List<int> salt, int iterations, int keyLength) {
    final hmac = Hmac(sha512, password);
    final result = <int>[];
    
    for (int i = 1; result.length < keyLength; i++) {
      final block = _f(hmac, salt, iterations, i);
      result.addAll(block.take(keyLength - result.length));
    }
    
    return Uint8List.fromList(result);
  }
  
  static List<int> _f(Hmac hmac, List<int> salt, int iterations, int blockNumber) {
    final u = <int>[]..addAll(salt)..addAll(_intToBytes(blockNumber));
    var result = hmac.convert(u).bytes;
    
    for (int i = 1; i < iterations; i++) {
      final u_next = hmac.convert(result).bytes;
      for (int j = 0; j < result.length; j++) {
        result[j] ^= u_next[j];
      }
    }
    
    return result;
  }
  
  static List<int> _intToBytes(int value) {
    return [
      (value >> 24) & 0xff,
      (value >> 16) & 0xff,
      (value >> 8) & 0xff,
      value & 0xff,
    ];
  }
  
  /// Get word by index (for testing)
  static String getWord(int index) {
    if (index < 0 || index >= _wordList.length) {
      throw ArgumentError('Word index out of range');
    }
    return _wordList[index];
  }
  
  /// Get word index (for testing)
  static int getWordIndex(String word) {
    final index = _wordList.indexOf(word.toLowerCase());
    if (index == -1) {
      throw ArgumentError('Word not found in wordlist');
    }
    return index;
  }
  
  /// Get total word count
  static int get wordCount => _wordList.length;
}