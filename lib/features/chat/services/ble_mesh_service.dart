import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/chat_identity.dart';
import '../models/chat_peer.dart';
import 'mesh_protocol.dart';

class BleMeshService {
  ChatIdentity? _identity;
  final Map<String, ChatPeer> _peers = {};
  final Set<String> _processedMessageIds = {};
  final List<String> _processedMessageOrder = [];
  final StreamController<ChatPeer> _peerController =
      StreamController<ChatPeer>.broadcast();
  final StreamController<Uint8List> _dataController =
      StreamController<Uint8List>.broadcast();
  final StreamController<bool> _scanStateController =
      StreamController<bool>.broadcast();
  final StreamController<bool> _bluetoothStateController =
      StreamController<bool>.broadcast();
  static const int _maxTrackedMessageIds = 1000;
  bool _isScanning = false;
  bool _isAdvertising = false;
  bool _initialized = false;
  Timer? _scanTimer;
  Timer? _heartbeatTimer;
  StreamSubscription? _adapterStateSubscription;
  Stream<ChatPeer> get peerStream => _peerController.stream;
  Stream<Uint8List> get dataStream => _dataController.stream;
  Stream<bool> get scanStateStream => _scanStateController.stream;
  Stream<bool> get bluetoothStateStream => _bluetoothStateController.stream;
  bool get isScanning => _isScanning;
  bool get isAdvertising => _isAdvertising;
  Map<String, ChatPeer> get peers => Map.unmodifiable(_peers);
  bool get hasRadioTransport => false;
  bool _isBluetoothOn = false;
  bool get isBluetoothOn => _isBluetoothOn;
  Future<void> initialize(ChatIdentity identity) async {
    _identity = identity;
    await _adapterStateSubscription?.cancel();
    _adapterStateSubscription = null;
    try {
      _isBluetoothOn =
          await FlutterBluePlus.adapterState.first == BluetoothAdapterState.on;
    } catch (e) {
      debugPrint('[BleMesh] Bluetooth unavailable: $e');
      _isBluetoothOn = false;
    }
    try {
      _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
        final isOn = state == BluetoothAdapterState.on;
        _isBluetoothOn = isOn;
        _bluetoothStateController.add(isOn);
        if (!isOn && _isScanning) {
          stopScanning();
        }
        if (!isOn && _isAdvertising) {
          stopAdvertising();
        }
      });
    } catch (e) {
      debugPrint('[BleMesh] Cannot observe adapter state: $e');
    }
    _initialized = true;
    _startHeartbeat();
  }

  Future<bool> requestPermissions() async {
    final bluetoothStatuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
    ].request();
    final bluetoothGranted = bluetoothStatuses.values.every(
      (status) => status.isGranted || status.isLimited,
    );
    if (!kIsWeb && Platform.isAndroid && await _isLegacyAndroidScan()) {
      final location = await Permission.locationWhenInUse.request();
      return bluetoothGranted && (location.isGranted || location.isLimited);
    }
    return bluetoothGranted;
  }

  Future<bool> _isLegacyAndroidScan() async {
    try {
      final status = await Permission.bluetoothScan.status;
      return !(status.isGranted || status.isLimited);
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestBluetoothOn() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await FlutterBluePlus.turnOn();
      } catch (e) {
        debugPrint('[BleMesh] Could not enable Bluetooth: $e');
      }
    }
    try {
      _isBluetoothOn =
          await FlutterBluePlus.adapterState.first == BluetoothAdapterState.on;
    } catch (_) {
      _isBluetoothOn = false;
    }
    return _isBluetoothOn;
  }

  Future<void> startScanning() async {
    if (_isScanning) return;
    _isScanning = true;
    _scanStateController.add(true);
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _performScan();
    });
    _performScan();
  }

  Future<void> _performScan() async {
    if (_identity == null || !_initialized) return;
    if (!hasRadioTransport) {
      debugPrint(
        '[BleMesh] Peer discovery is unavailable: no peripheral BLE transport '
        'is linked. See BleMeshService._transmit.',
      );
      return;
    }
  }

  Future<void> stopScanning() async {
    _isScanning = false;
    _scanStateController.add(false);
    _scanTimer?.cancel();
    _scanTimer = null;
  }

  Future<void> startAdvertising() async {
    if (_isAdvertising) return;
    _isAdvertising = true;
    debugPrint('[BleMesh] Advertising as peer ${_identity?.peerId}');
  }

  Future<void> stopAdvertising() async {
    _isAdvertising = false;
  }

  Future<void> sendData(Uint8List data, {String? targetPeerId}) async {
    final identity = _identity;
    if (identity == null) {
      throw StateError('Mesh identity is not initialised');
    }
    final packet = MeshProtocol.createPacket(
      type: targetPeerId == null
          ? MeshProtocol.PACKET_TYPE_CHANNEL
          : MeshProtocol.PACKET_TYPE_PRIVATE,
      senderId: identity.peerId,
      recipientId: targetPeerId,
      payload: data,
    );
    await _transmit(packet, targetPeerId: targetPeerId);
  }

  Future<void> _transmit(Uint8List packet, {String? targetPeerId}) async {
    debugPrint(
      '[BleMesh] Dropping ${packet.length}-byte packet: no BLE transport linked '
      '(target=${targetPeerId ?? 'broadcast'}).',
    );
  }

  void injectPacket(Uint8List rawData, {String? senderPeerId}) {
    processIncomingData(rawData, senderPeerId ?? '');
  }

  bool processIncomingData(Uint8List rawData, String senderPeerId) {
    final parsed = MeshProtocol.parsePacket(rawData);
    if (parsed == null) return false;
    final messageId = parsed['messageId'] as String;
    if (_processedMessageIds.contains(messageId)) return false;
    final ttl = parsed['ttl'] as int;
    final hopCount = parsed['hopCount'] as int;
    if (hopCount >= ttl) return false;
    _rememberMessageId(messageId);
    final senderId = parsed['senderId'] as String;
    if (senderId.isNotEmpty) _updatePeer(senderId);
    _dataController.add(rawData);
    return true;
  }

  Future<void> relayPacket(Uint8List packet) async {
    final parsed = MeshProtocol.parsePacket(packet);
    if (parsed == null) return;
    final messageId = parsed['messageId'] as String;
    if (_processedMessageIds.contains(messageId)) return;
    final ttl = parsed['ttl'] as int;
    final hopCount = parsed['hopCount'] as int;
    if (hopCount >= ttl) return;
    _rememberMessageId(messageId);
    final relayPacket = MeshProtocol.createPacket(
      type: parsed['type'] as int == MeshProtocol.PACKET_TYPE_CHANNEL
          ? MeshProtocol.PACKET_TYPE_CHANNEL
          : MeshProtocol.PACKET_TYPE_PRIVATE,
      senderId: parsed['senderId'] as String,
      recipientId: parsed['recipientId'] as String?,
      payload: parsed['payload'] as Uint8List,
      ttl: ttl,
      messageId: messageId,
      hopCount: hopCount + 1,
    );
    await _transmit(
      relayPacket,
      targetPeerId: parsed['recipientId'] as String?,
    );
  }

  void _rememberMessageId(String messageId) {
    _processedMessageIds.add(messageId);
    _processedMessageOrder.add(messageId);
    while (_processedMessageOrder.length > _maxTrackedMessageIds) {
      final oldest = _processedMessageOrder.removeAt(0);
      _processedMessageIds.remove(oldest);
    }
  }

  void _updatePeer(String peerId, {String? nickname}) {
    final existing = _peers[peerId];
    final peer = ChatPeer(
      peerId: peerId,
      nickname: nickname ?? existing?.nickname,
      lastSeen: DateTime.now(),
      connectionState: PeerConnectionState.connected,
      signalStrength: existing?.signalStrength ?? 0,
      hopCount: existing?.hopCount ?? 0,
    );
    _peers[peerId] = peer;
    _peerController.add(peer);
  }

  void registerPeer(String peerId, {String? nickname}) {
    final normalized = MeshProtocol.normalizePeerId(peerId);
    if (!MeshProtocol.isValidPeerId(normalized)) return;
    _updatePeer(normalized, nickname: nickname?.trim());
  }

  void forgetPeers() {
    _peers.clear();
    _processedMessageIds.clear();
    _processedMessageOrder.clear();
  }

  void removePeer(String peerId) {
    _peers.remove(peerId);
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _cleanStalePeers();
    });
  }

  void _cleanStalePeers() {
    final now = DateTime.now();
    final stalePeers = _peers.entries
        .where((e) => now.difference(e.value.lastSeen).inSeconds > 60)
        .map((e) => e.key)
        .toList();
    for (final peerId in stalePeers) {
      _peers.remove(peerId);
    }
  }

  void dispose() {
    _scanTimer?.cancel();
    _heartbeatTimer?.cancel();
    _adapterStateSubscription?.cancel();
    _peerController.close();
    _dataController.close();
    _scanStateController.close();
    _bluetoothStateController.close();
  }
}
