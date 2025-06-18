import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/wallet.dart';
import '../models/address_info.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';
import 'address_details_screen.dart';

class AddressListScreen extends StatefulWidget {
  final Wallet wallet;
  final WalletService walletService;

  const AddressListScreen({
    super.key,
    required this.wallet,
    required this.walletService,
  });

  @override
  State<AddressListScreen> createState() => _AddressListScreenState();
}

class _AddressListScreenState extends State<AddressListScreen> {
  List<AddressInfo> _addresses = [];
  bool _isLoading = false;
  bool _showZeroBalances = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final addresses = await widget.walletService.getAllAddresses();
      setState(() {
        _addresses = addresses;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load addresses: $e'),
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

  Future<void> _generateNewAddress() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final newAddress = await widget.walletService.getNewReceiveAddress();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('New address generated: ${_truncateAddress(newAddress)}'),
            backgroundColor: AppTheme.successGreen,
            action: SnackBarAction(
              label: 'Copy',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: newAddress));
              },
            ),
          ),
        );
        
        // Reload addresses to show the new one
        await _loadAddresses();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate address: $e'),
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

  List<AddressInfo> get _filteredAddresses {
    var filtered = _addresses.where((addr) {
      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!addr.address.toLowerCase().contains(query) &&
            !(addr.label?.toLowerCase().contains(query) ?? false)) {
          return false;
        }
      }
      
      // Filter by balance
      if (!_showZeroBalances && addr.balance == 0.0) {
        return false;
      }
      
      return true;
    }).toList();

    // Sort by balance (highest first), then by creation date
    filtered.sort((a, b) {
      final balanceCompare = b.balance.compareTo(a.balance);
      if (balanceCompare != 0) return balanceCompare;
      
      if (a.createdAt != null && b.createdAt != null) {
        return b.createdAt!.compareTo(a.createdAt!);
      }
      return 0;
    });

    return filtered;
  }

  String _truncateAddress(String address) {
    if (address.length <= 20) return address;
    return '${address.substring(0, 10)}...${address.substring(address.length - 10)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Addresses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadAddresses,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'toggle_zero':
                  setState(() {
                    _showZeroBalances = !_showZeroBalances;
                  });
                  break;
                case 'export':
                  _exportAddresses();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggle_zero',
                child: Row(
                  children: [
                    Icon(_showZeroBalances ? Icons.visibility_off : Icons.visibility),
                    const SizedBox(width: 8),
                    Text(_showZeroBalances ? 'Hide Zero Balances' : 'Show Zero Balances'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 8),
                    Text('Export Addresses'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search addresses or labels...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          
          // Summary card
          if (!_isLoading) _buildSummaryCard(),
          
          // Address list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredAddresses.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadAddresses,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredAddresses.length,
                          itemBuilder: (context, index) {
                            final address = _filteredAddresses[index];
                            return _buildAddressCard(address);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _generateNewAddress,
        icon: const Icon(Icons.add),
        label: const Text('New Address'),
        backgroundColor: AppTheme.accentGold,
        foregroundColor: Colors.black,
      ),
    );
  }

  Widget _buildSummaryCard() {
    final totalBalance = _addresses.fold<double>(0.0, (sum, addr) => sum + addr.balance);
    final activeAddresses = _addresses.where((addr) => addr.balance > 0).length;
    final totalAddresses = _addresses.length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Address Summary',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  'Total Balance',
                  '${totalBalance.toStringAsFixed(8)} GTC',
                  Icons.account_balance_wallet,
                  AppTheme.accentGold,
                ),
                _buildSummaryItem(
                  'Active Addresses',
                  '$activeAddresses',
                  Icons.location_on,
                  Colors.green,
                ),
                _buildSummaryItem(
                  'Total Addresses',
                  '$totalAddresses',
                  Icons.list,
                  Colors.blue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildAddressCard(AddressInfo addressInfo) {
    final hasBalance = addressInfo.balance > 0;
    final isCurrentAddress = addressInfo.address == widget.wallet.address;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: hasBalance ? 4 : 1,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddressDetailsScreen(
                addressInfo: addressInfo,
                walletService: widget.walletService,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (isCurrentAddress) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentGold,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'CURRENT',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (addressInfo.label != null) ...[
                              Flexible(
                                child: Text(
                                  addressInfo.label!,
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ] else ...[
                              Text(
                                _getAddressTypeLabel(addressInfo.address),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _truncateAddress(addressInfo.address),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${addressInfo.balance.toStringAsFixed(8)} GTC',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: hasBalance ? AppTheme.accentGold : Colors.grey[600],
                        ),
                      ),
                      if (addressInfo.transactionCount > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${addressInfo.transactionCount} txs',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          _getAddressTypeIcon(addressInfo.address),
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getAddressTypeLabel(addressInfo.address),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (addressInfo.isChange) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              'CHANGE',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.orange[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: addressInfo.address));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Address copied to clipboard'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        tooltip: 'Copy Address',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: Colors.grey[400],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No addresses match your search'
                : 'No addresses found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Generate your first address to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _generateNewAddress,
              icon: const Icon(Icons.add),
              label: const Text('Generate Address'),
            ),
          ],
        ],
      ),
    );
  }

  String _getAddressTypeLabel(String address) {
    if (address.startsWith('gt1')) return 'Bech32 (Native SegWit)';
    if (address.startsWith('3')) return 'P2SH (SegWit)';
    if (address.startsWith('1')) return 'P2PKH (Legacy)';
    return 'Unknown';
  }

  IconData _getAddressTypeIcon(String address) {
    if (address.startsWith('gt1')) return Icons.security;
    if (address.startsWith('3')) return Icons.shield;
    if (address.startsWith('1')) return Icons.account_balance_wallet;
    return Icons.help_outline;
  }

  Future<void> _exportAddresses() async {
    try {
      final csvData = _generateCSV();
      await Clipboard.setData(ClipboardData(text: csvData));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Address list copied to clipboard as CSV'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export addresses: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _generateCSV() {
    final buffer = StringBuffer();
    buffer.writeln('Address,Label,Balance,Type,Transactions,Created');
    
    for (final addr in _addresses) {
      buffer.writeln([
        addr.address,
        addr.label ?? '',
        addr.balance.toStringAsFixed(8),
        _getAddressTypeLabel(addr.address),
        addr.transactionCount,
        addr.createdAt?.toIso8601String() ?? '',
      ].join(','));
    }
    
    return buffer.toString();
  }
}