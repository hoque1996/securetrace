import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../application/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  int _failedAttempts = 0;
  bool _overlayActive = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await ref.read(authControllerProvider.notifier).login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    // If auth still has an error after the call, this attempt failed
    final authState = ref.read(authControllerProvider);
    if (authState.hasError) {
      setState(() => _failedAttempts++);

      // Shake the login button to signal failure
      _shakeController.forward(from: 0);

      if (_failedAttempts >= 3 && !_overlayActive) {
        setState(() => _overlayActive = true);

        // Brief delay so the error snackbar shows before overlay
        await Future.delayed(const Duration(milliseconds: 600));

        if (mounted) {
          await context.push('/intruder-capture');
        }

        // Re-arm after overlay closes
        if (mounted) {
          setState(() {
            _overlayActive = false;
            _failedAttempts = 0;
          });
        }
      }
    } else {
      // Success — reset counter
      setState(() => _failedAttempts = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final attempts = _failedAttempts;

    ref.listen<AsyncValue<void>>(
      authControllerProvider,
      (_, state) {
        if (state.hasError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${state.error}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      },
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),

              // ── Logo + Title ────────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
                        border: Border.all(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                            width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.security,
                        size: 44,
                        color: Color(0xFF00E5FF),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'SecureTrace AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Sign in to continue',
                      style: TextStyle(
                        color: Color(0xFF8892A4),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // ── Warning banner (shown from attempt 2 onward) ────────────
              if (attempts >= 2)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.redAccent, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Warning: ${3 - attempts} attempt(s) remaining before security capture.',
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Email field ─────────────────────────────────────────────
              _GlassTextField(
                controller: _emailController,
                labelText: 'Email',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 16),

              // ── Password field ──────────────────────────────────────────
              _GlassTextField(
                controller: _passwordController,
                labelText: 'Password',
                prefixIcon: Icons.lock_outline,
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFF8892A4),
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),

              const SizedBox(height: 32),

              // ── Login button with shake animation ───────────────────────
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  final dx = attempts > 0
                      ? (8 *
                          (0.5 - _shakeAnimation.value).abs() *
                          (attempts.clamp(1, 3) * 2))
                      : 0.0;
                  return Transform.translate(
                    offset: Offset(dx, 0),
                    child: child,
                  );
                },
                child: ElevatedButton(
                  onPressed: authState.isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: Colors.black,
                    disabledBackgroundColor:
                        const Color(0xFF00E5FF).withValues(alpha: 0.4),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 6,
                    shadowColor: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                  ),
                  child: authState.isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.black, strokeWidth: 2.5),
                        )
                      : const Text(
                          'Login',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Register link ───────────────────────────────────────────
              Center(
                child: TextButton(
                  onPressed: () => context.go('/register'),
                  child: const Text(
                    "Don't have an account? Register",
                    style: TextStyle(color: Color(0xFF00E5FF)),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Attempt dots indicator ──────────────────────────────────
              if (attempts > 0)
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < attempts
                              ? Colors.redAccent
                              : Colors.white.withValues(alpha: 0.15),
                        ),
                      );
                    }),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Reusable glassy text field ───────────────────────────────────────────────

class _GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final IconData prefixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;

  const _GlassTextField({
    required this.controller,
    required this.labelText,
    required this.prefixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Color(0xFF8892A4)),
        prefixIcon: Icon(prefixIcon, color: const Color(0xFF00E5FF), size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFF111827),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
