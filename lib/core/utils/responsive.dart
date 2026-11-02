import 'package:flutter/material.dart';

/// Shared breakpoints and sizing helpers for Nudgr's responsive layout.
///
/// Values follow Material 3 window size classes: compact (phones), medium
/// (tablets/small windows) and expanded (desktop web). Screens read these
/// instead of hardcoding magic numbers, so the whole app breaks at the same
/// widths.
class Responsive {
  Responsive._();

  /// Below this width the layout is the mobile-first design.
  static const double compactMax = 600;

  /// Tablet / small laptop range.
  static const double mediumMax = 1024;

  /// Widest comfortable line length for reading and forms.
  static const double maxContentWidth = 720;

  /// Wider cap for grid-style screens (notes, calendar, tasks).
  static const double maxWideContentWidth = 1100;

  /// Navigation rail switches in at this width instead of a bottom bar.
  static const double railBreakpoint = 900;

  /// Two-column form/grid layouts switch in at this width.
  static const double twoColumnBreakpoint = 700;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compactMax;

  static bool isMedium(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= compactMax && w < mediumMax;
  }

  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= mediumMax;

  static bool useNavigationRail(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= railBreakpoint;

  /// True when a viewport is short enough that fixed-height blocks must shrink
  /// (landscape phones, small browser windows).
  static bool isShort(BuildContext context) =>
      MediaQuery.sizeOf(context).height < 640;

  static double horizontalPadding(BuildContext context) {
    if (isExpanded(context)) return 32;
    if (isMedium(context)) return 24;
    return 20;
  }

  /// Number of grid columns that fit comfortably at the current width.
  static int gridColumns(
    double width, {
    int min = 1,
    int max = 4,
    double minTileWidth = 260,
  }) {
    final fitting = (width / minTileWidth).floor();
    return fitting.clamp(min, max);
  }
}

/// Constrains page content to a comfortable width and centres it.
///
/// On phones this is a no-op; on desktop web it stops every screen from
/// stretching a phone layout across 1920px. [wide] uses the grid cap instead of
/// the reading cap.
/// Makes a centred block shrink-to-fit but scroll when the viewport is short.
///
/// Fixed-height centring is the most common mobile-first overflow: a column that
/// fits a tall phone clips in a 500dp browser window or under large text
/// scaling. Wrapping it in this keeps it centred when there is room and lets it
/// scroll when there is not, without any height maths at the call site.
class CenteredScrollable extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const CenteredScrollable({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : 0,
            ),
            child: Center(
              child: Padding(padding: padding, child: child),
            ),
          ),
        );
      },
    );
  }
}

class ResponsiveContent extends StatelessWidget {
  final Widget child;
  final bool wide;
  final EdgeInsetsGeometry? padding;
  const ResponsiveContent({
    super.key,
    required this.child,
    this.wide = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final maxWidth = wide
        ? Responsive.maxWideContentWidth
        : Responsive.maxContentWidth;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: padding == null
            ? child
            : Padding(padding: padding!, child: child),
      ),
    );
  }
}
