import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bit_chat_identity.dart';
import '../models/bit_chat_message.dart';
import '../models/bit_chat_peer.dart';
import '../models/bit_chat_channel.dart';
import 'ble_mesh_service.dart';
import 'bit_chat_protocol.dart';

class BitChatService {
  BitChatIdentity? _identity;
  final BleMeshService _meshService = BleMeshService();
  final Map<String, List<BitChatMessage>> _channelMessages = {};
  final Map<String, List<BitChatMessage>> _privateMessages = {};
  final List<BitChatChannel> _channels = [];
  final Map<String, Uint8List> _sharedSecrets = {};

  final StreamController<BitChatMessage> _messageController = StreamController<BitChatMessage>.broadcast();
  final StreamController<List<BitChatPeer>> _peersController = StreamController<List<BitChatPeer>>.broadcast();
  final StreamController<MeshStatus> _statusController = StreamController<MeshStatus>.broadcast();

  MeshStatus _meshStatus = MeshStatus.inactive;
  Timer? _peersUpdateTimer;

  BitChatIdentity? get identity => _identity;
  BleMeshService get meshService => _meshService;
  Stream<BitChatMessage> get messageStream => _messageController.stream;
  Stream<List<BitChatPeer>> get peersStream => _peersController.stream;
  Stream<MeshStatus> get statusStream => _statusController.stream;
  MeshStatus get meshStatus => _meshStatus;
  List<BitChatChannel> get channels => List.unmodifiable(_channels);
  Map<String, List<BitChatMessage>> get channelMessages => Map.unmodifiable(_channelMessages);
  Map<String, List<BitChatMessage>> get privateMessages => Map.unmodifiable(_privateMessages);

  List<BitChatPeer> get nearbyPeers => _meshService.peers.values.toList();

  Future<void> initialize() async {
    await _loadIdentity();
    if (_identity != null) {
      await _meshService.initialize(_identity!);
      _setupListeners();
      await _loadChannels();
      await _loadMessages();
    }
  }

