import 'dart:async';
import 'package:flutter/material.dart';
import '../models/bit_chat_message.dart';
import '../models/bit_chat_peer.dart';
import '../models/bit_chat_channel.dart';
import '../services/bit_chat_service.dart';

class BitChatState {
  final List<BitChatPeer> peers;
  final List<BitChatChannel> channels;
  final Map<String, List<BitChatMessage>> channelMessages;
  final Map<String, List<BitChatMessage>> privateMessages;
  final MeshStatus meshStatus;
  final bool isInitializing;
  final String? error;
  final String selectedChannel;
  final String? activePrivateChatPeerId;
  final bool permissionsGranted;

  const BitChatState({
    this.peers = const [],
    this.channels = const [],
    this.channelMessages = const {},
    this.privateMessages = const {},
    this.meshStatus = MeshStatus.inactive,
    this.isInitializing = true,
    this.error,
    this.selectedChannel = 'nearby',
    this.activePrivateChatPeerId,
    this.permissionsGranted = false,
  });

  BitChatState copyWith({
    List<BitChatPeer>? peers,
    List<BitChatChannel>? channels,
    Map<String, List<BitChatMessage>>? channelMessages,
    Map<String, List<BitChatMessage>>? privateMessages,
    MeshStatus? meshStatus,
    bool? isInitializing,
    String? error,
    String? selectedChannel,
    String? activePrivateChatPeerId,
    bool? permissionsGranted,
  }) {
    return BitChatState(
      peers: peers ?? this.peers,
      channels: channels ?? this.channels,
      channelMessages: channelMessages ?? this.channelMessages,
      privateMessages: privateMessages ?? this.privateMessages,
      meshStatus: meshStatus ?? this.meshStatus,
      isInitializing: isInitializing ?? this.isInitializing,
      error: error,
      selectedChannel: selectedChannel ?? this.selectedChannel,
      activePrivateChatPeerId: activePrivateChatPeerId,
      permissionsGranted: permissionsGranted ?? this.permissionsGranted,
    );
  }
}

class BitChatProvider extends ChangeNotifier {
  final BitChatService _service = BitChatService();
  BitChatState _state = const BitChatState();
  StreamSubscription? _messageSub;
  StreamSubscription? _peersSub;
  StreamSubscription? _statusSub;

  BitChatState get state => _state;
  BitChatService get service => _service;

  @override
  void dispose() {
    _messageSub?.cancel();
    _peersSub?.cancel();
    _statusSub?.cancel();
    _service.dispose();
    super.dispose();
  }

  Future<void> initialize() async {
    _state = _state.copyWith(isInitializing: true);
    notifyListeners();

    await _service.initialize();

    final granted = await _service.meshService.requestPermissions();

    _messageSub = _service.messageStream.listen((message) {
      _refreshState();
    });

    _peersSub = _service.peersStream.listen((peers) {
      _state = _state.copyWith(peers: peers);
      notifyListeners();
    });

    _statusSub = _service.statusStream.listen((status) {
      _state = _state.copyWith(meshStatus: status);
      notifyListeners();
    });

    _state = _state.copyWith(
      isInitializing: false,
      peers: _service.nearbyPeers,
      channels: _service.channels,
      permissionsGranted: granted,
    );
    notifyListeners();

    if (granted) {
      await startMesh();
    }
  }

  Future<void> startMesh() async {
    await _service.startMesh();
    _refreshState();
  }

  Future<void> stopMesh() async {
    await _service.stopMesh();
    _refreshState();
  }

  Future<void> requestPermissions() async {
    final granted = await _service.meshService.requestPermissions();
    _state = _state.copyWith(permissionsGranted: granted);
    notifyListeners();
    if (granted) {
      await startMesh();
    }
  }

  void selectChannel(String channelName) {
    _state = _state.copyWith(
      selectedChannel: channelName,
      activePrivateChatPeerId: null,
    );
    notifyListeners();
  }

  void openPrivateChat(String peerId) {
    _state = _state.copyWith(activePrivateChatPeerId: peerId);
    notifyListeners();
  }

  void closePrivateChat() {
    _state = _state.copyWith(activePrivateChatPeerId: null);
    notifyListeners();
  }

  Future<void> sendMessage(String content) async {
    await _service.sendMessage(content, channelName: _state.selectedChannel);
    _refreshState();
  }

  Future<void> sendPrivateMessage(String content, String recipientPeerId) async {
    await _service.sendPrivateMessage(content, recipientPeerId);
    _refreshState();
  }

  Future<void> joinChannel(String channelName) async {
    await _service.joinChannel(channelName);
    _state = _state.copyWith(channels: _service.channels);
    notifyListeners();
  }

  Future<void> leaveChannel(String channelName) async {
    await _service.leaveChannel(channelName);
    _state = _state.copyWith(channels: _service.channels);
    notifyListeners();
  }

  Future<void> emergencyWipe() async {
    await _service.emergencyWipe();
    _state = const BitChatState();
    notifyListeners();
    await initialize();
  }

  List<BitChatMessage> get currentMessages {
    if (_state.activePrivateChatPeerId != null) {
      return _service.getPrivateMessages(_state.activePrivateChatPeerId!);
    }
    return _service.getChannelMessages(_state.selectedChannel);
  }

  BitChatPeer? getPeer(String peerId) {
    final matches = _state.peers.where((p) => p.peerId == peerId);
    return matches.isNotEmpty ? matches.first : null;
  }

  void _refreshState() {
    _state = _state.copyWith(
      peers: _service.nearbyPeers,
      channels: _service.channels,
      meshStatus: _service.meshStatus,
    );
    notifyListeners();
  }
}
