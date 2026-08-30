import 'package:flutter/material.dart';
import '../../../core/theme/app_text_styles.dart';
import '../services/bit_chat_service.dart';

class MeshStatusIndicator extends StatelessWidget {
  final MeshStatus status;

  const MeshStatusIndicator({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color dotColor;
    String label;

    switch (status) {
      case MeshStatus.active:
        dotColor = Colors.green;
        label = 'Active';
        break;
      case MeshStatus.scanning:
        dotColor = Colors.orange;
        label = 'Scanning';
        break;
      case MeshStatus.permissionDenied:
        dotColor = Colors.red;
        label = 'No Permission';
        break;
      case MeshStatus.offline:
        dotColor = Colors.red;
        label = 'Offline';
        break;
      case MeshStatus.inactive:
        dotColor = Colors.grey;
        label = 'Inactive';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: dotColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: dotColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: dotColor.withValues(alpha: 0.5),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.googleSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: dotColor,
            ),
          ),
        ],
      ),
    );
  }
}

class MeshStatusText extends StatelessWidget {
  final MeshStatus status;
  final int peerCount;

  const MeshStatusText({
    super.key,
    required this.status,
    required this.peerCount,
  });

  @override
  Widget build(BuildContext context) {
    String text;

    switch (status) {
      case MeshStatus.active:
        text = 'Nearby devices: $peerCount';
        break;
      case MeshStatus.scanning:
        text = 'Searching for nearby peers...';
        break;
      case MeshStatus.permissionDenied:
        text = 'Bluetooth permission required';
        break;
      case MeshStatus.offline:
        text = 'Bluetooth is off';
        break;
      case MeshStatus.inactive:
        text = 'Mesh inactive';
        break;
    }

    return Text(
      text,
      style: AppTextStyles.googleSans(
        fontSize: 13,
        color: Colors.grey,
      ),
    );
  }
}
