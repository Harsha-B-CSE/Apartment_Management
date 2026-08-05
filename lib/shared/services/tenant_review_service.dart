// lib/shared/services/tenant_review_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class TenantReviewService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Submit a new review from a tenant profile
  Future<void> submitReview({
    required String buildingId,
    required String tenantUid,
    required String tenantName,
    required String flatNo,
    required double ratingScore,
    required String feedbackComment,
  }) async {
    await _db.collection('ratings').add({
      'timestamp': FieldValue.serverTimestamp(),
      'buildingId': buildingId,
      'tenantUid': tenantUid,
      'tenantName': tenantName,
      'flatNo': flatNo,
      'ratingScore': ratingScore,
      'feedbackComment': feedbackComment,
    });
  }

  /// Stream historical reviews for a specific building instance (Used by Admin screens)
  Stream<QuerySnapshot> streamBuildingRatings(String buildingId) {
    return _db.collection('ratings')
        .where('buildingId', isEqualTo: buildingId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
}