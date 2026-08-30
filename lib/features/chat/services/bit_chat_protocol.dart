import 'dart:typed_data';

class BitChatProtocol {
  static const int PACKET_TYPE_MESSAGE = 0x01;
  static const int PACKET_TYPE_ACK = 0x02;
  static const int PACKET_TYPE_DISCOVERY = 0x03;
  static const int PACKET_TYPE_DISCOVERY_RESPONSE = 0x04;
  static const int PACKET_TYPE_RELAY = 0x05;
  static const int PACKET_TYPE_PRIVATE = 0x06;
  static const int PACKET_TYPE_CHANNEL = 0x07;

  static const int MAX_PAYLOAD_SIZE = 512;
  static const int HEADER_SIZE = 12;
  static const int DEFAULT_TTL = 5;

  static Uint8List createPacket({
    required int type,
    required String senderId,
    String? recipientId,
    required Uint8List payload,
    int ttl = DEFAULT_TTL,
    String? messageId,
    int hopCount = 0,
  }) {
    final senderBytes = _hexToBytes(senderId);
    final recipientBytes = recipientId != null ? _hexToBytes(recipientId) : Uint8List(8);
    final msgIdBytes = messageId != null ? _hexToBytes(messageId.substring(0, 8)) : _generateMessageId();

    final buffer = BytesBuilder();
    buffer.addByte(type);
    buffer.addByte(ttl);
    buffer.add(_uint16Bytes(payload.length));
    buffer.add(senderBytes);
    buffer.add(recipientBytes);
    buffer.add(msgIdBytes);
    buffer.add(_uint16Bytes(hopCount));
    buffer.add(payload);
    return buffer.toBytes();
  }

  static Map<String, dynamic> parsePacket(Uint8List data) {
    if (data.length < HEADER_SIZE) return {'valid': false};

    int offset = 0;
    final type = data[offset++];
    final ttl = data[offset++];
    final payloadLength = _bytesToUint16(data.sublist(offset, offset + 2));
    offset += 2;

    final senderId = _bytesToHex(data.sublist(offset, offset + 8));
    offset += 8;

    final recipientId = _bytesToHex(data.sublist(offset, offset + 8));
    offset += 8;

    final messageId = _bytesToHex(data.sublist(offset, offset + 8));
    offset += 8;

    final hopCount = _bytesToUint16(data.sublist(offset, offset + 2));
    offset += 2;

    final payload = data.sublist(offset, offset + payloadLength);

    return {
      'valid': true,
      'type': type,
      'ttl': ttl,
      'senderId': senderId,
      'recipientId': recipientId == '0000000000000000' ? null : recipientId,
      'messageId': messageId,
      'hopCount': hopCount,
      'payload': payload,
    };
  }

  static Uint8List createMessagePayload(String content) {
    final contentBytes = Uint8List.fromList(content.codeUnits);
    final buffer = BytesBuilder();
    buffer.add(_uint16Bytes(contentBytes.length));
    buffer.add(contentBytes);
    return buffer.toBytes();
  }

  static String parseMessagePayload(Uint8List payload) {
    if (payload.length < 2) return '';
    final contentLength = _bytesToUint16(payload.sublist(0, 2));
    if (payload.length < 2 + contentLength) return '';
    return String.fromCharCodes(payload.sublist(2, 2 + contentLength));
  }

  static Uint8List createDiscoveryPayload(String peerId, String? nickname) {
    final buffer = BytesBuilder();
    final peerIdBytes = _hexToBytes(peerId);
    buffer.add(peerIdBytes);
    if (nickname != null) {
      final nickBytes = Uint8List.fromList(nickname.codeUnits);
      buffer.addByte(nickBytes.length);
      buffer.add(nickBytes);
    } else {
      buffer.addByte(0);
    }
    return buffer.toBytes();
  }

  static Map<String, String?> parseDiscoveryPayload(Uint8List payload) {
    if (payload.length < 8) return {'peerId': ''};
    final peerId = _bytesToHex(payload.sublist(0, 8));
    int offset = 8;
    String? nickname;
    if (offset < payload.length) {
      final nickLen = payload[offset++];
      if (offset + nickLen <= payload.length) {
        nickname = String.fromCharCodes(payload.sublist(offset, offset + nickLen));
      }
    }
    return {'peerId': peerId, 'nickname': nickname};
  }

  static Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }

  static String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Uint8List _uint16Bytes(int value) {
    return Uint8List(2)..buffer.asByteData().setInt16(0, value, Endian.big);
  }

  static int _bytesToUint16(List<int> bytes) {
    if (bytes.length < 2) return 0;
    return (bytes[0] << 8) | bytes[1];
  }

  static Uint8List _generateMessageId() {
    final result = Uint8List(8);
    final now = DateTime.now().millisecondsSinceEpoch;
    result.buffer.asByteData().setInt64(0, now, Endian.big);
    return result;
  }

  static String generateMessageId() {
    final bytes = _generateMessageId();
    return _bytesToHex(bytes);
  }

  static Uint8List fragmentMessage(Uint8List data, int maxFragmentSize) {
    if (data.length <= maxFragmentSize) return data;
    final fragments = <Uint8List>[];
    for (var i = 0; i < data.length; i += maxFragmentSize) {
      final end = (i + maxFragmentSize).clamp(0, data.length);
      fragments.add(data.sublist(i, end));
    }
    final buffer = BytesBuilder();
    for (final fragment in fragments) {
      buffer.add(_uint16Bytes(fragment.length));
      buffer.add(fragment);
    }
    return buffer.toBytes();
  }

  static List<Uint8List> defragmentMessage(Uint8List data) {
    final fragments = <Uint8List>[];
    int offset = 0;
    while (offset < data.length) {
      if (offset + 2 > data.length) break;
      final fragLen = _bytesToUint16(data.sublist(offset, offset + 2));
      offset += 2;
      if (offset + fragLen > data.length) break;
      fragments.add(data.sublist(offset, offset + fragLen));
      offset += fragLen;
    }
    return fragments;
  }
}
