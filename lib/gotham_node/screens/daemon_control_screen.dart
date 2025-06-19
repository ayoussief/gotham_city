import 'package:flutter/material.dart';
import 'dart:async';
import '../services/gotham_daemon.dart';

/// Flutter screen for controlling Gotham daemon with buttons! 🎮
/// No CLI needed - we have a beautiful UI!
class DaemonControlScreen extends StatefulWidget {
  const DaemonControlScreen({Key? key}) : super(key: key);

  @override
  State<DaemonControlScreen> createState() => _DaemonControlScreenState();
}

class _DaemonControlScreenState extends State<DaemonControlScreen> {
  final GothamDaemon _daemon = GothamDaemon();
  
  // UI State
  bool _isLoading = false;
  Map<String, dynamic>? _daemonInfo;
  Map<String, dynamic>? _realtimeStats;
  List<String> _logs = [];
  List<Map<String, dynamic>> _events = [];
  
  // Subscriptions
  StreamSubscription? _statsSubscription;
  StreamSubscription? _logsSubscription;
  StreamSubscription? _eventsSubscription;
  
  @override
  void initState() {
    super.initState();
    _initializeStreams();
    _updateDaemonInfo();
  }
  
  @override
  void dispose() {
    _statsSubscription?.cancel();
    _logsSubscription?.cancel();
    _eventsSubscription?.cancel();
    super.dispose();
  }
  
  void _initializeStreams() {
    // Listen to real-time stats
    _statsSubscription = _daemon.statsStream.listen((stats) {
      if (mounted) {
        setState(() {
          _realtimeStats = stats;
        });
      }
    });
    
    // Listen to logs
    _logsSubscription = _daemon.logStream.listen((log) {
      if (mounted) {
        setState(() {
          _logs.add(log);
          if (_logs.length > 100) {
            _logs.removeAt(0); // Keep only last 100 logs
          }
        });
      }
    });
    
    // Listen to events
    _eventsSubscription = _daemon.daemonEventsStream.listen((event) {
      if (mounted) {
        setState(() {
          _events.insert(0, event);
          if (_events.length > 50) {
            _events.removeLast(); // Keep only last 50 events
          }
        });
      }
    });
  }
  
  void _updateDaemonInfo() {
    setState(() {
      _daemonInfo = _daemon.getDaemonInfo();
    });
  }
  
  Future<void> _startDaemon() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _daemon.startDaemon();
      _updateDaemonInfo();
      _showSnackBar('🚀 Daemon started successfully!', Colors.green);
    } catch (e) {
      _showSnackBar('❌ Failed to start daemon: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _stopDaemon() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _daemon.stopDaemon();
      _updateDaemonInfo();
      _showSnackBar('🛑 Daemon stopped successfully!', Colors.orange);
    } catch (e) {
      _showSnackBar('❌ Failed to stop daemon: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _restartSync() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _daemon.restartSync();
      _showSnackBar('🔄 Sync restarted!', Colors.blue);
    } catch (e) {
      _showSnackBar('❌ Failed to restart sync: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🦇 Gotham Daemon Control'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _updateDaemonInfo,
            tooltip: 'Refresh Status',
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
                  _buildControlButtons(),
                  const SizedBox(height: 20),
                  _buildStatusCards(),
                  const SizedBox(height: 20),
                  _buildRealtimeStats(),
                  const SizedBox(height: 20),
                  _buildEventsSection(),
                  const SizedBox(height: 20),
                  _buildLogsSection(),
                ],
              ),
            ),
    );
  }
  
  Widget _buildControlButtons() {
    final isRunning = _daemon.isRunning;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🎮 Daemon Controls',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isRunning ? null : _startDaemon,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Daemon'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: !isRunning ? null : _stopDaemon,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop Daemon'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: !isRunning ? null : _restartSync,
                icon: const Icon(Icons.refresh),
                label: const Text('Restart Sync'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatusCards() {
    if (_daemonInfo == null) return const SizedBox();
    
    final daemon = _daemonInfo!['daemon'] as Map<String, dynamic>;
    final network = _daemonInfo!['network'] as Map<String, dynamic>;
    final blockchain = _daemonInfo!['blockchain'] as Map<String, dynamic>;
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatusCard(
                '🚀 Daemon Status',
                daemon['running'] ? 'Running' : 'Stopped',
                daemon['running'] ? Colors.green : Colors.red,
                subtitle: 'Uptime: ${daemon['uptime_formatted'] ?? '0s'}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatusCard(
                '🌐 Network',
                network['connected'] ? 'Connected' : 'Disconnected',
                network['connected'] ? Colors.green : Colors.red,
                subtitle: 'Peers: ${network['connections']}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatusCard(
                '⛓️ Blockchain',
                'Block ${blockchain['blocks']}',
                Colors.blue,
                subtitle: 'Sync: ${blockchain['sync_progress_percent']}%',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatusCard(
                '🔄 Sync Status',
                blockchain['is_syncing'] ? 'Syncing' : 'Synced',
                blockchain['is_syncing'] ? Colors.orange : Colors.green,
                subtitle: 'Headers: ${blockchain['headers']}',
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildStatusCard(String title, String value, Color color, {String? subtitle}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildRealtimeStats() {
    if (_realtimeStats == null) return const SizedBox();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📊 Real-time Statistics',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _buildStatRow('Current Height', '${_realtimeStats!['current_height']}'),
            _buildStatRow('Target Height', '${_realtimeStats!['target_height']}'),
            _buildStatRow('Sync Progress', '${(_realtimeStats!['sync_progress'] * 100).toStringAsFixed(2)}%'),
            _buildStatRow('Uptime', '${_realtimeStats!['uptime_seconds']}s'),
            _buildStatRow('Data Size', '${(_realtimeStats!['data_dir_size'] / 1024 / 1024).toStringAsFixed(2)} MB'),
            _buildStatRow('Memory Usage', '${(_realtimeStats!['memory_usage'] / 1024 / 1024).toStringAsFixed(2)} MB'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEventsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📅 Recent Events',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: _events.length,
                itemBuilder: (context, index) {
                  final event = _events[index];
                  final timestamp = DateTime.fromMillisecondsSinceEpoch(event['timestamp']);
                  
                  return ListTile(
                    dense: true,
                    leading: _getEventIcon(event['event']),
                    title: Text(event['event']),
                    subtitle: Text(
                      '${timestamp.hour.toString().padLeft(2, '0')}:'
                      '${timestamp.minute.toString().padLeft(2, '0')}:'
                      '${timestamp.second.toString().padLeft(2, '0')}',
                    ),
                    trailing: event['data'] != null
                        ? Icon(Icons.info_outline, size: 16)
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLogsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📝 Daemon Logs',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      _logs[index],
                      style: const TextStyle(
                        color: Colors.green,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _getEventIcon(String event) {
    switch (event) {
      case 'daemon_started':
        return const Icon(Icons.play_arrow, color: Colors.green);
      case 'daemon_stopped':
        return const Icon(Icons.stop, color: Colors.red);
      case 'sync_progress':
        return const Icon(Icons.sync, color: Colors.blue);
      case 'sync_restarted':
        return const Icon(Icons.refresh, color: Colors.orange);
      case 'transaction_sent':
        return const Icon(Icons.send, color: Colors.purple);
      default:
        return const Icon(Icons.info, color: Colors.grey);
    }
  }
}