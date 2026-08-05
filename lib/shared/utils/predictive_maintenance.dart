import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class PredictiveMaintenance {
  /// Runs when the admin boots up the app.
  /// Fetches recent complaints and passes them to a background isolate for heavy statistical analysis.
  static Future<void> triggerAnalysis(String buildingId) async {
    try {
      // 1. Fetch complaints for the building and filter locally to bypass Firestore Index requirements
      final cutoff = DateTime.now().subtract(const Duration(days: 90));
      final snap = await FirebaseFirestore.instance
          .collection('complaints')
          .where('buildingId', isEqualTo: buildingId)
          .get();

      // We only need the text and category for analysis from the last 90 days
      final dataList = snap.docs.where((doc) {
        final data = doc.data();
        if (data['createdAt'] == null) return false;
        final createdAt = (data['createdAt'] as Timestamp).toDate();
        return createdAt.isAfter(cutoff) || createdAt.isAtSameMomentAs(cutoff);
      }).map((doc) {
        return {
          'category': doc.data()['category']?.toString() ?? 'General',
          'description': doc.data()['description']?.toString() ?? '',
        };
      }).toList();

      if (dataList.isEmpty) return;

      // 2. Run statistical analysis in a background thread to prevent UI stuttering
      final List<String> alerts = await compute(_analyzePatterns, dataList);

      // 3. Post alerts to Notifications for Admin
      for (String alert in alerts) {
        // We use a specific tag to prevent duplicate alerts
        final alertId = 'predictive_alert_${DateTime.now().year}_${DateTime.now().month}_${alert.hashCode}';
        
        final alertSnap = await FirebaseFirestore.instance.collection('notifications').doc(alertId).get();
        if (!alertSnap.exists) {
          await FirebaseFirestore.instance.collection('notifications').doc(alertId).set({
            'buildingId': buildingId,
            'title': 'AI Maintenance Alert',
            'body': alert,
            'type': 'alert',
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      debugPrint("Predictive Maintenance Engine Failed: $e");
    }
  }

  /// Runs in an Isolate. No access to Firebase or UI.
  static List<String> _analyzePatterns(List<Map<String, String>> complaints) {
    List<String> alerts = [];
    int plumbingCount = 0;
    int elevatorCount = 0;

    for (var c in complaints) {
      if (c['category'] == 'Plumbing') plumbingCount++;
      if (c['category'] == 'Elevator') elevatorCount++;
      
      final desc = c['description']!.toLowerCase();
      if (desc.contains('pipe') && desc.contains('burst')) {
        plumbingCount += 2; // heavily weight bursts
      }
    }

    if (plumbingCount > 5) {
      alerts.add("Predictive Analysis: High frequency of plumbing issues detected recently. Recommend scheduling a building-wide pipe inspection.");
    }
    if (elevatorCount > 3) {
      alerts.add("Predictive Analysis: Elevator malfunction rate is exceeding normal thresholds. Recommend contacting the vendor for early preventive maintenance.");
    }

    return alerts;
  }
}