  Future<void> _loadIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    final identityJson = prefs.getString('bitchat_identity');
    if (identityJson != null) {
      _identity = BitChatIdentity.fromJson(jsonDecode(identityJson));
    } else {
      _identity = BitChatIdentity.generate();
      await prefs.setString('bitchat_identity', jsonEncode(_identity!.toJson()));
    }
  }

  Future<void> _loadChannels() async {
    final prefs = await SharedPreferences.getInstance();
    final channelsJson = prefs.getString('bitchat_channels');
    if (channelsJson != null) {
      final list = jsonDecode(channelsJson) as List;
      _channels.addAll(list.map((c) => BitChatChannel.fromJson(c)));
    }

    if (_channels.isEmpty) {
      _channels.add(BitChatChannel(
        name: 'nearby',
        displayName: 'Nearby',
        createdAt: DateTime.now(),
        isJoined: true,
        description: 'Public channel for nearby peers',
      ));
      _channels.add(BitChatChannel(
        name: 'local',
        displayName: 'Local',
        createdAt: DateTime.now(),
        isJoined: true,
        description: 'Local mesh channel',
      ));
      _channels.add(BitChatChannel(
        name: 'mesh',
        displayName: 'Mesh',
        createdAt: DateTime.now(),
        isJoined: true,
        description: 'General mesh channel',
      ));
      await _saveChannels();
    }
  }

  Future<void> _saveChannels() async {
    final prefs = await SharedPreferences.getInstance();
    final json = _channels.map((c) => c.toJson()).toList();
    await prefs.setString('bitchat_channels', jsonEncode(json));
  }

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final channelMsgsJson = prefs.getString('bitchat_channel_messages');
    if (channelMsgsJson != null) {
      final map = jsonDecode(channelMsgsJson) as Map<String, dynamic>;
      for (final entry in map.entries) {
        final msgs = (entry.value as List).map((m) => BitChatMessage.fromJson(m)).toList();
        _channelMessages[entry.key] = msgs;
      }
    }
    final privateMsgsJson = prefs.getString('bitchat_private_messages');
    if (privateMsgsJson != null) {
      final map = jsonDecode(privateMsgsJson) as Map<String, dynamic>;
      for (final entry in map.entries) {
        final msgs = (entry.value as List).map((m) => BitChatMessage.fromJson(m)).toList();
        _privateMessages[entry.key] = msgs;
      }
    }
  }

  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final channelMap = <String, dynamic>{};
    for (final entry in _channelMessages.entries) {
      channelMap[entry.key] = entry.value.map((m) => m.toJson()).toList();
    }
    await prefs.setString('bitchat_channel_messages', jsonEncode(channelMap));

    final privateMap = <String, dynamic>{};
    for (final entry in _privateMessages.entries) {
      privateMap[entry.key] = entry.value.map((m) => m.toJson()).toList();
    }
    await prefs.setString('bitchat_private_messages', jsonEncode(privateMap));
  }

  void _setupListeners() {
    _meshService.peerStream.listen((peer) {
      _peersController.add(_meshService.peers.values.toList());
    });

    _meshService.dataStream.listen((data) {
      _handleIncomingData(data);
    });

    _meshService.scanStateStream.listen((scanning) {
      if (!_meshService.isBluetoothOn) {
        _meshStatus = MeshStatus.offline;
      } else {
        _meshStatus = scanning ? MeshStatus.scanning : MeshStatus.active;
      }
      _statusController.add(_meshStatus);
    });

    _meshService.bluetoothStateStream.listen((isOn) {
      if (!isOn) {
        _meshStatus = MeshStatus.offline;
        _statusController.add(_meshStatus);
      } else if (_meshStatus == MeshStatus.offline) {
        _meshStatus = MeshStatus.inactive;
        _statusController.add(_meshStatus);
      }
    });

    _peersUpdateTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _peersController.add(_meshService.peers.values.toList());
      _updateMeshStatus();
    });
  }

  void _updateMeshStatus() {
    if (!_meshService.isBluetoothOn) {
      _meshStatus = MeshStatus.offline;
    } else {
      final peerCount = _meshService.peers.length;
      if (peerCount > 0) {
        _meshStatus = MeshStatus.active;
      } else if (_meshService.isScanning) {
        _meshStatus = MeshStatus.scanning;
      } else {
        _meshStatus = MeshStatus.inactive;
      }
    }
    _statusController.add(_meshStatus);
  }

  void _handleIncomingData(Uint8List data) {
    final parsed = BitChatProtocol.parsePacket(data);
    if (!parsed['valid']) return;

    final type = parsed['type'] as int;
    final senderId = parsed['senderId'] as String;
    final recipientId = parsed['recipientId'] as String?;
    final payload = parsed['payload'] as Uint8List;

    switch (type) {
      case BitChatProtocol.PACKET_TYPE_DISCOVERY:
        _handleDiscovery(senderId, payload);
        break;
      case BitChatProtocol.PACKET_TYPE_MESSAGE:
      case BitChatProtocol.PACKET_TYPE_CHANNEL:
        _handleMessage(senderId, recipientId, payload);
        break;
      case BitChatProtocol.PACKET_TYPE_PRIVATE:
        _handlePrivateMessage(senderId, payload);
        break;
      case BitChatProtocol.PACKET_TYPE_RELAY:
        _meshService.relayPacket(data);
        break;
    }
  }

  void _handleDiscovery(String senderId, Uint8List payload) {
    final info = BitChatProtocol.parseDiscoveryPayload(payload);
    final peerId = info['peerId'];
    if (peerId != null && peerId.isNotEmpty) {
      _meshService.processIncomingData(
        BitChatProtocol.createPacket(
          type: BitChatProtocol.PACKET_TYPE_DISCOVERY_RESPONSE,
          senderId: _identity!.peerId,
          payload: BitChatProtocol.createDiscoveryPayload(_identity!.peerId, _identity!.nickname),
        ),
        senderId,
      );
    }
  }

  void _handleMessage(String senderId, String? recipientId, Uint8List payload) {
    final content = BitChatProtocol.parseMessagePayload(payload);
    if (content.isEmpty) return;

    final channelName = recipientId ?? 'nearby';
    final message = BitChatMessage(
      id: BitChatProtocol.generateMessageId(),
      senderPeerId: senderId,
      senderNickname: _meshService.peers[senderId]?.nickname,
      content: content,
      timestamp: DateTime.now(),
      type: BitChatMessageType.publicChannel,
      channelName: channelName,
    );

    if (!_channelMessages.containsKey(channelName)) {
      _channelMessages[channelName] = [];
    }
    _channelMessages[channelName]!.add(message);
    _messageController.add(message);
    _saveMessages();
  }

  void _handlePrivateMessage(String senderId, Uint8List payload) {
    final content = BitChatProtocol.parseMessagePayload(payload);
    if (content.isEmpty) return;

    final message = BitChatMessage(
      id: BitChatProtocol.generateMessageId(),
      senderPeerId: senderId,
      senderNickname: _meshService.peers[senderId]?.nickname,
      recipientPeerId: _identity!.peerId,
      content: content,
      timestamp: DateTime.now(),
      type: BitChatMessageType.privateMessage,
    );

    if (!_privateMessages.containsKey(senderId)) {
      _privateMessages[senderId] = [];
    }
    _privateMessages[senderId]!.add(message);
    _messageController.add(message);
    _saveMessages();
  }

  Future<void> startMesh() async {
    if (!_meshService.isBluetoothOn) {
      _meshStatus = MeshStatus.offline;
      _statusController.add(_meshStatus);
      return;
    }

    final granted = await _meshService.requestPermissions();
    if (!granted) {
      _meshStatus = MeshStatus.permissionDenied;
      _statusController.add(_meshStatus);
      return;
    }
    await _meshService.startScanning();
    await _meshService.startAdvertising();
    _meshStatus = MeshStatus.scanning;
    _statusController.add(_meshStatus);
  }

  Future<void> stopMesh() async {
    await _meshService.stopScanning();
    await _meshService.stopAdvertising();
    _meshStatus = MeshStatus.inactive;
    _statusController.add(_meshStatus);
  }

  Future<void> sendMessage(String content, {String channelName = 'nearby'}) async {
    final payload = BitChatProtocol.createMessagePayload(content);
    final message = BitChatMessage(
      id: BitChatProtocol.generateMessageId(),
      senderPeerId: _identity!.peerId,
      senderNickname: _identity!.nickname,
      content: content,
      timestamp: DateTime.now(),
      type: BitChatMessageType.publicChannel,
      channelName: channelName,
      deliveryState: MessageDeliveryState.sending,
    );

    if (!_channelMessages.containsKey(channelName)) {
      _channelMessages[channelName] = [];
    }
    _channelMessages[channelName]!.add(message);
    _messageController.add(message);

    await _meshService.sendData(payload);
    _updateMessageDeliveryState(message.id, MessageDeliveryState.sent);
    _saveMessages();
  }

  Future<void> sendPrivateMessage(String content, String recipientPeerId) async {
    final payload = BitChatProtocol.createMessagePayload(content);
    final message = BitChatMessage(
      id: BitChatProtocol.generateMessageId(),
      senderPeerId: _identity!.peerId,
      senderNickname: _identity!.nickname,
      recipientPeerId: recipientPeerId,
      content: content,
      timestamp: DateTime.now(),
      type: BitChatMessageType.privateMessage,
      deliveryState: MessageDeliveryState.sending,
    );

    if (!_privateMessages.containsKey(recipientPeerId)) {
      _privateMessages[recipientPeerId] = [];
    }
    _privateMessages[recipientPeerId]!.add(message);
    _messageController.add(message);

    await _meshService.sendData(payload, targetPeerId: recipientPeerId);
    _updateMessageDeliveryState(message.id, MessageDeliveryState.sent);
    _saveMessages();
  }

  void _updateMessageDeliveryState(String messageId, MessageDeliveryState state) {
    for (final messages in _channelMessages.values) {
      for (var i = 0; i < messages.length; i++) {
        if (messages[i].id == messageId) {
          messages[i] = messages[i].copyWith(deliveryState: state);
        }
      }
    }
    for (final messages in _privateMessages.values) {
      for (var i = 0; i < messages.length; i++) {
        if (messages[i].id == messageId) {
          messages[i] = messages[i].copyWith(deliveryState: state);
        }
      }
    }
  }

  Future<void> joinChannel(String channelName) async {
    final existing = _channels.where((c) => c.name == channelName).toList();
    if (existing.isEmpty) {
      _channels.add(BitChatChannel(
        name: channelName,
        displayName: channelName,
        createdAt: DateTime.now(),
        isJoined: true,
      ));
    } else {
      final idx = _channels.indexOf(existing.first);
      _channels[idx] = existing.first.copyWith(isJoined: true);
    }
    await _saveChannels();
  }

  Future<void> leaveChannel(String channelName) async {
    final idx = _channels.indexWhere((c) => c.name == channelName);
    if (idx >= 0) {
      _channels[idx] = _channels[idx].copyWith(isJoined: false);
      await _saveChannels();
    }
  }

  List<BitChatMessage> getChannelMessages(String channelName) {
    return _channelMessages[channelName] ?? [];
  }

  List<BitChatMessage> getPrivateMessages(String peerId) {
    return _privateMessages[peerId] ?? [];
  }

  Future<void> emergencyWipe() async {
    _channelMessages.clear();
    _privateMessages.clear();
    _channels.clear();
    _sharedSecrets.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('bitchat_identity');
    await prefs.remove('bitchat_channels');
    await prefs.remove('bitchat_channel_messages');
    await prefs.remove('bitchat_private_messages');
    _identity = BitChatIdentity.generate();
    await prefs.setString('bitchat_identity', jsonEncode(_identity!.toJson()));
  }

  void dispose() {
    _peersUpdateTimer?.cancel();
    _meshService.dispose();
    _messageController.close();
    _peersController.close();
    _statusController.close();
  }
}

enum MeshStatus {
  inactive,
  scanning,
  active,
  permissionDenied,
  offline,
}
