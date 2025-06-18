/// Crypto Information Screen
/// 
/// This screen showcases our real Bitcoin cryptographic operations:
/// - secp256k1 elliptic curve cryptography
/// - Real Bitcoin address generation
/// - Production-quality implementations
library crypto_info_screen;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/wallet_service.dart';
import '../models/wallet.dart';

class CryptoInfoScreen extends StatefulWidget {
  final Wallet wallet;
  final WalletService walletService;

  const CryptoInfoScreen({
    super.key,
    required this.wallet,
    required this.walletService,
  });

  @override
  State<CryptoInfoScreen> createState() => _CryptoInfoScreenState();
}

class _CryptoInfoScreenState extends State<CryptoInfoScreen> {
  Map<String, dynamic>? _cryptoInfo;
  Map<String, dynamic>? _testResults;
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _loadCryptoInfo();
  }

  Future<void> _loadCryptoInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final info = await widget.walletService.getWalletCryptoInfo();
      setState(() {
        _cryptoInfo = info;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load crypto info: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _runSecp256k1Tests() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await widget.walletService.testSecp256k1Implementation();
      setState(() {
        _testResults = results;
      });

      if (mounted) {
        final success = results['success'] ?? false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success 
                ? '✅ All secp256k1 tests passed!' 
                : '❌ Some tests failed',
            ),
            backgroundColor: success ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to run tests: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔐 Cryptographic Information'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _runSecp256k1Tests,
            icon: const Icon(Icons.quiz),
            tooltip: 'Run Tests',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 16),
                  if (_cryptoInfo != null) _buildCryptoInfoCard(),
                  const SizedBox(height: 16),
                  if (_testResults != null) _buildTestResultsCard(),
                  const SizedBox(height: 16),
                  _buildImplementationDetailsCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.security,
                    color: Colors.green,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Real Bitcoin Cryptography',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'This wallet uses production-ready implementations of Bitcoin\'s cryptographic primitives:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            _buildFeatureRow('✅', 'secp256k1 elliptic curve operations'),
            _buildFeatureRow('✅', 'Real Bitcoin address generation'),
            _buildFeatureRow('✅', 'Production transaction validation'),
            _buildFeatureRow('✅', 'Gotham Core compatible algorithms'),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(String icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildCryptoInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Wallet Cryptographic Details',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoTile('Address', _cryptoInfo!['address']),
            _buildInfoTile('Address Type', _cryptoInfo!['addressType']),
            _buildInfoTile('Script Type', _cryptoInfo!['scriptType']),
            _buildInfoTile('Derivation Path', _cryptoInfo!['derivationPath']),
            _buildInfoTile('Compressed', _cryptoInfo!['compressed'].toString()),
            _buildInfoTile('Network', _cryptoInfo!['network']),
            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text('Public Key (Hex)'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    _cryptoInfo!['publicKey'],
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestResultsCard() {
    final success = _testResults!['success'] ?? false;
    final testsPassed = _testResults!['testsPassed'] ?? 0;
    final totalTests = _testResults!['totalTests'] ?? 0;
    final details = _testResults!['details'] ?? {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  success ? Icons.check_circle : Icons.warning,
                  color: success ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'secp256k1 Test Results',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: success ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: success ? Colors.green : Colors.orange,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tests Passed: $testsPassed / $totalTests',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: success ? Colors.green[700] : Colors.orange[700],
                    ),
                  ),
                  Icon(
                    success ? Icons.verified : Icons.info,
                    color: success ? Colors.green : Colors.orange,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...details.entries.map((entry) => _buildTestDetail(entry.key, entry.value)),
          ],
        ),
      ),
    );
  }

  Widget _buildTestDetail(String testName, dynamic result) {
    final isPass = result.toString().startsWith('PASS');
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isPass ? Icons.check : Icons.close,
            color: isPass ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$testName: $result',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImplementationDetailsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.code, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  'Implementation Details',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailSection(
              'secp256k1 Curve Parameters',
              [
                'Field Prime (p): FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F',
                'Group Order (n): FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141',
                'Generator Point: (79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798, 483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8)',
                'Curve Equation: y² = x³ + 7 (mod p)',
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailSection(
              'Cryptographic Operations',
              [
                'Elliptic Curve Point Multiplication (Scalar * Generator)',
                'Point Addition and Doubling on secp256k1',
                'Modular Arithmetic over Prime Field',
                'Compressed Public Key Serialization (33 bytes)',
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailSection(
              'Address Generation',
              [
                'RIPEMD160(SHA256(PublicKey)) for Address Hash',
                'Base58Check Encoding for Legacy Addresses',
                'Bech32 Encoding for SegWit Addresses',
                'Proper Checksum Validation',
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailSection(
              'Gotham Core Compatibility',
              [
                'Same secp256k1_ec_pubkey_create logic',
                'Identical EncodeDestination behavior',
                'Compatible transaction validation',
                'Matching sendrawtransaction protocol',
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<String> details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        ...details.map((detail) => Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Text(
                  detail,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$label copied to clipboard')),
                );
              },
              child: Text(
                value,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}