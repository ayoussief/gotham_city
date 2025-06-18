import 'package:flutter/material.dart';
import 'dart:async';
import '../models/block_header.dart';
import '../models/peer.dart';
import '../services/bitcoin_node_service.dart';
import '../theme/app_theme.dart';

class NodeStatusScreen extends StatefulWidget {
  const NodeStatusScreen({super.key});

  @override
  State<NodeStatusScreen> createState() => _NodeStatusScreenState();
}

class _NodeStatusScreenState extends State<NodeStatusScreen> {
  final BitcoinNodeService _nodeService = BitcoinNodeService();
  
  BlockchainInfo? _blockchainInfo;
  NetworkStats? _networkStats;
  List<BlockHeader> _recentHeaders = [];
  Map<String, dynamic> _localStats = {};
  bool _isConnected = false;
  bool _isLoading = true;
  
  StreamSubscription? _blockchainInfoSub;
  StreamSubscription? _networkStatsSub;
  StreamSubscription? _blockHeadersSub;
  StreamSubscription? _connectionSub;

  @override
  void initState() {
    super.initState();
    _initializeNode();
    _setupStreams();
  }

  @override
  void dispose() {
    _blockchainInfoSub?.cancel();
    _networkStatsSub?.cancel();
    _blockHeadersSub?.cancel();
    _connectionSub?.cancel();
    super.dispose();
  }

