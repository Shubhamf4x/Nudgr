import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_identity.dart';
import '../models/chat_message.dart';
import '../models/chat_peer.dart';
import '../models/chat_channel.dart';
import 'ble_mesh_service.dart';
import 'mesh_protocol.dart';

class MeshChatService {
  ChatIdentity? _identity;
  final BleMeshService _meshService = BleMeshService();
  final Map<String, List<ChatMessage>> _channelMessages = {};
  final Map<String, List<ChatMessage>> _privateMessages = {};
  final List<ChatChannel> _channels = [];
  final Set<String> _seenMessageIds = {};
  final List<String> _seenMessageIdOrder = [];
  static const int _maxSeenMessageIds = 1000;
  static const int _maxMessagesPerConversation = 200;
  final StreamController<ChatMessage> _messageController =
      StreamController<ChatMessage>.broadcast();
  final StreamController<List<ChatPeer>> _peersController =
      StreamController<List<ChatPeer>>.broadcast();
  final StreamController<MeshStatus> _statusController =
      StreamController<MeshStatus>.broadcast();
  MeshStatus _meshStatus = MeshStatus.inactive;
  Timer? _peersUpdateTimer;
  StreamSubscription? _peerSub;
  StreamSubscription? _dataSub;
  StreamSubscription? _scanStateSub;
  StreamSubscription? _bluetoothStateSub;
  ChatIdentity? get identity => _identity;
  BleMeshService get meshService => _meshService;
  Stream<ChatMessage> get messageStream => _messageController.stream;
  Stream<List<ChatPeer>> get peersStream => _peersController.stream;
  Stream<MeshStatus> get statusStream => _statusController.stream;
  MeshStatus get meshStatus => _meshStatus;
  List<ChatChannel> get channels => List.unmodifiable(_channels);
  Map<String, List<ChatMessage>> get channelMessages =>
      Map.unmodifiable(_channelMessages);
  Map<String, List<ChatMessage>> get privateMessages =>
      Map.unmodifiable(_privateMessages);
  List<ChatPeer> get nearbyPeers => _meshService.peers.values.toList();
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
    final identityJson = prefs.getString('nudgr_chat_identity');
    if (identityJson != null) {
      try {
        final decoded = jsonDecode(identityJson);
        if (decoded is Map) {
          _identity = ChatIdentity.fromJson(Map<String, dynamic>.from(decoded));
        }
      } catch (e) {
        debugPrint('[MeshChat] Unreadable stored identity, regenerating: $e');
      }
    }
    _identity ??= ChatIdentity.generate();
    await prefs.setString(
      'nudgr_chat_identity',
      jsonEncode(_identity!.toJson()),
    );
  }

  Future<void> _loadChannels() async {
    final prefs = await SharedPreferences.getInstance();
    final channelsJson = prefs.getString('nudgr_chat_channels');
    if (channelsJson != null) {
      try {
        final decoded = jsonDecode(channelsJson);
        if (decoded is List) {
          for (final entry in decoded) {
            if (entry is! Map) continue;
            try {
              _channels.add(
                ChatChannel.fromJson(Map<String, dynamic>.from(entry)),
              );
            } catch (_) {}
          }
        }
      } catch (e) {
        debugPrint('[MeshChat] Unreadable stored channels: $e');
      }
    }
    if (_channels.isEmpty) {
      _channels.add(
        ChatChannel(
          name: 'nearby',
          displayName: 'Nearby',
          createdAt: DateTime.now(),
          isJoined: true,
          description: 'Public channel for nearby peers',
        ),
      );
      _channels.add(
        ChatChannel(
          name: 'local',
          displayName: 'Local',
          createdAt: DateTime.now(),
          isJoined: true,
          description: 'Local mesh channel',
        ),
      );
      _channels.add(
        ChatChannel(
          name: 'mesh',
          displayName: 'Mesh',
          createdAt: DateTime.now(),
          isJoined: true,
          description: 'General mesh channel',
        ),
      );
      await _saveChannels();
    }
  }

  Future<void> _saveChannels() async {
    final prefs = await SharedPreferences.getInstance();
    final json = _channels.map((c) => c.toJson()).toList();
    await prefs.setString('nudgr_chat_channels', jsonEncode(json));
  }

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    _loadMessageMap(
      prefs.getString('nudgr_chat_channel_messages'),
      _channelMessages,
    );
    _loadMessageMap(
      prefs.getString('nudgr_chat_private_messages'),
      _privateMessages,
    );
  }

  void _loadMessageMap(String? raw, Map<String, List<ChatMessage>> target) {
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      for (final entry in decoded.entries) {
        if (entry.key is! String || entry.value is! List) continue;
        final messages = <ChatMessage>[];
        for (final item in entry.value as List) {
          if (item is! Map) continue;
          try {
            messages.add(ChatMessage.fromJson(Map<String, dynamic>.from(item)));
          } catch (_) {}
        }
        _trimHistory(messages);
        target[entry.key as String] = messages;
      }
    } catch (e) {
      debugPrint('[MeshChat] Unreadable stored messages, starting empty: $e');
    }
  }

  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final channelMap = <String, dynamic>{};
    for (final entry in _channelMessages.entries) {
      channelMap[entry.key] = entry.value.map((m) => m.toJson()).toList();
    }
    await prefs.setString(
      'nudgr_chat_channel_messages',
      jsonEncode(channelMap),
    );
    final privateMap = <String, dynamic>{};
    for (final entry in _privateMessages.entries) {
      privateMap[entry.key] = entry.value.map((m) => m.toJson()).toList();
    }
    await prefs.setString(
      'nudgr_chat_private_messages',
      jsonEncode(privateMap),
    );
  }

  void _setupListeners() {
    _cancelListeners();
    _peerSub = _meshService.peerStream.listen((peer) {
      _peersController.add(_meshService.peers.values.toList());
    });
    _dataSub = _meshService.dataStream.listen((data) {
      _handleIncomingData(data);
    });
    _scanStateSub = _meshService.scanStateStream.listen((scanning) {
      if (!_meshService.isBluetoothOn) {
        _meshStatus = MeshStatus.offline;
      } else {
        _meshStatus = scanning ? MeshStatus.scanning : MeshStatus.active;
      }
      _statusController.add(_meshStatus);
    });
    _bluetoothStateSub = _meshService.bluetoothStateStream.listen((isOn) {
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

  void _cancelListeners() {
    _peerSub?.cancel();
    _dataSub?.cancel();
    _scanStateSub?.cancel();
    _bluetoothStateSub?.cancel();
    _peerSub = null;
    _dataSub = null;
    _scanStateSub = null;
    _bluetoothStateSub = null;
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
    final parsed = MeshProtocol.parsePacket(data);
    if (parsed == null) return;
    final type = parsed['type'] as int;
    final senderId = parsed['senderId'] as String;
    final messageId = parsed['messageId'] as String;
    final identity = _identity;
    if (identity == null) return;
    final ttl = parsed['ttl'] as int;
    final hopCount = parsed['hopCount'] as int;
    if (senderId == MeshProtocol.normalizePeerId(identity.peerId)) return;
    if (!_admitMessage(messageId, hopCount, ttl)) return;
    final recipientId = parsed['recipientId'] as String?;
    final payload = parsed['payload'] as Uint8List;
    switch (type) {
      case MeshProtocol.PACKET_TYPE_DISCOVERY:
        _handleDiscovery(senderId, payload);
        break;
      case MeshProtocol.PACKET_TYPE_CHANNEL:
        _handleChannelMessage(senderId, messageId, payload);
        break;
      case MeshProtocol.PACKET_TYPE_MESSAGE:
      case MeshProtocol.PACKET_TYPE_RELAY:
      case MeshProtocol.PACKET_TYPE_PRIVATE:
        if (type == MeshProtocol.PACKET_TYPE_RELAY) {
          unawaited(_meshService.relayPacket(data));
        }
        if (recipientId == null) {
          _handleChannelMessage(senderId, messageId, payload);
        } else {
          _handlePrivateMessage(senderId, messageId, recipientId, payload);
        }
        break;
    }
  }

  bool _admitMessage(String messageId, int hopCount, int ttl) {
    if (_seenMessageIds.contains(messageId)) return false;
    if (ttl <= 0 || hopCount >= ttl) return false;
    _seenMessageIds.add(messageId);
    _seenMessageIdOrder.add(messageId);
    while (_seenMessageIdOrder.length > _maxSeenMessageIds) {
      _seenMessageIds.remove(_seenMessageIdOrder.removeAt(0));
    }
    return true;
  }

  void _handleDiscovery(String senderId, Uint8List payload) {
    final info = MeshProtocol.parseDiscoveryPayload(payload);
    if (info == null || info.peerId.isEmpty) return;
    _meshService.registerPeer(
      MeshProtocol.normalizePeerId(info.peerId),
      nickname: info.nickname,
    );
  }

  void _handleChannelMessage(
    String senderId,
    String messageId,
    Uint8List payload,
  ) {
    final decoded = MeshProtocol.parseChannelMessagePayload(payload);
    if (decoded == null) return;
    final channelName = decoded.channelName;
    if (!_isKnownChannel(channelName)) return;
    _appendChannelMessage(
      channelName,
      ChatMessage(
        id: messageId,
        senderPeerId: senderId,
        senderNickname: _meshService.peers[senderId]?.nickname,
        content: decoded.content,
        timestamp: DateTime.now(),
        type: ChatMessageType.publicChannel,
        channelName: channelName,
      ),
    );
  }

  void _handlePrivateMessage(
    String senderId,
    String messageId,
    String recipientId,
    Uint8List payload,
  ) {
    if (recipientId != MeshProtocol.normalizePeerId(_identity!.peerId)) return;
    final content = MeshProtocol.parseMessagePayload(payload);
    if (content.isEmpty) return;
    final message = ChatMessage(
      id: messageId,
      senderPeerId: senderId,
      senderNickname: _meshService.peers[senderId]?.nickname,
      recipientPeerId: _identity!.peerId,
      content: content,
      timestamp: DateTime.now(),
      type: ChatMessageType.privateMessage,
    );
    final messages = _privateMessages.putIfAbsent(senderId, () => []);
    messages.add(message);
    _trimHistory(messages);
    _messageController.add(message);
    unawaited(_saveMessages());
  }

  bool _isKnownChannel(String channelName) =>
      _channels.any((c) => c.name == channelName && c.isJoined);
  void _appendChannelMessage(String channelName, ChatMessage message) {
    final messages = _channelMessages.putIfAbsent(channelName, () => []);
    messages.add(message);
    _trimHistory(messages);
    _messageController.add(message);
    unawaited(_saveMessages());
  }

  void _trimHistory(List<ChatMessage> messages) {
    if (messages.length <= _maxMessagesPerConversation) return;
    messages.removeRange(0, messages.length - _maxMessagesPerConversation);
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

  Future<void> sendMessage(
    String content, {
    String channelName = 'nearby',
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;
    final payload = MeshProtocol.createChannelMessagePayload(
      channelName,
      trimmed,
    );
    final message = ChatMessage(
      id: MeshProtocol.generateMessageId(),
      senderPeerId: _identity!.peerId,
      senderNickname: _identity!.nickname,
      content: trimmed,
      timestamp: DateTime.now(),
      type: ChatMessageType.publicChannel,
      channelName: channelName,
      deliveryState: MessageDeliveryState.sending,
    );
    _appendChannelMessage(channelName, message);
    await _meshService.sendData(payload);
    _updateMessageDeliveryState(message.id, MessageDeliveryState.sent);
    await _saveMessages();
  }

  Future<void> sendPrivateMessage(
    String content,
    String recipientPeerId,
  ) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;
    final payload = MeshProtocol.createMessagePayload(trimmed);
    final message = ChatMessage(
      id: MeshProtocol.generateMessageId(),
      senderPeerId: _identity!.peerId,
      senderNickname: _identity!.nickname,
      recipientPeerId: recipientPeerId,
      content: trimmed,
      timestamp: DateTime.now(),
      type: ChatMessageType.privateMessage,
      deliveryState: MessageDeliveryState.sending,
    );
    final messages = _privateMessages.putIfAbsent(recipientPeerId, () => []);
    messages.add(message);
    _trimHistory(messages);
    _messageController.add(message);
    await _meshService.sendData(payload, targetPeerId: recipientPeerId);
    _updateMessageDeliveryState(message.id, MessageDeliveryState.sent);
    await _saveMessages();
  }

  void _updateMessageDeliveryState(
    String messageId,
    MessageDeliveryState state,
  ) {
    for (final messages in [
      ..._channelMessages.values,
      ..._privateMessages.values,
    ]) {
      for (var i = 0; i < messages.length; i++) {
        if (messages[i].id == messageId) {
          messages[i] = messages[i].copyWith(deliveryState: state);
          return;
        }
      }
    }
  }

  Future<void> joinChannel(String channelName) async {
    final existing = _channels.where((c) => c.name == channelName).toList();
    if (existing.isEmpty) {
      _channels.add(
        ChatChannel(
          name: channelName,
          displayName: channelName,
          createdAt: DateTime.now(),
          isJoined: true,
        ),
      );
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

  List<ChatMessage> getChannelMessages(String channelName) {
    return _channelMessages[channelName] ?? [];
  }

  List<ChatMessage> getPrivateMessages(String peerId) {
    return _privateMessages[peerId] ?? [];
  }

  Future<void> emergencyWipe() async {
    _channelMessages.clear();
    _privateMessages.clear();
    _channels.clear();
    _seenMessageIds.clear();
    _seenMessageIdOrder.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('nudgr_chat_identity');
    await prefs.remove('nudgr_chat_channels');
    await prefs.remove('nudgr_chat_channel_messages');
    await prefs.remove('nudgr_chat_private_messages');
    _identity = ChatIdentity.generate();
    await prefs.setString(
      'nudgr_chat_identity',
      jsonEncode(_identity!.toJson()),
    );
    _meshService.forgetPeers();
    await _meshService.initialize(_identity!);
    await _loadChannels();
    _meshStatus = MeshStatus.inactive;
    _statusController.add(_meshStatus);
  }

  void dispose() {
    _cancelListeners();
    _peersUpdateTimer?.cancel();
    _peersUpdateTimer = null;
    _meshService.dispose();
    _messageController.close();
    _peersController.close();
    _statusController.close();
  }
}

enum MeshStatus { inactive, scanning, active, permissionDenied, offline }
