import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../application/intruder_detection_service.dart';

/// Transparent, invisible screen that runs silently after 3 failed logins.
/// It calls [IntruderDetectionService.captureAndAnalyze] and then pops itself.
/// The user sees nothing except a very brief black flash (< 2 seconds).
class IntruderOverlayScreen extends ConsumerStatefulWidget {
  const IntruderOverlayScreen({super.key});

  @override
  ConsumerState<IntruderOverlayScreen> createState() =>
      _IntruderOverlayScreenState();
}

class _IntruderOverlayScreenState extends ConsumerState<IntruderOverlayScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fade;
  bool _started = false;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fade = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();

    // Start capture pipeline after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    if (_started) return;
    _started = true;

    final service = ref.read(intruderDetectionServiceProvider);
    final result = await service.captureAndAnalyze();

    debugPrint('[IntruderOverlay] Result: $result');

    // Return to login screen regardless of outcome
    if (mounted) {
      await _fadeController.reverse();
      if (mounted) context.pop();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fully transparent overlay — user cannot see this screen
    return FadeTransition(
      opacity: _fade,
      child: const Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.expand(),
      ),
    );
  }
}
