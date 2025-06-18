import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/wallet.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';

class SendScreen extends StatefulWidget {
  final Wallet wallet;
  final WalletService walletService;

  const SendScreen({
    super.key,
    required this.wallet,
    required this.walletService,
  });

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  final _feeRateController = TextEditingController();
  
  bool _isLoading = false;
  double _estimatedFee = 0.0;
  bool _isMaxAmount = false;

  @override
  void initState() {
    super.initState();
    _feeRateController.text = '1'; // Default fee rate
    _amountController.addListener(_onAmountChanged);
    _feeRateController.addListener(_onFeeRateChanged);
  }

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    _feeRateController.dispose();
    super.dispose();
  }

  void _onAmountChanged() {
    _updateFeeEstimate();
  }

  void _onFeeRateChanged() {
    _updateFeeEstimate();
  }

  Future<void> _updateFeeEstimate() async {
    final amount = double.tryParse(_amountController.text);
    final feeRate = double.tryParse(_feeRateController.text);
    
    if (amount != null && amount > 0 && feeRate != null && feeRate > 0) {
      try {
        final fee = await widget.walletService.estimateFee(
          toAddress: _addressController.text.isNotEmpty ? _addressController.text : 'gt1qexample',
          amount: amount,
          feeRate: feeRate,
        );
        
        if (mounted) {
          setState(() {
            _estimatedFee = fee;
          });
        }
      } catch (e) {
        // Fee estimation failed, use default
        setState(() {
          _estimatedFee = 0.00001; // Default fee
        });
      }
    }
  }

  void _setMaxAmount() {
    final maxAmount = widget.wallet.balance - _estimatedFee;
    if (maxAmount > 0) {
      _amountController.text = maxAmount.toStringAsFixed(8);
      setState(() {
        _isMaxAmount = true;
      });
    }
  }

  Future<void> _sendTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final amount = double.parse(_amountController.text);
      final feeRate = double.parse(_feeRateController.text);
      
      // Confirm transaction
      final confirmed = await _showConfirmationDialog(amount, _estimatedFee);
      if (!confirmed) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final txid = await widget.walletService.sendTransaction(
        toAddress: _addressController.text,
        amount: amount,
        feeRate: feeRate,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transaction sent! TXID: ${txid.substring(0, 16)}...'),
            backgroundColor: AppTheme.successGreen,
            duration: const Duration(seconds: 5),
          ),
        );
        
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send transaction: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _showConfirmationDialog(double amount, double fee) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Transaction'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('To: ${_addressController.text}'),
              const SizedBox(height: 8),
              Text('Amount: ${amount.toStringAsFixed(8)} GTC'),
              const SizedBox(height: 8),
              Text('Fee: ${fee.toStringAsFixed(8)} GTC'),
              const SizedBox(height: 8),
              Text('Total: ${(amount + fee).toStringAsFixed(8)} GTC'),
              const SizedBox(height: 16),
              const Text(
                'This transaction cannot be undone. Please verify all details.',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Send'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send GTC'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBalanceCard(),
              const SizedBox(height: 16),
              _buildAddressField(),
              const SizedBox(height: 16),
              _buildAmountField(),
              const SizedBox(height: 16),
              _buildFeeField(),
              const SizedBox(height: 16),
              _buildSummaryCard(),
              const SizedBox(height: 24),
              _buildSendButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.account_balance_wallet, color: AppTheme.accentGold),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Available Balance'),
                Text(
                  widget.wallet.balanceFormatted,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recipient Address',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _addressController,
          decoration: InputDecoration(
            hintText: 'gt1q... or 1... or 3...',
            suffixIcon: IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: () {
                // TODO: Implement QR code scanner
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('QR scanner coming soon')),
                );
              },
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a recipient address';
            }
            if (!_isValidAddress(value)) {
              return 'Invalid address format';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Amount (GTC)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: _setMaxAmount,
              child: const Text('MAX'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            hintText: '0.00000000',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter an amount';
            }
            final amount = double.tryParse(value);
            if (amount == null || amount <= 0) {
              return 'Please enter a valid amount';
            }
            if (amount > widget.wallet.balance) {
              return 'Insufficient balance';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildFeeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fee Rate (sat/byte)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _feeRateController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            hintText: '1.0',
            helperText: 'Higher fee = faster confirmation',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a fee rate';
            }
            final feeRate = double.tryParse(value);
            if (feeRate == null || feeRate <= 0) {
              return 'Please enter a valid fee rate';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final total = amount + _estimatedFee;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Transaction Summary',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildSummaryRow('Amount', '${amount.toStringAsFixed(8)} GTC'),
            _buildSummaryRow('Network Fee', '${_estimatedFee.toStringAsFixed(8)} GTC'),
            const Divider(),
            _buildSummaryRow(
              'Total',
              '${total.toStringAsFixed(8)} GTC',
              isTotal: true,
            ),
            if (total > widget.wallet.balance)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Insufficient balance for this transaction',
                  style: TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? AppTheme.accentGold : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final total = amount + _estimatedFee;
    final canSend = amount > 0 && 
                   total <= widget.wallet.balance && 
                   _addressController.text.isNotEmpty &&
                   _isValidAddress(_addressController.text);

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: canSend && !_isLoading ? _sendTransaction : null,
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Send Transaction'),
      ),
    );
  }

  bool _isValidAddress(String address) {
    // Basic address validation
    if (address.startsWith('gt1') && address.length >= 42) {
      return true; // Bech32 address
    }
    if (address.startsWith('1') && address.length >= 26 && address.length <= 35) {
      return true; // Legacy P2PKH
    }
    if (address.startsWith('3') && address.length >= 26 && address.length <= 35) {
      return true; // Legacy P2SH
    }
    return false;
  }
}