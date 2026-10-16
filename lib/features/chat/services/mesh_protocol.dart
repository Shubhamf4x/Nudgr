import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

class MeshProtocol {
  static const int PACKET_TYPE_MESSAGE = 0x01;
  static const int PACKET_TYPE_ACK = 0x02;
  static const int PACKET_TYPE_DISCOVERY = 0x03;
  static const int PACKET_TYPE_DISCOVERY_RESPONSE = 0x04;
  static const int PACKET_TYPE_RELAY = 0x05;
  static const int PACKET_TYPE_PRIVATE = 0x06;
  static const int PACKET_TYPE_CHANNEL = 0x07;
  static const int MAX_PAYLOAD_SIZE = 512;
  static const int DEFAULT_TTL = 5;
  static const int maxChannelNameLength = 32;
  static const int maxNicknameLength = 32;
  static const int _peerIdBytes = 4;
  static const int _messageIdBytes = 8;
  static const int peerIdHexLength = _peerIdBytes * 2;
  static const int messageIdHexLength = _messageIdBytes * 2;
  static const int HEADER_SIZE =
      1 + 1 + 2 + _peerIdBytes + _peerIdBytes + _messageIdBytes + 2;
  static final RegExp _hexRegExp = RegExp(r'^[0-9a-f]+$');
  static String normalizePeerId(String value) => value.trim().toLowerCase();
  static bool isValidPeerId(String? value) =>
      value != null &&
      value.length == peerIdHexLength &&
      _hexRegExp.hasMatch(normalizePeerId(value));
  static bool isValidMessageId(String? value) =>
      value != null &&
      value.length == messageIdHexLength &&
      _hexRegExp.hasMatch(value.toLowerCase());
  static Uint8List createPacket({
    required int type,
    required String senderId,
    String? recipientId,
    required Uint8List payload,
    int ttl = DEFAULT_TTL,
    String? messageId,
    int hopCount = 0,
  }) {
    if (payload.length > MAX_PAYLOAD_SIZE) {
      throw ArgumentError.value(
        payload.length,
        'payload',
        'exceeds the $MAX_PAYLOAD_SIZE byte mesh limit',
      );
    }
    final sender = normalizePeerId(senderId);
    if (!isValidPeerId(sender)) {
      throw ArgumentError.value(
        senderId,
        'senderId',
        'must be 8 hex characters',
      );
    }
    final recipient = recipientId == null ? null : normalizePeerId(recipientId);
    if (recipient != null && !isValidPeerId(recipient)) {
      throw ArgumentError.value(
        recipientId,
        'recipientId',
        'must be 8 hex characters',
      );
    }
    final resolvedMessageId = messageId == null
        ? generateMessageId()
        : messageId.toLowerCase();
    if (!isValidMessageId(resolvedMessageId)) {
      throw ArgumentError.value(
        messageId,
        'messageId',
        'must be 16 hex characters',
      );
    }
    final buffer = BytesBuilder();
    buffer.addByte(type & 0xff);
    buffer.addByte(ttl & 0xff);
    buffer.add(_uint16Bytes(payload.length));
    buffer.add(_hexToBytes(sender));
    buffer.add(
      recipient == null ? Uint8List(_peerIdBytes) : _hexToBytes(recipient),
    );
    buffer.add(_hexToBytes(resolvedMessageId));
    buffer.add(_uint16Bytes(hopCount));
    buffer.add(payload);
    return buffer.toBytes();
  }

  static Map<String, dynamic>? parsePacket(Uint8List data) {
    if (data.length < HEADER_SIZE) return null;
    var offset = 0;
    final type = data[offset++];
    final ttl = data[offset++];
    final payloadLength = _bytesToUint16(data, offset);
    offset += 2;
    if (payloadLength > MAX_PAYLOAD_SIZE) return null;
    if (offset + payloadLength > data.length) return null;
    final senderId = _bytesToHex(data, offset, _peerIdBytes);
    offset += _peerIdBytes;
    final recipientId = _bytesToHex(data, offset, _peerIdBytes);
    offset += _peerIdBytes;
    final messageId = _bytesToHex(data, offset, _messageIdBytes);
    offset += _messageIdBytes;
    final hopCount = _bytesToUint16(data, offset);
    offset += 2;
    final payload = Uint8List.fromList(
      data.sublist(offset, offset + payloadLength),
    );
    final isBroadcast = recipientId == '0' * peerIdHexLength;
    return {
      'valid': true,
      'type': type,
      'ttl': ttl,
      'senderId': senderId,
      'recipientId': isBroadcast ? null : recipientId,
      'messageId': messageId,
      'hopCount': hopCount,
      'payload': payload,
    };
  }

  static Uint8List createMessagePayload(String content) {
    final contentBytes = utf8.encode(content);
    final buffer = BytesBuilder();
    buffer.add(_uint16Bytes(contentBytes.length));
    buffer.add(contentBytes);
    return buffer.toBytes();
  }

