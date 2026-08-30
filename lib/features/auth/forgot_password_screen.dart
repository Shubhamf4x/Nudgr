import '../../core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/color_constants.dart';
import '../../shared/widgets/nudgr_button.dart';
import '../../shared/widgets/nudgr_text_field.dart';
import 'auth_provider.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isSuccess = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.resetPassword(
      email: _emailController.text.trim(),
    );

    setState(() {
      _isLoading = false;
      _isSuccess = success;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _isSuccess ? _buildSuccessView() : _buildFormView(),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: ColorConstants.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.lock_reset_rounded,
              color: ColorConstants.warning,
              size: 28,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Forgot Password?',
            style: AppTextStyles.googleSans(
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "No worries! Enter your email and we'll send you a reset link.",
            style: AppTextStyles.googleSans(
              fontSize: 15,
              color: Colors.grey,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          NudgrTextField(
            label: 'Email',
            hint: 'Enter your email',
            prefixIcon: Icons.email_outlined,
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!value.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),
          NudgrButton(
            text: 'Send Reset Link',
            isLoading: _isLoading,
            onPressed: _handleResetPassword,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 80),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: ColorConstants.success.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_rounded,
            color: ColorConstants.success,
            size: 40,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Check Your Email',
          style: AppTextStyles.googleSans(
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "We've sent a password reset link to",
          style: AppTextStyles.googleSans(
            fontSize: 15,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _emailController.text,
          style: AppTextStyles.googleSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: ColorConstants.primary,
          ),
        ),
        const SizedBox(height: 40),
        NudgrButton(
          text: 'Back to Sign In',
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            setState(() => _isSuccess = false);
          },
          child: Text(
            'Try another email',
            style: AppTextStyles.googleSans(
              color: ColorConstants.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
