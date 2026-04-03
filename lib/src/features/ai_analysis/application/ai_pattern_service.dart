import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

class AIPatternService {
  StreamSubscription<AccelerometerEvent>? _subscription;
  final Function(String message, double magnitude) onAbnormalMovement;

  AIPatternService({required this.onAbnormalMovement});

  void startMonitoring() {
    _subscription = accelerometerEventStream().listen((AccelerometerEvent event) {
      // Calculate total G-force magnitude
      // sqrt(x^2 + y^2 + z^2)
      final double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      
      // Gravity is roughly 9.8 m/s^2. 
      // 3.0g (~30 m/s^2) is a strong sudden movement (run, drop, grab)
      if (magnitude > 30.0) {
        onAbnormalMovement('Sudden High-G Force Detected (Possible Grab/Drop)', magnitude);
      }
      
      // More advanced: Detect sustained movement in a specific direction?
      // For MVP, we use the magnitude threshold as the primary "AI Alert"
    });
  }

  void stopMonitoring() {
    _subscription?.cancel();
  }
}
