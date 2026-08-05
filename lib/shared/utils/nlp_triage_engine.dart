import 'package:flutter/foundation.dart';

class TriageResult {
  final String urgency;
  final String category;
  final String? adminNote;

  TriageResult({required this.urgency, required this.category, this.adminNote});
}

class NlpTriageEngine {
  /// Runs the text analysis in a background isolate to prevent UI lag.
  static Future<TriageResult> analyzeComplaint(String text) async {
    // compute() spins up a separate thread to run the analysis
    return await compute(_runAnalysis, text.toLowerCase());
  }

  /// This function runs in the isolate. It cannot access UI or global state.
  static TriageResult _runAnalysis(String text) {
    String category = 'General';
    String urgency = 'Low';
    String? adminNote;

    // 1. Analyze Category
    if (text.contains('water') || text.contains('leak') || text.contains('pipe') || text.contains('plumb')) {
      category = 'Plumbing';
    } else if (text.contains('electric') || text.contains('light') || text.contains('wire') || text.contains('switch')) {
      category = 'Electrical';
    } else if (text.contains('elevator') || text.contains('lift')) {
      category = 'Elevator';
    } else if (text.contains('clean') || text.contains('garbage') || text.contains('trash')) {
      category = 'Housekeeping';
    } else if (text.contains('noise') || text.contains('loud') || text.contains('party')) {
      category = 'Disturbance';
    } else if (text.contains('medical') || text.contains('doctor') || text.contains('health') || text.contains('injury') || text.contains('man down') || text.contains('blood')) {
      category = 'Medical';
    }

    // 2. Analyze Urgency
    if (text.contains('fire') || text.contains('smoke') || text.contains('spark') || 
        text.contains('flood') || text.contains('stuck') || text.contains('emergency') || text.contains('man down') || text.contains('injury')) {
      urgency = 'Emergency';
    } else if (text.contains('leak') || text.contains('broken') || text.contains('stop')) {
      urgency = 'High';
    } else if (text.contains('dirty') || text.contains('noise')) {
      urgency = 'Medium';
    }

    // 3. Generate Auto-Reply (Admin Note)
    if (category == 'Medical' && urgency == 'Emergency') {
      adminNote = "[AI AUTO-REPLY]: MEDICAL EMERGENCY DETECTED. Please call local emergency services (Ambulance/Paramedics) immediately if someone is hurt. Security has been alerted to provide building access.";
    } else if (category == 'Electrical' && urgency == 'Emergency') {
      adminNote = "[AI AUTO-REPLY]: Please do not touch the affected area. If safe, turn off the main breaker. A technician has been prioritized.";
    } else if (category == 'Plumbing' && urgency == 'High') {
      adminNote = "[AI AUTO-REPLY]: If there is active flooding, please turn off the nearest water valve immediately. Maintenance is notified.";
    } else if (category == 'Elevator' && urgency == 'Emergency') {
      adminNote = "[AI AUTO-REPLY]: Do not attempt to force the doors open. Emergency rescue is on the way.";
    } else if (category == 'Disturbance') {
      adminNote = "[AI AUTO-REPLY]: Security has been notified to investigate the noise complaint.";
    } else {
      adminNote = "[AI AUTO-REPLY]: Your request has been automatically categorized as $category ($urgency urgency) and forwarded to the Building Admin.";
    }

    return TriageResult(urgency: urgency, category: category, adminNote: adminNote);
  }
}
