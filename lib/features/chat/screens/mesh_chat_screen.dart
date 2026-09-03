import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/color_constants.dart';
import '../models/chat_peer.dart';
import '../providers/mesh_chat_provider.dart';
import '../services/mesh_chat_service.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_composer.dart';
import '../widgets/peer_tile.dart';
import '../widgets/mesh_status_indicator.dart';

class MeshChatScreen extends StatefulWidget {
  const MeshChatScreen({super.key});

  @override
  State<MeshChatScreen> createState() => _MeshChatScreenState();
}

class _MeshChatScreenState extends State<MeshChatScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MeshChatProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Selector<MeshChatProvider, ({bool isInitializing, bool permissionsGranted, dynamic meshStatus})>(
      selector: (_, p) => (isInitializing: p.state.isInitializing, permissionsGranted: p.state.permissionsGranted, meshStatus: p.state.meshStatus),
      builder: (context, data, _) {
        final provider = context.read<MeshChatProvider>();

        if (data.isInitializing) {
          return _buildLoadingScreen(theme);
        }

        if (!data.permissionsGranted || data.meshStatus == MeshStatus.offline) {
          return _buildPermissionScreen(provider, theme);
        }

        return _buildMainContent(provider, isDark);
      },
    );
  }

  Widget _buildLoadingScreen(ThemeData theme) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: ColorConstants.primary),
            const SizedBox(height: 16),
            Text(
              'Initializing Chat...',
              style: AppTextStyles.googleSans(
                fontSize: 16,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionScreen(MeshChatProvider provider, ThemeData theme) {
    final isOffline = provider.state.meshStatus == MeshStatus.offline;
    final buttonText = isOffline ? 'Turn On Bluetooth' : 'Allow Bluetooth';
    final descriptionText = isOffline
        ? 'Bluetooth is turned off. Please enable Bluetooth to discover nearby Chat devices and communicate through the local mesh.'
        : 'Nudgr needs Bluetooth access to discover nearby Chat devices and communicate through the local mesh.';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: ColorConstants.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isOffline ? Icons.bluetooth_disabled_rounded : Icons.bluetooth_rounded,
                    size: 40,
                    color: ColorConstants.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  isOffline ? 'Bluetooth Off' : 'Bluetooth Access',
                  style: AppTextStyles.googleSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  descriptionText,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.googleSans(
                    fontSize: 15,
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => provider.requestPermissions(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorConstants.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      buttonText,
                      style: AppTextStyles.googleSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(MeshChatProvider provider, bool isDark) {
    final peerCount = provider.state.peers.length;
    final isActive = provider.state.meshStatus == MeshStatus.active ||
        provider.state.meshStatus == MeshStatus.scanning;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(provider, peerCount, isActive, isDark),
            _buildTabBar(provider, isDark),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildChatTab(provider, isDark),
                  _buildPeersTab(provider, isDark),
                ],
              ),
            ),
            if (_state.activePrivateChatPeerId == null)
              ChatComposer(
                onSend: (text) => provider.sendMessage(text),
              ),
          ],
        ),
      ),
    );
  }

  MeshChatState get _state => context.read<MeshChatProvider>().state;

  Widget _buildHeader(MeshChatProvider provider, int peerCount, bool isDark, bool isActive) {
    return Selector<MeshChatProvider, ({dynamic meshStatus, int peerCount})>(
      selector: (_, p) => (meshStatus: p.state.meshStatus, peerCount: p.state.peers.length),
      builder: (context, data, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Chat',
                    style: AppTextStyles.googleSans(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  MeshStatusIndicator(
                    status: data.meshStatus,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              MeshStatusText(
                status: data.meshStatus,
                peerCount: data.peerCount,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabBar(MeshChatProvider provider, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: ColorConstants.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
        labelStyle: AppTextStyles.googleSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: AppTextStyles.googleSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        dividerColor: Colors.transparent,
        splashBorderRadius: BorderRadius.circular(10),
        tabs: const [
          Tab(text: 'Nearby'),
          Tab(text: 'Peers'),
        ],
      ),
    );
  }

  Widget _buildChatTab(MeshChatProvider provider, bool isDark) {
    if (provider.state.activePrivateChatPeerId != null) {
      return _buildPrivateChatTab(provider, isDark);
    }

    return Selector<MeshChatProvider, int>(
      selector: (_, p) =>
          p.currentMessages.length * 31 + p.state.selectedChannel.hashCode,
      shouldRebuild: (previous, next) => previous != next,
      builder: (context, messageCount, _) {
        final channelMessages = provider.currentMessages;
        return Column(
          children: [
            _buildChannelChips(provider, isDark),
            Expanded(
              child: channelMessages.isEmpty
                  ? _buildEmptyState(isDark)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: channelMessages.length,
                      itemBuilder: (context, index) {
                        final msg = channelMessages[index];
                        final myId = provider.service.identity?.peerId ?? '';
                        final isMine = msg.senderPeerId == myId;
                        return MessageBubble(
                          message: msg,
                          isMine: isMine,
                          peerNickname: provider.getPeer(msg.senderPeerId)?.nickname,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPrivateChatTab(MeshChatProvider provider, bool isDark) {
    final peerId = provider.state.activePrivateChatPeerId!;
    final peer = provider.getPeer(peerId);

    return Selector<MeshChatProvider, int>(
      selector: (_, p) => p.getPrivateMessages(peerId).length,
      shouldRebuild: (previous, next) => previous != next,
      builder: (context, messageCount, _) {
        final messages = provider.getPrivateMessages(peerId);
        return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerTheme.color ?? Colors.grey.shade200,
              ),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: () => provider.closePrivateChat(),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 16,
                backgroundColor: ColorConstants.primary.withValues(alpha: 0.1),
                child: Text(
                  (peer?.nickname ?? peerId).substring(0, 1).toUpperCase(),
                  style: AppTextStyles.googleSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ColorConstants.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    peer?.nickname ?? peerId,
                    style: AppTextStyles.googleSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Private',
                    style: AppTextStyles.googleSans(
                      fontSize: 12,
                      color: ColorConstants.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: Text(
                    'Send a private message',
                    style: AppTextStyles.googleSans(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final myId = provider.service.identity?.peerId ?? '';
                    final isMine = msg.senderPeerId == myId;
                    return MessageBubble(
                      message: msg,
                      isMine: isMine,
                    );
                  },
                ),
        ),
        ChatComposer(
          onSend: (text) => provider.sendPrivateMessage(text, peerId),
        ),
      ],
        );
      },
    );
  }

  Widget _buildChannelChips(MeshChatProvider provider, bool isDark) {
    final channels = provider.state.channels.where((c) => c.isJoined).toList();
    final theme = Theme.of(context);
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: channels.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final channel = channels[index];
          final isSelected = channel.name == provider.state.selectedChannel;
          return GestureDetector(
            onTap: () => provider.selectChannel(channel.name),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? ColorConstants.primary
                    : isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? ColorConstants.primary
                      : Theme.of(context).dividerTheme.color ?? Colors.grey.shade300,
                ),
              ),
              child: Text(
                '#${channel.displayName}',
                style: AppTextStyles.googleSans(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : theme.textTheme.bodyMedium?.color,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPeersTab(MeshChatProvider provider, bool isDark) {
    return Selector<MeshChatProvider, List<dynamic>>(
      selector: (_, p) => p.state.peers,
      builder: (context, peers, _) {
        if (peers.isEmpty) {
          return _buildNoPeersState(isDark);
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: peers.length,
          itemBuilder: (context, index) {
            final peer = peers[index];
            return PeerTile(
              peer: peer,
              onTap: () => _showPeerDetails(peer, provider),
              onPrivateMessage: () {
                provider.openPrivateChat(peer.peerId);
                _tabController.animateTo(0);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 48,
            color: isDark ? Colors.white24 : Colors.black12,
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: AppTextStyles.googleSans(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Send a message to start chatting',
            style: AppTextStyles.googleSans(
              fontSize: 13,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoPeersState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: ColorConstants.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.bluetooth_searching_rounded,
              size: 32,
              color: ColorConstants.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No nearby peers',
            style: AppTextStyles.googleSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bring another Chat-enabled\ndevice nearby to start chatting.',
            textAlign: TextAlign.center,
            style: AppTextStyles.googleSans(
              fontSize: 14,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => context.read<MeshChatProvider>().startMesh(),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(
              'Scan Again',
              style: AppTextStyles.googleSans(fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: ColorConstants.primary,
              side: BorderSide(color: ColorConstants.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showPeerDetails(ChatPeer peer, MeshChatProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            CircleAvatar(
              radius: 28,
              backgroundColor: ColorConstants.primary.withValues(alpha: 0.1),
              child: Text(
                (peer.nickname ?? peer.peerId).substring(0, 1).toUpperCase(),
                style: AppTextStyles.googleSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: ColorConstants.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (peer.nickname != null)
              Text(
                peer.nickname!,
                style: AppTextStyles.googleSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              'Peer ID: ${peer.displayId}',
              style: AppTextStyles.googleSans(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: peer.isConnected
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                peer.isConnected ? 'Connected' : 'Visible',
                style: AppTextStyles.googleSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: peer.isConnected ? Colors.green : Colors.orange,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  provider.openPrivateChat(peer.peerId);
                  _tabController.animateTo(0);
                },
                icon: const Icon(Icons.lock_outline_rounded, size: 18),
                label: Text(
                  'Private Message',
                  style: AppTextStyles.googleSans(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorConstants.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
