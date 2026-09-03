import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/sync_service.dart';

class SyncProvider extends ChangeNotifier {
  final SyncService _syncService = SyncService.getInstance();
  Timer? _pollTimer;

  String _lastSnapshot = '';

  SyncStatus get status => _syncService.status;
  DateTime? get lastSyncTime => _syncService.lastSyncTime;
  String? get lastSyncError => _syncService.lastSyncError;
  int get pendingCount => _syncService.pendingCount;
  bool get isOnline => _syncService.isOnline;
  bool get isSyncing => _syncService.isSyncing;
  bool get cloudEnabled => _syncService.cloudEnabled;

  String get statusLabel {
    if (!cloudEnabled) return 'On this device';
    if (!isOnline) return 'Offline';
    switch (status) {
      case SyncStatus.syncing:
        return 'Syncing...';
      case SyncStatus.error:
        return 'Sync error';
      case SyncStatus.offline:
        return 'Offline';
      case SyncStatus.idle:
        return 'Up to date';
    }
  }

  String get lastSyncLabel {
    if (lastSyncTime == null) return 'Never';
    final diff = DateTime.now().difference(lastSyncTime!);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final snapshot =
          '${_syncService.status}|$_syncService.isOnline|${_syncService.pendingCount}|${_syncService.lastSyncTime?.millisecondsSinceEpoch ?? 0}|${_syncService.lastSyncError ?? ''}';
      if (snapshot == _lastSnapshot) return;
      _lastSnapshot = snapshot;
      notifyListeners();
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
  }

  Future<void> syncNow() async {
    await _syncService.fullSync();
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
