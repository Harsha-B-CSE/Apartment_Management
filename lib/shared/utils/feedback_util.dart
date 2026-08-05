// lib/shared/utils/feedback_util.dart
import 'package:haptic_feedback/haptic_feedback.dart';

class FeedbackUtil {
  FeedbackUtil._();

  static void light() => Haptics.vibrate(HapticsType.light);
  static void medium() => Haptics.vibrate(HapticsType.medium);
  static void error() => Haptics.vibrate(HapticsType.error);
  static void success() => Haptics.vibrate(HapticsType.success);

  /// Cascading native taps for a richer success feel
  static Future<void> successExtended() async {
    await Haptics.vibrate(HapticsType.medium);
    await Future.delayed(const Duration(milliseconds: 80));
    await Haptics.vibrate(HapticsType.medium);
  }
}