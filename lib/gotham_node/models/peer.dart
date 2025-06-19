class Peer {
  final String address;
  final int port;
  final String userAgent;
  final int version;
  final int services;
  final int startingHeight;
  final bool inbound;
  final int connectionTime;
  final int lastSend;
  final int lastRecv;
  final int bytesRecv;
  final int bytesSent;
  final double pingTime;
  final bool connected;

  Peer({
    required this.address,
    required this.port,
    this.userAgent = '',
    this.version = 0,
    this.services = 0,
    this.startingHeight = 0,
    this.inbound = false,
    this.connectionTime = 0,
    this.lastSend = 0,
    this.lastRecv = 0,
    this.bytesRecv = 0,
    this.bytesSent = 0,
    this.pingTime = 0.0,
    this.connected = false,
  });

  factory Peer.fromJson(Map<String, dynamic> json) {
    return Peer(
      address: json['addr']?.split(':')[0] ?? '',
      port: int.tryParse(json['addr']?.split(':')[1] ?? '0') ?? 0,
      userAgent: json['subver'] ?? '',
      version: json['version'] ?? 0,
      services: int.tryParse(json['services']?.toString() ?? '0') ?? 0,
      startingHeight: json['startingheight'] ?? 0,
      inbound: json['inbound'] ?? false,
      connectionTime: json['conntime'] ?? 0,
      lastSend: json['lastsend'] ?? 0,
      lastRecv: json['lastrecv'] ?? 0,
      bytesRecv: json['bytesrecv'] ?? 0,
      bytesSent: json['bytessent'] ?? 0,
      pingTime: (json['pingtime'] ?? 0.0).toDouble(),
      connected: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'addr': '$address:$port',
      'subver': userAgent,
      'version': version,
      'services': services,
      'startingheight': startingHeight,
      'inbound': inbound,
      'conntime': connectionTime,
      'lastsend': lastSend,
      'lastrecv': lastRecv,
      'bytesrecv': bytesRecv,
      'bytessent': bytesSent,
      'pingtime': pingTime,
      'connected': connected,
    };
  }

  // Get connection status
  String get connectionStatus {
    if (!connected) return 'Disconnected';
    
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final timeSinceLastRecv = now - lastRecv;
    
    if (timeSinceLastRecv > 300) return 'Stale'; // 5 minutes
    if (timeSinceLastRecv > 60) return 'Slow';   // 1 minute
    return 'Active';
  }

  // Get connection quality based on ping time
  String get connectionQuality {
    if (pingTime == 0) return 'Unknown';
    if (pingTime < 0.1) return 'Excellent';
    if (pingTime < 0.3) return 'Good';
    if (pingTime < 0.5) return 'Fair';
    return 'Poor';
  }

  // Check if peer supports specific services
  bool hasService(int serviceFlag) {
    return (services & serviceFlag) != 0;
  }

  // Common service flags
  static const int nodeNetwork = 1;
  static const int nodeGetUtxo = 2;
  static const int nodeBloom = 4;
  static const int nodeWitness = 8;
  static const int nodeNetworkLimited = 1024;

  // Get supported services as list
  List<String> get supportedServices {
    final List<String> servicesList = [];
    
    if (hasService(nodeNetwork)) servicesList.add('Network');
    if (hasService(nodeGetUtxo)) servicesList.add('GetUTXO');
    if (hasService(nodeBloom)) servicesList.add('Bloom');
    if (hasService(nodeWitness)) servicesList.add('Witness');
    if (hasService(nodeNetworkLimited)) servicesList.add('Limited');
    
    return servicesList;
  }

  // Format bytes for display
  String get formattedBytesRecv {
    return _formatBytes(bytesRecv);
  }

  String get formattedBytesSent {
    return _formatBytes(bytesSent);
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  // Get connection duration
  String get connectionDuration {
    if (connectionTime == 0) return 'Unknown';
    
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final duration = now - connectionTime;
    
    if (duration < 60) return '${duration}s';
    if (duration < 3600) return '${duration ~/ 60}m';
    if (duration < 86400) return '${duration ~/ 3600}h';
    return '${duration ~/ 86400}d';
  }

  @override
  String toString() {
    return 'Peer($address:$port, ${connectionStatus.toLowerCase()}, ${supportedServices.join(', ')})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Peer && other.address == address && other.port == port;
  }

  @override
  int get hashCode => address.hashCode ^ port.hashCode;
}

// Network statistics
class NetworkStats {
  final int totalBytesRecv;
  final int totalBytesSent;
  final int connections;
  final int timeOffset;
  final bool networkActive;
  final List<Peer> peers;

  NetworkStats({
    required this.totalBytesRecv,
    required this.totalBytesSent,
    required this.connections,
    required this.timeOffset,
    required this.networkActive,
    required this.peers,
  });

  factory NetworkStats.fromJson(Map<String, dynamic> json, List<Peer> peers) {
    return NetworkStats(
      totalBytesRecv: json['totalbytesrecv'] ?? 0,
      totalBytesSent: json['totalbytessent'] ?? 0,
      connections: json['connections'] ?? 0,
      timeOffset: json['timeoffset'] ?? 0,
      networkActive: json['networkactive'] ?? false,
      peers: peers,
    );
  }

  // Get active peers count
  int get activePeersCount {
    return peers.where((peer) => peer.connectionStatus == 'Active').length;
  }

  // Get inbound/outbound peer counts
  int get inboundPeersCount {
    return peers.where((peer) => peer.inbound).length;
  }

  int get outboundPeersCount {
    return peers.where((peer) => !peer.inbound).length;
  }

  // Calculate average ping time
  double get averagePingTime {
    final activePeers = peers.where((peer) => peer.pingTime > 0).toList();
    if (activePeers.isEmpty) return 0.0;
    
    final totalPing = activePeers.fold<double>(0.0, (sum, peer) => sum + peer.pingTime);
    return totalPing / activePeers.length;
  }
}