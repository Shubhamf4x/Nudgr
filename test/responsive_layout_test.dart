import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nudgr/core/utils/responsive.dart';
import 'package:nudgr/shared/widgets/empty_state.dart';
import 'package:nudgr/shared/widgets/nudgr_button.dart';
import 'package:nudgr/shared/widgets/platform_unavailable.dart';
import 'package:nudgr/shared/widgets/task_card.dart';
import 'package:nudgr/shared/models/task_model.dart';
import 'package:nudgr/features/auth/onboarding_screen.dart';

import 'support/responsive_harness.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Responsive breakpoints', () {
    testWidgets('classify compact / medium / expanded widths', (tester) async {
      setViewport(tester, const Size(390, 844));
      late BuildContext captured;
      await tester.pumpWidget(
        hostApp(
          Builder(
            builder: (context) {
              captured = context;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(Responsive.isCompact(captured), isTrue);
      expect(Responsive.isMedium(captured), isFalse);
      expect(Responsive.isExpanded(captured), isFalse);
      expect(Responsive.useNavigationRail(captured), isFalse);

      setViewport(tester, const Size(834, 1112));
      await tester.pumpWidget(
        hostApp(
          Builder(
            builder: (context) {
              captured = context;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(Responsive.isCompact(captured), isFalse);
      expect(Responsive.isMedium(captured), isTrue);
      expect(Responsive.useNavigationRail(captured), isFalse);

      setViewport(tester, const Size(1920, 1080));
      await tester.pumpWidget(
        hostApp(
          Builder(
            builder: (context) {
              captured = context;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(Responsive.isExpanded(captured), isTrue);
      expect(Responsive.useNavigationRail(captured), isTrue);
    });

    test('gridColumns scales with width and respects bounds', () {
      expect(Responsive.gridColumns(320, min: 2, minTileWidth: 160), 2);
      expect(Responsive.gridColumns(834, min: 2, max: 2), 2);
      expect(Responsive.gridColumns(1920, min: 2, max: 4), 4);
      expect(Responsive.gridColumns(1920, min: 1, max: 3), 3);
    });
  });

  group('ResponsiveContent caps content width', () {
    testWidgets('fills a phone but clamps a desktop viewport', (tester) async {
      const innerKey = ValueKey('responsive-inner');
      Future<double> widthAt(Size size) async {
        setViewport(tester, size);
        await tester.pumpWidget(
          hostApp(
            const Scaffold(
              body: ResponsiveContent(
                child: SizedBox(
                  key: innerKey,
                  height: 10,
                  width: double.infinity,
                ),
              ),
            ),
          ),
        );
        return tester.getSize(find.byKey(innerKey)).width;
      }

      final phone = await widthAt(const Size(390, 844));
      final desktop = await widthAt(const Size(1920, 1080));

      expect(phone, lessThanOrEqualTo(390));
      expect(desktop, lessThanOrEqualTo(Responsive.maxContentWidth));
      expect(desktop, greaterThan(300));
    });
  });

  group('No layout overflow at representative viewports', () {
    testWidgets('EmptyState scrolls instead of overflowing', (tester) async {
      final failures = await overflowsAtViewports(
        tester,
        hostApp(
          const Scaffold(
            body: EmptyState(
              icon: Icons.checklist_rounded,
              title: 'No tasks yet',
              subtitle:
                  'Create your first task to start organising your day and '
                  'tracking what matters most to you.',
              actionText: 'Add task',
            ),
          ),
        ),
      );
      expect(failures, isEmpty, reason: 'overflowing viewports: $failures');
    });

    testWidgets('PlatformUnavailable renders its explanation everywhere', (
      tester,
    ) async {
      final failures = await overflowsAtViewports(
        tester,
        hostApp(
          const Scaffold(
            body: PlatformUnavailable(
              icon: Icons.directions_walk_rounded,
              feature: 'Step counting',
              detail:
                  'A hardware step counter is only available on Android '
                  'devices with the activity-recognition permission.',
              alternative:
                  'Your saved step history is still shown where available.',
            ),
          ),
        ),
      );
      expect(failures, isEmpty, reason: 'overflowing viewports: $failures');
    });

    testWidgets('NudgrButton grows with large text instead of clipping', (
      tester,
    ) async {
      final failures = await overflowsAtViewports(
        tester,
        hostApp(
          Scaffold(
            body: Center(
              child: SizedBox(
                width: 280,
                child: NudgrButton(
                  text: 'Sign in to continue with your account',
                  onPressed: () {},
                  icon: Icons.login_rounded,
                ),
              ),
            ),
          ),
        ),
        viewports: const {
          'phone-320x480': TestViewports.phoneSmall,
          'browser-380x500': TestViewports.browserNarrow,
        },
      );
      expect(failures, isEmpty, reason: 'overflowing viewports: $failures');
    });

    testWidgets('TaskCard survives a long category name and long title', (
      tester,
    ) async {
      final task = TaskModel(
        id: 't1',
        title:
            'Prepare the quarterly engineering review deck with all the '
            'supporting metrics and follow-up actions',
        categoryName: 'Professional Development and Continuous Learning',
        priority: 'high',
        dueDate: DateTime(2026, 8, 30),
        userId: 'uid-1',
        createdAt: DateTime(2026, 8, 1),
        updatedAt: DateTime(2026, 8, 1),
      );

      final failures = await overflowsAtViewports(
        tester,
        hostApp(
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(12),
              child: TaskCard(task: task, onTap: () {}, onToggle: () {}),
            ),
          ),
        ),
        viewports: const {
          'phone-320x480': TestViewports.phoneSmall,
          'browser-380x500': TestViewports.browserNarrow,
        },
      );
      expect(failures, isEmpty, reason: 'overflowing viewports: $failures');
    });

    testWidgets('Onboarding scrolls in a short browser window', (tester) async {
      final failures = await overflowsAtViewports(
        tester,
        hostApp(const OnboardingScreen()),
        viewports: const {
          'browser-380x500': TestViewports.browserNarrow,
          'phone-320x480': TestViewports.phoneSmall,
          'laptop-1280x800': TestViewports.laptop,
        },
      );
      expect(failures, isEmpty, reason: 'overflowing viewports: $failures');
    });
  });
}
