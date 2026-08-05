// lib/shared/services/audit_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuditService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> logAction({
    required String buildingId,
    required String action,
    required String result,
    required String details,
    String? fallbackUserName,
  }) async {
    // Prevent empty or invalid routing context drops
    if (buildingId.isEmpty || buildingId == 'unassigned') return;

    try {
      final User? currentUser = _auth.currentUser;

      String operatorName = "System Operator";
      if (currentUser?.displayName != null && currentUser!.displayName!.trim().isNotEmpty) {
        operatorName = currentUser.displayName!.trim();
      } else if (fallbackUserName != null && fallbackUserName.trim().isNotEmpty) {
        operatorName = fallbackUserName.trim();
      }

      final String operatorUid = currentUser?.uid ?? "unauthenticated_cron";
      final String standardizedAction = action.trim().toUpperCase().replaceAll(' ', '_');
      final String standardizedResult = result.trim().toLowerCase();

      // ✅ Execute firestore write inside a localized safe zone
      await _db.collection('audit_logs').add({
        'timestamp': FieldValue.serverTimestamp(),
        'buildingId': buildingId.trim(),
        'userUid': operatorUid,
        'userName': operatorName,
        'action': standardizedAction,
        'result': standardizedResult,
        'details': details.trim(),
      });
    } catch (dbError) {
      // 🛡️ CRITICAL FIX: Catch database write rejections (e.g. Security Rules blocks)
      // and print to log instead of letting it bubble up and crashing Flutter!
      print('🚨 FAULT ISOLATION: Audit Logging blocked by database rules or network layout: $dbError');
    }
  }
}