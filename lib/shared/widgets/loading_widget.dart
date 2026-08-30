import '../../core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import '../../core/constants/color_constants.dart';

class LoadingWidget extends StatelessWidget {
  final String? message;
  final double size;

  const LoadingWidget({super.key, this.message, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: size,
            width: size,
            child: CircularProgressIndicator(
              color: ColorConstants.primary,
              strokeWidth: 3,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: AppTextStyles.googleSans(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
