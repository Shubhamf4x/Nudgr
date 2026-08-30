import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class BitChatIdentity {
  final Uint8List privateKey;
  final Uint8List publicKey;
  final String peerId;
  String? nickname;

  BitChatIdentity({
    required this.privateKey,
    required this.publicKey,
    required this.peerId,
    this.nickname,
  });

  factory BitChatIdentity.generate() {
    final random = Random.secure();
    final privateKey = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      privateKey[i] = random.nextInt(256);
    }
    final publicKey = _derivePublicKey(privateKey);
    final peerId = _derivePeerId(publicKey);
    return BitChatIdentity(
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
    final hex = hash.bytes.take(4).map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
    return hex;
  }

  Uint8List sign(Uint8List data) {
    final combined = Uint8List.fromList(privateKey + data);
    final hash = sha256.convert(combined);
    return Uint8List.fromList(hash.bytes);
  }

  bool verify(Uint8List data, Uint8List signature) {
    final combined = Uint8List.fromList(privateKey + data);
    final hash = sha256.convert(combined);
    final expected = Uint8List.fromList(hash.bytes);
    if (expected.length != signature.length) return false;
    for (var i = 0; i < expected.length; i++) {
      if (expected[i] != signature[i]) return false;
    }
    return true;
  }

  Map<String, dynamic> toJson() => {
    'privateKey': base64Encode(privateKey),
    'publicKey': base64Encode(publicKey),
    'peerId': peerId,
    'nickname': nickname,
  };

  factory BitChatIdentity.fromJson(Map<String, dynamic> json) => BitChatIdentity(
    privateKey: base64Decode(json['privateKey']),
    publicKey: base64Decode(json['publicKey']),
    peerId: json['peerId'],
    nickname: json['nickname'],
  );
}
