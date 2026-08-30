import '../../core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

class NudgrTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final int maxLines;
  final bool enabled;
  final VoidCallback? onTap;
  final bool readOnly;

  const NudgrTextField({
    super.key,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.controller,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.maxLines = 1,
    this.enabled = true,
    this.onTap,
    this.readOnly = false,
  });

  @override
  State<NudgrTextField> createState() => _NudgrTextFieldState();
}

class _NudgrTextFieldState extends State<NudgrTextField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: AppTextStyles.googleSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          obscureText: _obscureText,
          validator: widget.validator,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          maxLines: widget.obscureText ? 1 : widget.maxLines,
          enabled: widget.enabled,
          onTap: widget.onTap,
          readOnly: widget.readOnly,
          style: AppTextStyles.googleSans(fontSize: 15),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: AppTextStyles.googleSans(
              color: Colors.grey.withValues(alpha: 0.5),
            ),
            prefixIcon: widget.prefixIcon != null
                ? Icon(widget.prefixIcon, size: 20, color: Colors.grey)
                : null,
            suffixIcon: widget.obscureText
                ? IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      size: 20,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  )
                : widget.suffixIcon,
          ),
        ),
      ],
    );
  }
}
