import 'package:hive_flutter/hive_flutter.dart';

class CacheService {
  static Box? _box;

  static Future<void> init() async {
    if (_box != null) return;
    try {
      _box = await Hive.openBox('apartment_cache');
    } catch (e) {
      await Hive.deleteBoxFromDisk('apartment_cache');
      _box = await Hive.openBox('apartment_cache');
    }
  }

  static Box get box {
    if (_box == null) throw Exception("CacheService not initialized");
    return _box!;
  }

  // --- Dashboard Cache Methods ---

  /// Saves the stats to Hive and resets the staleness flag
  static Future<void> setDashboard(Map<String, int> stats) async {
    await box.put('dashboard_stats', stats);
    await box.put('dashboard_is_stale', false);
  }

  /// Returns the stats only if they are NOT marked as stale
  static Map<String, int>? getDashboard() {
    final bool isStale = box.get('dashboard_is_stale', defaultValue: true);
    if (isStale) return null;

    final data = box.get('dashboard_stats');
    return data != null ? Map<String, int>.from(data) : null;
  }

  /// Returns whatever is in the cache regardless of staleness (for offline mode)
  static Map<String, int>? getDashboardStale() {
    final data = box.get('dashboard_stats');
    return data != null ? Map<String, int>.from(data) : null;
  }

  static Future<void> setDashboardStale(bool isStale) async {
    await box.put('dashboard_is_stale', isStale);
  }

  // --- General Methods ---
  static Future<void> set(String key, dynamic value) async => await box.put(key, value);
  static dynamic get(String key) => box.get(key);
  static Future<void> clearAll() async => await box.clear();
}