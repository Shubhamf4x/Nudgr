import 'package:flutter/material.dart';

import '../../core/platform/platform_capabilities.dart';
import 'empty_state.dart';

/// Shown in place of a feature the current platform cannot support.
///
/// Reuses [EmptyState] rather than introducing a second look for "no content",
/// and always states which platform is missing what, so a limitation is never
/// mistaken for a bug or an empty account.
class PlatformUnavailable extends StatelessWidget {
  final IconData icon;
  final String feature;
  final String detail;
  final String? alternative;
  const PlatformUnavailable({
    super.key,
    required this.icon,
    required this.feature,
    required this.detail,
    this.alternative,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      '$feature is not available on ${PlatformCapabilities.platformName}.',
      detail,
      ?alternative,
    ].join('\n\n');
    return EmptyState(
      icon: icon,
      title: '$feature unavailable',
      subtitle: subtitle,
    );
  }
}
