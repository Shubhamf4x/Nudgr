import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../services/mesh_protocol.dart';

class ChatIdentity {
  final Uint8List privateKey;
  final Uint8List publicKey;
  final String peerId;
  String? nickname;
  ChatIdentity({
    required this.privateKey,
    required this.publicKey,
    required this.peerId,
    this.nickname,
  });
  factory ChatIdentity.generate() {
    final random = Random.secure();
    final privateKey = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      privateKey[i] = random.nextInt(256);
    }
    final publicKey = _derivePublicKey(privateKey);
    final peerId = _derivePeerId(publicKey);
    return ChatIdentity(
      privateKey: privateKey,
      publicKey: publicKey,
      peerId: peerId,
    );
  }
  static Uint8List _derivePublicKey(Uint8List privateKey) {
    final hash = sha256.convert(privateKey);
    return Uint8List.fromList(hash.bytes);
  }

  static String _derivePeerId(Uint8List publicKey) {
    final hash = sha256.convert(publicKey);
    return hash.bytes
        .take(4)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  Uint8List sign(Uint8List data) {
    final hmac = Hmac(sha256, privateKey);
    return Uint8List.fromList(hmac.convert(data).bytes);
  }

  bool verify(Uint8List data, Uint8List signature) {
    final expected = sign(data);
    if (expected.length != signature.length) return false;
    var diff = 0;
    for (var i = 0; i < expected.length; i++) {
      diff |= expected[i] ^ signature[i];
    }
    return diff == 0;
  }

  Map<String, dynamic> toJson() => {
    'privateKey': base64Encode(privateKey),
    'publicKey': base64Encode(publicKey),
    'peerId': peerId,
    'nickname': nickname,
  };
  factory ChatIdentity.fromJson(Map<String, dynamic> json) {
    final privateKey = _tryBase64(json['privateKey'], 32);
    final publicKey = _tryBase64(json['publicKey'], 32);
    if (privateKey == null || publicKey == null) {
      return ChatIdentity.generate();
    }
    final rawPeerId = json['peerId'];
    final peerId = rawPeerId is String
        ? MeshProtocol.normalizePeerId(rawPeerId)
        : '';
    final nickname = json['nickname'];
    return ChatIdentity(
      privateKey: privateKey,
      publicKey: publicKey,
      peerId: MeshProtocol.isValidPeerId(peerId)
          ? peerId
          : _derivePeerId(publicKey),
      nickname: nickname is String && nickname.trim().isNotEmpty
          ? nickname.trim()
          : null,
    );
  }
  static Uint8List? _tryBase64(Object? value, int expectedLength) {
    if (value is! String || value.isEmpty) return null;
    try {
      final decoded = base64Decode(value);
      return decoded.length == expectedLength ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
