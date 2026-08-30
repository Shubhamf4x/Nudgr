enum PeerConnectionState {
  disconnected,
  connecting,
  connected,
  advertising,
}

class BitChatPeer {
  final String peerId;
  final String? nickname;
  final DateTime lastSeen;
  final PeerConnectionState connectionState;
  final int signalStrength;
  final bool isRelay;
  final int hopCount;

  const BitChatPeer({
    required this.peerId,
    this.nickname,
    required this.lastSeen,
    this.connectionState = PeerConnectionState.disconnected,
    this.signalStrength = 0,
    this.isRelay = false,
    this.hopCount = 0,
  });

  bool get isConnected => connectionState == PeerConnectionState.connected;
  bool get isActive => DateTime.now().difference(lastSeen).inSeconds < 30;

  String get displayId => peerId.length > 8 ? peerId.substring(0, 8) : peerId;
  String get displayName => nickname ?? displayId;

  BitChatPeer copyWith({
    String? peerId,
    String? nickname,
    DateTime? lastSeen,
    PeerConnectionState? connectionState,
    int? signalStrength,
    bool? isRelay,
    int? hopCount,
  }) {
    return BitChatPeer(
      peerId: peerId ?? this.peerId,
      nickname: nickname ?? this.nickname,
      lastSeen: lastSeen ?? this.lastSeen,
      connectionState: connectionState ?? this.connectionState,
      signalStrength: signalStrength ?? this.signalStrength,
      isRelay: isRelay ?? this.isRelay,
      hopCount: hopCount ?? this.hopCount,
    );
  }

  Map<String, dynamic> toJson() => {
    'peerId': peerId,
    'nickname': nickname,
    'lastSeen': lastSeen.toIso8601String(),
    'connectionState': connectionState.index,
    'signalStrength': signalStrength,
    'isRelay': isRelay,
    'hopCount': hopCount,
  };

  factory BitChatPeer.fromJson(Map<String, dynamic> json) => BitChatPeer(
    peerId: json['peerId'],
    nickname: json['nickname'],
    lastSeen: DateTime.parse(json['lastSeen']),
    connectionState: PeerConnectionState.values[json['connectionState'] ?? 0],
    signalStrength: json['signalStrength'] ?? 0,
    isRelay: json['isRelay'] ?? false,
    hopCount: json['hopCount'] ?? 0,
  );
}
