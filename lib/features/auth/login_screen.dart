// lib/features/auth/login_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/saas_config.dart';
import '../../shared/services/auth_provider.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/services/notification_service.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/utils/feedback_util.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscure = true;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      FeedbackUtil.error();
      return;
    }

    FeedbackUtil.medium();
    FocusScope.of(context).unfocus();

    final auth = context.read<AuthProvider>();
    final String? error = await auth.login(_email.text.trim(), _password.text);

    if (!mounted) return;

    if (error == null) {
      FeedbackUtil.success();

      if (auth.user != null) {
        await NotificationService.saveToken(auth.user!.uid);
      }
      context.go(auth.isAdmin ? '/admin' : '/member');
    } else {
      FeedbackUtil.error();
      _showError(error);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.danger,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final config = SaasConfig.instance;

    return Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    children: [
                      const Icon(Icons.apartment_rounded, size: 80, color: AppColors.accent),
                      const SizedBox(height: 16),
                      Text(config.appName, style: Theme.of(context).textTheme.headlineMedium),
                      Text(config.tagline, style: const TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 32),

                      // Login Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              if (auth.isLockedOut) _buildLockoutBanner(auth.lockoutMessage),

                              AppTextField(
                                label: 'Email',
                                hint: 'you@domain.com',
                                controller: _email,
                                focusNode: _emailFocus,
                                enabled: !auth.isLoading,
                                keyboardType: TextInputType.text,
                                validator: (v) => (v == null || !v.contains('@')) ? 'Invalid email' : null,
                              ),
                              const SizedBox(height: 16),
                              AppTextField(
                                label: 'Password',
                                hint: '••••••••',
                                controller: _password,
                                focusNode: _passwordFocus,
                                obscureText: _obscure,
                                enabled: !auth.isLoading,
                                suffix: IconButton(
                                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off, size: 18),
                                  onPressed: () {
                                    FeedbackUtil.light();
                                    setState(() => _obscure = !_obscure);
                                  },
                                ),
                                validator: (v) => (v?.length ?? 0) < 6 ? 'Min 6 characters' : null,
                              ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: auth.isLoading ? null : () {
                                      FeedbackUtil.light();
                                      _showResetDialog();
                                    },
                                    child: const Text('Forgot password?', style: TextStyle(fontSize: 12)),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: auth.isLoading ? null : _login,
                                    child: auth.isLoading
                                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : const Text('Sign In'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      if (config.allowSelfSignup) _buildSignupPrompt(),
                    ],
                  ),
                ),
              ),
            ),
        ),
      ),
    );
  }

  Widget _buildLockoutBanner(String? msg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(msg ?? 'Locked out', style: const TextStyle(color: AppColors.danger, fontSize: 12)),
    );
  }

  Widget _buildSignupPrompt() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("New here? ", style: TextStyle(color: AppColors.textSecondary)),
        TextButton(
          onPressed: () {
            FeedbackUtil.light();
            context.go('/signup');
          },
          child: const Text('Create Account'),
        ),
      ],
    );
  }

  void _showResetDialog() {
    final emailCtrl = TextEditingController(text: _email.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: AppTextField(label: 'Email', controller: emailCtrl),
        actions: [
          TextButton(
            onPressed: () {
              FeedbackUtil.light();
              Navigator.pop(ctx);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              FeedbackUtil.medium();
              try {
                // Instantiates structural tracking adjustments internally
                await AuthService().sendPasswordReset(emailCtrl.text.trim());
                if (!mounted) return;
                FeedbackUtil.success();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reset link sent!')));
              } catch (e) {
                FeedbackUtil.error();
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }
}