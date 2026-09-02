import 'dart:async';
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
  final StreamController<ChatPeer> _peerController = StreamController<ChatPeer>.broadcast();
  final StreamController<Uint8List> _dataController = StreamController<Uint8List>.broadcast();
  final StreamController<bool> _scanStateController = StreamController<bool>.broadcast();
  final StreamController<bool> _bluetoothStateController = StreamController<bool>.broadcast();

  bool _isScanning = false;
  bool _isAdvertising = false;
  Timer? _scanTimer;
  Timer? _heartbeatTimer;
  StreamSubscription? _adapterStateSubscription;

  Stream<ChatPeer> get peerStream => _peerController.stream;
  Stream<Uint8List> get dataStream => _dataController.stream;
  Stream<bool> get scanStateStream => _scanStateController.stream;
  Stream<bool> get bluetoothStateStream => _bluetoothStateController.stream;
  bool get isScanning => _isScanning;
  Map<String, ChatPeer> get peers => Map.unmodifiable(_peers);

  bool _isBluetoothOn = false;
  bool get isBluetoothOn => _isBluetoothOn;

  Future<void> initialize(ChatIdentity identity) async {
    _identity = identity;

    _isBluetoothOn =
        await FlutterBluePlus.adapterState.first == BluetoothAdapterState.on;

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

    _startHeartbeat();
  }

  Future<bool> requestPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    final allGranted = statuses.values.every(
      (status) => status.isGranted || status.isLimited,
    );
    return allGranted;
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
    if (_identity == null) return;
    debugPrint('[BleMesh] Scanning for peers...');

    try {
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('[BleMesh] Scan error: $e');
    }
  }

  Future<void> stopScanning() async {
    _isScanning = false;
    _scanStateController.add(false);
    _scanTimer?.cancel();
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
    final packet = MeshProtocol.createPacket(
      type: MeshProtocol.PACKET_TYPE_MESSAGE,
      senderId: _identity!.peerId,
      recipientId: targetPeerId,
      payload: data,
    );
    debugPrint('[BleMesh] Sending data: ${data.length} bytes');
    _dataController.add(packet);
  }

  bool processIncomingData(Uint8List rawData, String senderPeerId) {
    final parsed = MeshProtocol.parsePacket(rawData);
    if (!parsed['valid']) return false;

    final messageId = parsed['messageId'] as String;
    if (_processedMessageIds.contains(messageId)) return false;
    _processedMessageIds.add(messageId);

    if (_processedMessageIds.length > 1000) {
      final toRemove = _processedMessageIds.take(500).toList();
      _processedMessageIds.removeAll(toRemove);
    }

    final ttl = parsed['ttl'] as int;
    final hopCount = parsed['hopCount'] as int;

    if (hopCount >= ttl) return false;

    final senderId = parsed['senderId'] as String;
    _updatePeer(senderId);

    _dataController.add(rawData);
    return true;
  }

  Future<void> relayPacket(Uint8List packet) async {
    final parsed = MeshProtocol.parsePacket(packet);
    if (!parsed['valid']) return;

    final ttl = parsed['ttl'] as int;
    final hopCount = parsed['hopCount'] as int;

    if (hopCount >= ttl) return;

    final relayPacket = MeshProtocol.createPacket(
      type: MeshProtocol.PACKET_TYPE_RELAY,
      senderId: _identity!.peerId,
      recipientId: parsed['recipientId'],
      payload: parsed['payload'],
      ttl: ttl,
      messageId: parsed['messageId'],
      hopCount: hopCount + 1,
    );

    _dataController.add(relayPacket);
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
