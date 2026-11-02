import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Representative viewports for responsive checks.
///
/// Sizes are in logical pixels and cover the breakpoints in
/// `lib/core/utils/responsive.dart`: a narrow phone, a small browser window, a
/// tablet, a laptop and a wide desktop display.
class TestViewports {
  TestViewports._();

  static const Size phoneSmall = Size(320, 480);
  static const Size phone = Size(390, 844);
  static const Size browserNarrow = Size(380, 500);
  static const Size tablet = Size(834, 1112);
  static const Size laptop = Size(1280, 800);
  static const Size desktopWide = Size(1920, 1080);

  static const Map<String, Size> all = {
    'phone-320x480': phoneSmall,
    'phone-390x844': phone,
    'browser-380x500': browserNarrow,
    'tablet-834x1112': tablet,
    'laptop-1280x800': laptop,
    'desktop-1920x1080': desktopWide,
  };
}

/// Sets the logical size of the test surface and restores it on teardown.
void setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Pumps [app] at every provided viewport and fails if any of them reports
/// a layout overflow.
///
/// Flutter surfaces `RenderFlex overflowed` through [FlutterError.onError] as a
/// `FlutterErrorDetails` whose exception is a [FlutterError]; this collects them
/// so a single test can assert "no overflow at any target size" per screen.
Future<Map<String, List<String>>> overflowsAtViewports(
  WidgetTester tester,
  Widget app, {
  Map<String, Size> viewports = TestViewports.all,
}) async {
  final failures = <String, List<String>>{};

  for (final entry in viewports.entries) {
    setViewport(tester, entry.value);
    final errors = <String>[];

    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.toString();
      if (text.contains('overflowed') ||
          text.contains('RenderFlex') ||
          text.contains('Vertical viewport was given unbounded')) {
        errors.add(text.split('\n').first);
      }
    };

    try {
      await tester.pumpWidget(app);
      await tester.pump(const Duration(milliseconds: 350));
      // A second frame exercises post-frame callbacks and animations.
      await tester.pump(const Duration(milliseconds: 350));
    } finally {
      FlutterError.onError = previous;
    }

    if (errors.isNotEmpty) {
      failures[entry.key] = errors.toSet().toList();
    }

    // Reset the tree between viewports so state does not leak.
    await tester.pumpWidget(const SizedBox.shrink());
  }

  return failures;
}

/// Wraps [child] in a minimal themed app so screens that read `Theme.of` or
/// `MediaQuery` behave as they would in the real app.
Widget hostApp(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF10101C),
      colorScheme: const ColorScheme.dark(primary: Color(0xFF6C63FF)),
    ),
    home: child,
  );
}
