import 'package:flutter/material.dart';
import 'dart:async';
import '../bitcoin_node/services/gotham_daemon.dart';
import '../theme/app_theme.dart';

class NodeStatusScreen extends StatefulWidget {
  const NodeStatusScreen({super.key});

  @override
  State<NodeStatusScreen> createState() => _NodeStatusScreenState();
}

class _NodeStatusScreenState extends State<NodeStatusScreen> {
  final GothamDaemon _daemon = GothamDaemon();
  
  Map<String, dynamic>? _daemonInfo;
  Map<String, dynamic>? _realtimeStats;
  List<Map<String, dynamic>> _peerInfo = [];
  bool _isConnected = false;
  bool _isLoading = true;
  
  StreamSubscription? _statsSubscription;
  StreamSubscription? _eventsSubscription;

  @override
  void initState() {
    super.initState();
    _initializeNode();
    _setupStreams();
  }

  @override
  void dispose() {
    _statsSubscription?.cancel();
    _eventsSubscription?.cancel();
    super.dispose();
  }

  void _initializeNode() async {
    try {
      if (!_daemon.isRunning) {
        await _daemon.startDaemon().timeout(const Duration(seconds: 30));
      }
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
    // Listen to daemon stats
    _statsSubscription = _daemon.statsStream.listen((stats) {
      if (mounted) {
        setState(() {
          _realtimeStats = stats;
          _isConnected = stats['network_connected'] ?? false;
        });
      }
    });

    // Listen to daemon events
    _eventsSubscription = _daemon.daemonEventsStream.listen((event) {
      if (mounted && event['event'] == 'sync_progress') {
        _loadData(); // Refresh data on sync progress
      }
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load daemon info and peer info
      _daemonInfo = _daemon.getDaemonInfo();
      _peerInfo = await _daemon.getPeerInfo();
      
      if (mounted) {
        setState(() {
          _isConnected = _daemon.isRunning;
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
            content: Text('Failed to load daemon data: $e'),
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

  Future<void> _startDaemon() async {
    if (_daemon.isRunning) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _daemon.startDaemon();
      await _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Gotham Daemon started successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to start daemon: $e'),
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

  Future<void> _stopDaemon() async {
    if (!_daemon.isRunning) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _daemon.stopDaemon();
      
      if (mounted) {
        setState(() {
          _isConnected = false;
          _daemonInfo = null;
          _realtimeStats = null;
          _peerInfo = [];
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🛑 Gotham Daemon stopped'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to stop daemon: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Gotham Node'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (_isConnected ? Colors.green : Colors.red).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _isConnected ? 'RUNNING' : 'STOPPED',
                style: TextStyle(
                  color: _isConnected ? Colors.green : Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (!_daemon.isRunning) ...[
            IconButton(
              icon: const Icon(Icons.play_arrow, color: Colors.green),
              onPressed: _startDaemon,
              tooltip: 'Start Daemon',
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.stop, color: Colors.red),
              onPressed: _stopDaemon,
              tooltip: 'Stop Daemon',
            ),
          ],
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
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
            _daemon.isRunning ? 'Loading Node Data' : 'Starting Gotham Daemon',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Text(
            _daemon.isRunning 
              ? 'Loading blockchain information and network stats...'
              : 'Starting the Gotham daemon...\nThis may take a few moments.',
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
              'Daemon Stopped',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'The Gotham daemon is not running.\n'
              'Start the daemon to begin syncing with the network.',
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
                  onPressed: _startDaemon,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Daemon'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    // If daemon is not running, show offline state
    if (!_daemon.isRunning) {
      return _buildOfflineState();
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDaemonStatus(),
            const SizedBox(height: 16),
            _buildDaemonInfo(),
            const SizedBox(height: 16),
            _buildRealtimeStats(),
            const SizedBox(height: 16),
            _buildPeerInfo(),
            const SizedBox(height: 16),
            _buildDaemonControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildDaemonStatus() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _daemon.isRunning ? Icons.check_circle : Icons.error,
                  color: _daemon.isRunning ? AppTheme.successGreen : AppTheme.dangerRed,
                ),
                const SizedBox(width: 8),
                Text(
                  'Daemon Status',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (_daemon.isRunning ? AppTheme.successGreen : AppTheme.dangerRed).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _daemon.isRunning ? 'RUNNING' : 'STOPPED',
                    style: TextStyle(
                      color: _daemon.isRunning ? AppTheme.successGreen : AppTheme.dangerRed,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (_realtimeStats != null && _realtimeStats!['sync_progress'] != null) ...[
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
                    'Syncing... ${(_realtimeStats!['sync_progress'] * 100).toStringAsFixed(1)}%',
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

  Widget _buildDaemonInfo() {
    if (_daemonInfo == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Daemon information not available',
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
              'Daemon Info',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.accentGold,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Version', _daemonInfo!['version'] ?? 'Unknown'),
            _buildInfoRow('PID', _daemonInfo!['pid']?.toString() ?? 'Unknown'),
            _buildInfoRow('Uptime', _formatUptime(_daemonInfo!['uptime'] ?? 0)),
            _buildInfoRow('Data Dir', _daemonInfo!['data_dir'] ?? 'Unknown'),
            _buildInfoRow('Network', _daemonInfo!['network'] ?? 'Unknown'),
          ],
        ),
      ),
    );
  }

  Widget _buildRealtimeStats() {
    if (_realtimeStats == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Real-time stats not available',
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
              'Real-time Stats',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.accentGold,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Current Height', _realtimeStats!['current_height']?.toString() ?? '0'),
            _buildInfoRow('Best Block', (_realtimeStats!['best_block_hash'] ?? '').toString().substring(0, 16) + '...'),
            _buildInfoRow('Sync Progress', '${(_realtimeStats!['sync_progress'] * 100).toStringAsFixed(2)}%'),
            _buildInfoRow('Network Connected', _realtimeStats!['network_connected'] == true ? 'Yes' : 'No'),
            _buildInfoRow('Active Peers', _realtimeStats!['active_peers']?.toString() ?? '0'),
          ],
        ),
      ),
    );
  }

  Widget _buildPeerInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Peer Connections',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentGold,
                  ),
                ),
                Text(
                  '${_peerInfo.length} peers',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.accentGold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_peerInfo.isEmpty) ...[
              Text(
                'No peer connections',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
              ),
            ] else ...[
              ...(_peerInfo.take(5).map((peer) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.computer,
                      size: 16,
                      color: AppTheme.accentGold,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        peer['addr'] ?? 'Unknown',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    Text(
                      peer['version']?.toString() ?? '',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ))),
              if (_peerInfo.length > 5) ...[
                const SizedBox(height: 8),
                Text(
                  '... and ${_peerInfo.length - 5} more',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDaemonControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daemon Controls',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.accentGold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _daemon.isRunning ? _stopDaemon : _startDaemon,
                    icon: Icon(_daemon.isRunning ? Icons.stop : Icons.play_arrow),
                    label: Text(_daemon.isRunning ? 'Stop Daemon' : 'Start Daemon'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _daemon.isRunning ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatUptime(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${(seconds / 60).floor()}m ${seconds % 60}s';
    final hours = (seconds / 3600).floor();
    final minutes = ((seconds % 3600) / 60).floor();
    return '${hours}h ${minutes}m';
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
            await GothamNodeService().saveConfiguration(
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