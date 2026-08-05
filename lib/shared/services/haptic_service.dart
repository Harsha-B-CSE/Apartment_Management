import 'package:haptic_feedback/haptic_feedback.dart';

class HapticService {
  static Future<void> light() async {
    final canVibrate = await Haptics.canVibrate();
    if (canVibrate) await Haptics.vibrate(HapticsType.light);
  }

  static Future<void> medium() async {
    final canVibrate = await Haptics.canVibrate();
    if (canVibrate) await Haptics.vibrate(HapticsType.medium);
  }

  static Future<void> heavy() async {
    final canVibrate = await Haptics.canVibrate();
    if (canVibrate) await Haptics.vibrate(HapticsType.heavy);
  }

  static Future<void> success() async {
    final canVibrate = await Haptics.canVibrate();
    if (canVibrate) await Haptics.vibrate(HapticsType.success);
  }

  static Future<void> error() async {
    final canVibrate = await Haptics.canVibrate();
    if (canVibrate) await Haptics.vibrate(HapticsType.error);
  }
}
