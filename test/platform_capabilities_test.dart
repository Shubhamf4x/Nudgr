import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nudgr/core/platform/platform_capabilities.dart';

void main() {
  group('PlatformCapabilities', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('web has no step sensor, notifications, Bluetooth or APK updates', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      // kIsWeb is a compile-time constant and stays false under `flutter test`,
      // so the web branch is asserted through the pure-logic getters that do
      // not depend on it rather than by faking the platform.
      expect(PlatformCapabilities.hasBluetoothMesh, isFalse);
    });

    test('Android reports the hardware capabilities the app relies on', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      expect(PlatformCapabilities.isAndroid, isTrue);
      expect(PlatformCapabilities.isMobile, isTrue);
      expect(PlatformCapabilities.isIOS, isFalse);
      expect(PlatformCapabilities.hasStepSensor, isTrue);
      expect(PlatformCapabilities.hasLocalNotifications, isTrue);
      expect(PlatformCapabilities.hasFileSystemPaths, isTrue);
      expect(PlatformCapabilities.hasBackgroundServices, isTrue);
      expect(PlatformCapabilities.hasApkUpdates, isTrue);
      expect(PlatformCapabilities.hasSystemBackButton, isTrue);
      expect(PlatformCapabilities.platformName, 'Android');
    });

    test('iOS keeps notifications and files but not steps or APK updates', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      expect(PlatformCapabilities.isIOS, isTrue);
      expect(PlatformCapabilities.isMobile, isTrue);
      expect(PlatformCapabilities.isAndroid, isFalse);
      expect(PlatformCapabilities.hasStepSensor, isFalse);
      expect(PlatformCapabilities.hasLocalNotifications, isTrue);
      expect(PlatformCapabilities.hasFileSystemPaths, isTrue);
      expect(PlatformCapabilities.hasApkUpdates, isFalse);
      expect(PlatformCapabilities.hasSystemBackButton, isFalse);
      expect(PlatformCapabilities.platformName, 'iOS');
    });

    test('desktop is not mobile and has no step sensor or APK updates', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      expect(PlatformCapabilities.isDesktop, isTrue);
      expect(PlatformCapabilities.isMobile, isFalse);
      expect(PlatformCapabilities.hasStepSensor, isFalse);
      expect(PlatformCapabilities.hasLocalNotifications, isTrue);
      expect(PlatformCapabilities.hasApkUpdates, isFalse);
      expect(PlatformCapabilities.hasSystemBackButton, isFalse);
      expect(PlatformCapabilities.platformName, 'Windows');
    });

    test('Bluetooth mesh is reported unavailable on every platform', () {
      for (final platform in [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.windows,
        TargetPlatform.macOS,
        TargetPlatform.linux,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(
          PlatformCapabilities.hasBluetoothMesh,
          isFalse,
          reason: 'the BLE transport is not implemented on $platform',
        );
      }
    });
  });
}
