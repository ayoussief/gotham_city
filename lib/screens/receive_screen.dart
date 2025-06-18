import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/wallet.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';

class ReceiveScreen extends StatefulWidget {
  final Wallet wallet;
  final WalletService walletService;

  const ReceiveScreen({
    super.key,
    required this.wallet,
    required this.walletService,
  });

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  final _amountController = TextEditingController();
  final _labelController = TextEditingController();
  
  String _currentAddress = '';
  bool _isGeneratingAddress = false;

  @override
  void initState() {
    super.initState();
    _currentAddress = widget.wallet.address;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _generateNewAddress() async {
    setState(() {
      _isGeneratingAddress = true;
    });

    try {
      final newAddress = await widget.walletService.getNewReceiveAddress();
      setState(() {
        _currentAddress = newAddress;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New address generated'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate address: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isGeneratingAddress = false;
      });
    }
  }

  void _copyAddress() {
    Clipboard.setData(ClipboardData(text: _currentAddress));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Address copied to clipboard'),
        backgroundColor: AppTheme.successGreen,
      ),
    );
  }

  void _copyPaymentRequest() {
    final amount = _amountController.text;
    final label = _labelController.text;
    
    String paymentRequest = _currentAddress;
    
    if (amount.isNotEmpty || label.isNotEmpty) {
      paymentRequest += '?';
      final params = <String>[];
      
      if (amount.isNotEmpty) {
        params.add('amount=$amount');
      }
      if (label.isNotEmpty) {
        params.add('label=${Uri.encodeComponent(label)}');
      }
      
      paymentRequest += params.join('&');
    }
    
    Clipboard.setData(ClipboardData(text: paymentRequest));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment request copied to clipboard'),
        backgroundColor: AppTheme.successGreen,
      ),
    );
  }

  void _shareAddress() {
    // TODO: Implement native sharing
    _copyAddress();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive GTC'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareAddress,
            tooltip: 'Share Address',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAddressCard(),
            const SizedBox(height: 16),
            _buildQRCodeCard(),
            const SizedBox(height: 16),
            _buildPaymentRequestForm(),
            const SizedBox(height: 16),
            _buildInstructions(),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Your Gotham Address',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.wallet.isHDWallet)
                  TextButton.icon(
                    onPressed: _isGeneratingAddress ? null : _generateNewAddress,
                    icon: _isGeneratingAddress
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 16),
                    label: const Text('New'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.mediumGray,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.lightGray),
              ),
              child: Column(
                children: [
                  SelectableText(
                    _currentAddress,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _copyAddress,
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copy'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _shareAddress,
                          icon: const Icon(Icons.share, size: 16),
                          label: const Text('Share'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQRCodeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'QR Code',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.lightGray),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.qr_code,
                      size: 80,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'QR Code\nComing Soon',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Scan this QR code to get the address',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentRequestForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Request (Optional)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount (GTC)',
                hintText: '0.00000000',
                helperText: 'Leave empty for any amount',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Label',
                hintText: 'Payment for...',
                helperText: 'Description for this payment',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _copyPaymentRequest,
                icon: const Icon(Icons.copy),
                label: const Text('Copy Payment Request'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.accentGold),
                SizedBox(width: 8),
                Text(
                  'How to Receive GTC',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('1. Share your address with the sender'),
            const SizedBox(height: 4),
            const Text('2. Or let them scan your QR code'),
            const SizedBox(height: 4),
            const Text('3. Wait for the transaction to be confirmed'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.security, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'For privacy, generate a new address for each payment',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}