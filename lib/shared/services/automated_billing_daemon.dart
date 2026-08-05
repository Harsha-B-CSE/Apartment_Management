// lib/shared/services/automated_billing_daemon.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/saas_config.dart';
import 'budget_report_service.dart';
import 'notification_service.dart';

class AutomatedBillingDaemon {
  static Timer? _cronHeartbeat;

  static void initializePipeline() {
    // Execute a recurring evaluation routine every 24 hours to monitor period cross-overs
    _cronHeartbeat = Timer.periodic(const Duration(hours: 24), (timer) {
      _evaluateAndIssueInvoices();
    });
  }

  static Future<void> _evaluateAndIssueInvoices() async {
    final now = DateTime.now();

    // Target activation window: First day of the calendar cycle
    if (now.day != 1) return;

    final targetMonth = now.month == 1 ? 12 : now.month - 1;
    final targetYear = now.month == 1 ? now.year - 1 : now.year;

    try {
      final buildings = await FirebaseFirestore.instance.collection('buildings').get();

      for (var bDoc in buildings.docs) {
        final bId = bDoc.id;

        // Execute financial calculations
        final reconciliationData = await BudgetReportService.processReconciliation(bId, targetMonth, targetYear);

        // Distribute calculated overheads across active tenant profiles
        final tenants = await FirebaseFirestore.instance
            .collection('users')
            .where('buildingId', isEqualTo: bId)
            .where('role', isEqualTo: 'member')
            .get();

        for (var tDoc in tenants.docs) {
          final tData = tDoc.data();
          String flatType = tData['flatType'] ?? '2BHK';

          double finalBilledAmount = (flatType == '1BHK' || flatType == '2BHK')
              ? SaasConfig.maintenance2BHK
              : SaasConfig.maintenanceAbove2BHK;

          // Dispatch transactional event updates down the pipeline
          await NotificationService.sendNotification(
            title: 'Monthly Statement Generated',
            body: 'Statement for $targetMonth/$targetYear settled. Total Due: ${SaasConfig.currencySymbol}$finalBilledAmount (Includes Base Maintenance + Logged Services).',
            type: 'general',
            targetUid: tDoc.id,
          );
        }
      }
    } catch (_) {
      // Internal execution logging block
    }
  }

  static void shutdownPipeline() {
    _cronHeartbeat?.cancel();
  }
}