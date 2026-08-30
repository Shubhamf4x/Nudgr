import 'dart:typed_data';

enum BitChatMessageType {
  publicChannel,
  privateMessage,
  peerDiscovery,
  ack,
  channelJoin,
  channelLeave,
}

enum MessageDeliveryState {
  pending,
  sending,
  sent,
  delivered,
  failed,
  queued,
}

class BitChatMessage {
  final String id;
  final String senderPeerId;
  final String? senderNickname;
  final String? recipientPeerId;
  final String content;
  final DateTime timestamp;
  final BitChatMessageType type;
  final String? channelName;
  final int ttl;
  final int hopCount;
  final Uint8List? signature;
  final MessageDeliveryState deliveryState;
  final bool isEncrypted;

  const BitChatMessage({
    required this.id,
    required this.senderPeerId,
    this.senderNickname,
    this.recipientPeerId,
    required this.content,
    required this.timestamp,
    this.type = BitChatMessageType.publicChannel,
    this.channelName,
    this.ttl = 5,
    this.hopCount = 0,
    this.signature,
    this.deliveryState = MessageDeliveryState.pending,
    this.isEncrypted = false,
  });

  bool get isMine => false;
  bool get isFromPeer => !isMine;

  BitChatMessage copyWith({
    String? id,
    String? senderPeerId,
    String? senderNickname,
    String? recipientPeerId,
    String? content,
    DateTime? timestamp,
    BitChatMessageType? type,
    String? channelName,
    int? ttl,
    int? hopCount,
    Uint8List? signature,
    MessageDeliveryState? deliveryState,
    bool? isEncrypted,
  }) {
    return BitChatMessage(
      id: id ?? this.id,
      senderPeerId: senderPeerId ?? this.senderPeerId,
      senderNickname: senderNickname ?? this.senderNickname,
      recipientPeerId: recipientPeerId ?? this.recipientPeerId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      channelName: channelName ?? this.channelName,
      ttl: ttl ?? this.ttl,
      hopCount: hopCount ?? this.hopCount,
      signature: signature ?? this.signature,
      deliveryState: deliveryState ?? this.deliveryState,
      isEncrypted: isEncrypted ?? this.isEncrypted,
    );
  }

  Uint8List toBytes() {
    final contentBytes = Uint8List.fromList(content.codeUnits);
    final buffer = BytesBuilder();
    buffer.addByte(type.index);
    buffer.add(_uint32Bytes(timestamp.millisecondsSinceEpoch));
    buffer.add(_uint16Bytes(contentBytes.length));
    buffer.add(contentBytes);
    return buffer.toBytes();
  }

  static Uint8List _uint32Bytes(int value) {
    return Uint8List(4)
      ..buffer.asByteData().setInt32(0, value, Endian.big);
  }

  static Uint8List _uint16Bytes(int value) {
    return Uint8List(2)
      ..buffer.asByteData().setInt16(0, value, Endian.big);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderPeerId': senderPeerId,
    'senderNickname': senderNickname,
    'recipientPeerId': recipientPeerId,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
    'type': type.index,
    'channelName': channelName,
    'ttl': ttl,
    'hopCount': hopCount,
    'deliveryState': deliveryState.index,
    'isEncrypted': isEncrypted,
  };

  factory BitChatMessage.fromJson(Map<String, dynamic> json) => BitChatMessage(
    id: json['id'],
    senderPeerId: json['senderPeerId'],
    senderNickname: json['senderNickname'],
    recipientPeerId: json['recipientPeerId'],
    content: json['content'],
    timestamp: DateTime.parse(json['timestamp']),
    type: BitChatMessageType.values[json['type'] ?? 0],
    channelName: json['channelName'],
    ttl: json['ttl'] ?? 5,
    hopCount: json['hopCount'] ?? 0,
    deliveryState: MessageDeliveryState.values[json['deliveryState'] ?? 0],
    isEncrypted: json['isEncrypted'] ?? false,
  );
}
