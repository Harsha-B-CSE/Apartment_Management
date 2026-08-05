// lib/shared/services/connectivity_service.dart
//
// Wraps connectivity_plus for offline-first behavior.
// ─────────────────────────────────────────────────────────────────────────────
// Screens use this to:
//  1. Show a "You're offline" banner (not a crash)
//  2. Skip Firestore calls when offline — serve Hive cache instead
//  3. Queue writes and retry when connection restores
//
// Usage:
//   if (ConnectivityService.isOnline) { ... }
//   ConnectivityService.stream.listen((online) { ... });

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final _conn = Connectivity();
  static bool _isOnline = true;

  static bool get isOnline => _isOnline;

  static final _controller = StreamController<bool>.broadcast();
  static Stream<bool> get stream => _controller.stream;

  static StreamSubscription? _sub;

  static Future<void> init() async {
    final result = await _conn.checkConnectivity();
    _isOnline = _fromResult(result);

    _sub = _conn.onConnectivityChanged.listen((result) {
      final online = _fromResult(result);
      if (online != _isOnline) {
        _isOnline = online;
        _controller.add(_isOnline);
      }
    });
  }

  static bool _fromResult(List<ConnectivityResult> results) =>
      results.any((r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet);

  static void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