  void _initializeNode() async {
    try {
      await _nodeService.initialize().timeout(const Duration(seconds: 30));
      await _loadData();
    } catch (e) {
      print('Node initialization failed: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _setupStreams() {
    _blockchainInfoSub = _nodeService.blockchainInfoStream.listen((info) {
      if (mounted) {
        setState(() {
          _blockchainInfo = info;
        });
      }
    });

    _networkStatsSub = _nodeService.networkStatsStream.listen((stats) {
      if (mounted) {
        setState(() {
          _networkStats = stats;
        });
      }
    });

    _blockHeadersSub = _nodeService.blockHeadersStream.listen((headers) {
      if (mounted) {
        _loadRecentHeaders();
      }
    });

    _connectionSub = _nodeService.connectionStream.listen((connected) {
      if (mounted) {
        setState(() {
          _isConnected = connected;
        });
      }
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final futures = await Future.wait([
        _nodeService.getBlockchainInfo(),
        _nodeService.getNetworkInfo(),
        _loadRecentHeaders(),
        _loadLocalStats(),
      ]).timeout(const Duration(seconds: 30));

      if (mounted) {
        setState(() {
          _blockchainInfo = futures[0] as BlockchainInfo?;
          _networkStats = futures[1] as NetworkStats?;
          _isConnected = _nodeService.isConnected;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Failed to load node data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        // Show error message to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect to Bitcoin node: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _loadData,
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadRecentHeaders() async {
    final headers = await _nodeService.getLocalBlockHeaders(limit: 10);
    if (mounted) {
      setState(() {
        _recentHeaders = headers;
      });
    }
  }

  Future<void> _loadLocalStats() async {
    final stats = await _nodeService.getLocalStats();
    if (mounted) {
      setState(() {
        _localStats = stats;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Node Status'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () => _nodeService.startSync(),
            tooltip: 'Sync Now',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showNodeSettings,
            tooltip: 'Node Settings',
          ),
        ],
      ),
      body: _isLoading ? _buildLoadingView() : _buildContent(),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: AppTheme.accentGold,
            strokeWidth: 3,
          ),
          const SizedBox(height: 24),
          Text(
            'Connecting to Bitcoin Node',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Text(
            'Attempting to connect to your Bitcoin node...\nThis may take a few moments.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading = false;
                  });
                },
                icon: const Icon(Icons.close),
                label: const Text('Cancel'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGold,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 24),
            Text(
              'Node Offline',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to connect to your Bitcoin node.\n'
              'Please check your node configuration and try again.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry Connection'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentGold,
                    foregroundColor: Colors.black,
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: _showNodeSettings,
                  icon: const Icon(Icons.settings),
                  label: const Text('Node Settings'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    // If there's no connection and no data, show offline state
    if (!_isConnected && _blockchainInfo == null && _networkStats == null) {
      return _buildOfflineState();
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildConnectionStatus(),
            const SizedBox(height: 16),
            _buildBlockchainInfo(),
            const SizedBox(height: 16),
            _buildNetworkStats(),
            const SizedBox(height: 16),
            _buildLocalStats(),
            const SizedBox(height: 16),
            _buildRecentHeaders(),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isConnected ? Icons.check_circle : Icons.error,
                  color: _isConnected ? AppTheme.successGreen : AppTheme.dangerRed,
                ),
                const SizedBox(width: 8),
                Text(
                  'Node Connection',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (_isConnected ? AppTheme.successGreen : AppTheme.dangerRed).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _isConnected ? 'Connected' : 'Disconnected',
                    style: TextStyle(
                      color: _isConnected ? AppTheme.successGreen : AppTheme.dangerRed,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (_nodeService.isSyncing) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.accentGold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Syncing headers...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.accentGold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBlockchainInfo() {
    if (_blockchainInfo == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Blockchain information not available',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Blockchain Info',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.accentGold,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Blocks', _blockchainInfo!.blocks.toString()),
            _buildInfoRow('Headers', _blockchainInfo!.headers.toString()),
            _buildInfoRow('Best Block', _blockchainInfo!.bestBlockHash.substring(0, 16) + '...'),
            _buildInfoRow('Difficulty', _blockchainInfo!.difficulty.toStringAsExponential(2)),
            _buildInfoRow('Sync Progress', '${_blockchainInfo!.syncPercentage.toStringAsFixed(2)}%'),
            if (_blockchainInfo!.verificationProgress < 1.0)
              _buildInfoRow('Verification', '${(_blockchainInfo!.verificationProgress * 100).toStringAsFixed(2)}%'),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkStats() {
    if (_networkStats == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Network information not available',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Network Stats',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.accentGold,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Connections', _networkStats!.connections.toString()),
            _buildInfoRow('Active Peers', _networkStats!.activePeersCount.toString()),
            _buildInfoRow('Inbound', _networkStats!.inboundPeersCount.toString()),
            _buildInfoRow('Outbound', _networkStats!.outboundPeersCount.toString()),
            _buildInfoRow('Avg Ping', '${_networkStats!.averagePingTime.toStringAsFixed(3)}s'),
            _buildInfoRow('Bytes Recv', _formatBytes(_networkStats!.totalBytesRecv)),
            _buildInfoRow('Bytes Sent', _formatBytes(_networkStats!.totalBytesSent)),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalStats() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Local Cache',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.accentGold,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Cached Headers', _localStats['block_headers_count']?.toString() ?? '0'),
            _buildInfoRow('Latest Height', _localStats['latest_height']?.toString() ?? '0'),
            _buildInfoRow('Database Size', _localStats['database_size_mb']?.toString() ?? '0' + ' MB'),
            _buildInfoRow('Known Peers', _localStats['peers_count']?.toString() ?? '0'),
            if (_localStats['latest_block_time'] != null)
              _buildInfoRow('Latest Block', _formatTimestamp(_localStats['latest_block_time'])),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentHeaders() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Headers',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.accentGold,
              ),
            ),
            const SizedBox(height: 12),
            if (_recentHeaders.isEmpty)
              Text(
                'No headers cached yet',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              ...(_recentHeaders.take(5).map((header) => _buildHeaderItem(header))),
            if (_recentHeaders.length > 5)
              TextButton(
                onPressed: () => _showAllHeaders(),
                child: Text('View all ${_recentHeaders.length} headers'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderItem(BlockHeader header) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: header.verifyProofOfWork() ? AppTheme.successGreen : AppTheme.dangerRed,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Block ${header.height}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  header.hash.substring(0, 16) + '...',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatTimestamp(header.timestamp),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  void _showNodeSettings() {
    showDialog(
      context: context,
      builder: (context) => _NodeSettingsDialog(),
    );
  }

  void _showAllHeaders() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _AllHeadersScreen(headers: _recentHeaders),
      ),
    );
  }
}

class _NodeSettingsDialog extends StatefulWidget {
  @override
  State<_NodeSettingsDialog> createState() => _NodeSettingsDialogState();
}

class _NodeSettingsDialogState extends State<_NodeSettingsDialog> {
  final _hostController = TextEditingController(text: 'localhost');
  final _portController = TextEditingController(text: '8332');
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Node Settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _hostController,
            decoration: const InputDecoration(labelText: 'RPC Host'),
          ),
          TextField(
            controller: _portController,
            decoration: const InputDecoration(labelText: 'RPC Port'),
            keyboardType: TextInputType.number,
          ),
          TextField(
            controller: _userController,
            decoration: const InputDecoration(labelText: 'RPC User'),
          ),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(labelText: 'RPC Password'),
            obscureText: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            await BitcoinNodeService().saveConfiguration(
              host: _hostController.text,
              port: int.tryParse(_portController.text) ?? 8332,
              user: _userController.text,
              password: _passwordController.text,
            );
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _AllHeadersScreen extends StatelessWidget {
  final List<BlockHeader> headers;

  const _AllHeadersScreen({required this.headers});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('All Headers (${headers.length})'),
      ),
      body: ListView.builder(
        itemCount: headers.length,
        itemBuilder: (context, index) {
          final header = headers[index];
          return ListTile(
            leading: Icon(
              Icons.block,
              color: header.verifyProofOfWork() ? AppTheme.successGreen : AppTheme.dangerRed,
            ),
            title: Text('Block ${header.height}'),
            subtitle: Text(header.hash),
            trailing: Text(_formatTimestamp(header.timestamp)),
          );
        },
      ),
    );
  }

  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}