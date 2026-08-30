import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class EncryptionService {
  static Uint8List deriveSharedSecret(Uint8List privateKey, Uint8List peerPublicKey) {
    final combined = Uint8List.fromList(privateKey + peerPublicKey);
    final hash = sha256.convert(combined);
    return Uint8List.fromList(hash.bytes);
  }

  static Uint8List encrypt(Uint8List data, Uint8List key) {
    final paddedKey = _padKey(key);
    final result = Uint8List(data.length);
    final random = Random.secure();
    final iv = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      iv[i] = random.nextInt(256);
    }

    for (var i = 0; i < data.length; i++) {
      final keyByte = paddedKey[i % paddedKey.length];
      final ivByte = iv[i % iv.length];
      result[i] = data[i] ^ keyByte ^ ivByte;
    }

    final buffer = BytesBuilder();
    buffer.add(iv);
    buffer.add(result);
    return buffer.toBytes();
  }

  static Uint8List decrypt(Uint8List encryptedData, Uint8List key) {
    if (encryptedData.length < 16) return Uint8List(0);

    final iv = encryptedData.sublist(0, 16);
    final data = encryptedData.sublist(16);
    final paddedKey = _padKey(key);
    final result = Uint8List(data.length);

    for (var i = 0; i < data.length; i++) {
      final keyByte = paddedKey[i % paddedKey.length];
      final ivByte = iv[i % iv.length];
      result[i] = data[i] ^ keyByte ^ ivByte;
    }

    return result;
  }

  static Uint8List _padKey(Uint8List key) {
    if (key.length >= 32) return key.sublist(0, 32);
    final padded = Uint8List(32);
    padded.setRange(0, key.length, key);
    for (var i = key.length; i < 32; i++) {
      padded[i] = key[i % key.length];
    }
    return padded;
  }

  static String generateNonce() {
    final random = Random.secure();
    final bytes = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      bytes[i] = random.nextInt(256);
    }
    return base64Encode(bytes);
  }

  static Uint8List hashData(Uint8List data) {
    final hash = sha256.convert(data);
    return Uint8List.fromList(hash.bytes);
  }
}
