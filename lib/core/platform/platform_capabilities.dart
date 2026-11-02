import 'package:flutter/foundation.dart';

/// Describes what the current platform can actually do.
///
/// Nudgr ships to Android, iOS and the browser from one codebase, but several
/// features rest on APIs that only exist on some of them. Routing every
/// capability question through this class keeps the platform checks in one
/// place, so a screen can ask "can I schedule a reminder?" instead of
/// branching on `kIsWeb` and guessing.
class PlatformCapabilities {
  PlatformCapabilities._();

  static bool get isWeb => kIsWeb;

  static bool get isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static bool get isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Hardware step counter. The Android host exposes it over a method channel;
  /// no other platform provides an equivalent through this app.
  static bool get hasStepSensor => isAndroid;

  /// Local notification scheduling. `flutter_local_notifications` supports
  /// Android, iOS, Linux and macOS but not the browser, where scheduling
  /// requires the (not yet integrated) Notification API plus a service worker.
  static bool get hasLocalNotifications => !isWeb;

  /// Bluetooth LE mesh chat. The transport is not implemented anywhere yet, and
  /// browsers expose only a central-role Web Bluetooth API that cannot advertise
  /// or host a GATT server, so peer discovery is not possible on web.
  static bool get hasBluetoothMesh => false;

  /// Whether the platform can read a file path returned by image_picker.
  /// On web the picked image is a blob, addressed by URL rather than a path.
  static bool get hasFileSystemPaths => !isWeb;

  /// Whether a native crop UI is available. `image_cropper` ships a web
  /// implementation, so this is true everywhere it is wired up.
  static bool get hasImageCrop => true;

  /// Background execution. Android uses a foreground service for step tracking;
  /// browsers throttle or suspend background tabs and have no equivalent.
  static bool get hasBackgroundServices => isMobile;

  /// In-app update check downloads an APK, which only makes sense on Android.
  static bool get hasApkUpdates => isAndroid;

  /// System back-gesture / hardware back button handling.
  static bool get hasSystemBackButton => isAndroid;

  /// Human-readable name of the current platform, for unavailable-state copy.
  static String get platformName {
    if (kIsWeb) return 'the browser';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.linux:
        return 'Linux';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.fuchsia:
        return 'Fuchsia';
    }
  }
}