  static String parseMessagePayload(Uint8List payload) {
    if (payload.length < 2) return '';
    final contentLength = _bytesToUint16(payload, 0);
    if (contentLength == 0 || payload.length < 2 + contentLength) return '';
    try {
      return utf8.decode(payload.sublist(2, 2 + contentLength));
    } catch (_) {
      return '';
    }
  }

  static Uint8List createChannelMessagePayload(
    String channelName,
    String content,
  ) {
    final channelBytes = utf8.encode(channelName);
    if (channelBytes.isEmpty || channelBytes.length > maxChannelNameLength) {
      throw ArgumentError.value(
        channelName,
        'channelName',
        'must be 1-$maxChannelNameLength UTF-8 bytes',
      );
    }
    final contentBytes = utf8.encode(content);
    final buffer = BytesBuilder();
    buffer.addByte(channelBytes.length);
    buffer.add(channelBytes);
    buffer.add(_uint16Bytes(contentBytes.length));
    buffer.add(contentBytes);
    return buffer.toBytes();
  }

  static ({String channelName, String content})? parseChannelMessagePayload(
    Uint8List payload,
  ) {
    if (payload.isEmpty) return null;
    final channelLength = payload[0];
    if (channelLength == 0 || payload.length < 1 + channelLength + 2) {
      return null;
    }
    final String channelName;
    try {
      channelName = utf8.decode(payload.sublist(1, 1 + channelLength));
    } catch (_) {
      return null;
    }
    final contentLength = _bytesToUint16(payload, 1 + channelLength);
    final start = 1 + channelLength + 2;
    if (contentLength == 0 || payload.length < start + contentLength) {
      return null;
    }
    try {
      return (
        channelName: channelName,
        content: utf8.decode(payload.sublist(start, start + contentLength)),
      );
    } catch (_) {
      return null;
    }
  }

  static Uint8List createDiscoveryPayload(String peerId, String? nickname) {
    final buffer = BytesBuilder();
    buffer.add(_hexToBytes(normalizePeerId(peerId)));
    final trimmed = nickname?.trim() ?? '';
    if (trimmed.isEmpty) {
      buffer.addByte(0);
    } else {
      final nickBytes = _truncateUtf8(trimmed, maxNicknameLength);
      buffer.addByte(nickBytes.length);
      buffer.add(nickBytes);
    }
    return buffer.toBytes();
  }

  static ({String peerId, String? nickname})? parseDiscoveryPayload(
    Uint8List payload,
  ) {
    if (payload.length < _peerIdBytes) return null;
    final peerId = _bytesToHex(payload, 0, _peerIdBytes);
    var offset = _peerIdBytes;
    String? nickname;
    if (offset < payload.length) {
      final nickLength = payload[offset++];
      if (nickLength > 0 && offset + nickLength <= payload.length) {
        try {
          nickname = utf8.decode(payload.sublist(offset, offset + nickLength));
        } catch (_) {
          nickname = null;
        }
      }
    }
    return (peerId: peerId, nickname: nickname);
  }

  static Uint8List _truncateUtf8(String value, int maxBytes) {
    final bytes = utf8.encode(value);
    if (bytes.length <= maxBytes) return Uint8List.fromList(bytes);
    var end = maxBytes;
    while (end > 0 && (bytes[end] & 0xc0) == 0x80) {
      end--;
    }
    return Uint8List.fromList(bytes.sublist(0, end));
  }

  static Uint8List _hexToBytes(String hex) {
    final normalized = hex.toLowerCase();
    if (normalized.length.isOdd || !_hexRegExp.hasMatch(normalized)) {
      throw FormatException('Expected an even-length hex string', hex);
    }
    final result = Uint8List(normalized.length ~/ 2);
    for (var i = 0; i < normalized.length; i += 2) {
      result[i ~/ 2] = int.parse(normalized.substring(i, i + 2), radix: 16);
    }
    return result;
  }

  static String _bytesToHex(Uint8List bytes, int offset, int length) {
    final buffer = StringBuffer();
    for (var i = offset; i < offset + length; i++) {
      buffer.write(bytes[i].toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  static Uint8List _uint16Bytes(int value) {
    return Uint8List(2)..buffer.asByteData().setUint16(0, value, Endian.big);
  }

  static int _bytesToUint16(Uint8List bytes, int offset) {
    if (offset < 0 || offset + 1 >= bytes.length) return 0;
    return (bytes[offset] << 8) | bytes[offset + 1];
  }

  static Uint8List generateMessageIdBytes() {
    final random = Random.secure();
    final result = Uint8List(_messageIdBytes);
    for (var i = 0; i < _messageIdBytes; i++) {
      result[i] = random.nextInt(256);
    }
    return result;
  }

  static String generateMessageId() =>
      _bytesToHex(generateMessageIdBytes(), 0, _messageIdBytes);
}
