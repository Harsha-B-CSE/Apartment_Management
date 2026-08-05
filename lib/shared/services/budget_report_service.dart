// lib/shared/services/budget_report_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/saas_config.dart';

class BudgetSummaryData {
  final double serviceExpenses;
  final double maintenanceExpenses;
  final double parkingExpenses;
  final double totalChargesCollected;
  final List<Map<String, dynamic>> transactionBreakdown;

  BudgetSummaryData({
    required this.serviceExpenses,
    required this.maintenanceExpenses,
    required this.parkingExpenses,
    required this.totalChargesCollected,
    required this.transactionBreakdown,
  });
}

class BudgetReportService {
  static Future<BudgetSummaryData> processReconciliation(String buildingId, int targetMonth, int targetYear) async {
    double serviceSpent = 0.0;
    double maintenanceSpent = 0.0;
    double parkingSpent = 0.0;
    double collectedRevenue = 0.0;
    List<Map<String, dynamic>> itemsList = [];

    // 1. Reconcile Completed Service Requests costs matching Screenshot 2026-06-05 210250.png layout index
    final requests = await FirebaseFirestore.instance
        .collection('service_requests')
        .where('buildingId', isEqualTo: buildingId)
        .where('status', isEqualTo: 'completed')
        .get();

    for (var doc in requests.docs) {
      final data = doc.data();
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

      if (createdAt != null && createdAt.month == targetMonth && createdAt.year == targetYear) {
        // Compute standard mock values for simulation purposes
        double cost = data['serviceName'].toString().toLowerCase() == 'plumber' ? 1200.0 : 850.0;
        serviceSpent += cost;

        itemsList.add({
          'title': data['serviceName'] ?? 'General Service',
          'type': 'Expense (Service)',
          'amount': cost,
          'date': "${createdAt.day}/${createdAt.month}/${createdAt.year}"
        });
      }
    }

    // 2. Fetch Multi-tenant Resident configuration parameters to apply Tiered SaaS Rules
    final residents = await FirebaseFirestore.instance
        .collection('users')
        .where('buildingId', isEqualTo: buildingId)
        .where('role', isEqualTo: 'member')
        .get();

    for (var doc in residents.docs) {
      final data = doc.data();
      String flatType = data['flatType'] ?? '2BHK';

      // Enforce the mandated structural assessment rates
      double assessmentFee = (flatType == '1BHK' || flatType == '2BHK')
          ? SaasConfig.maintenance2BHK
          : SaasConfig.maintenanceAbove2BHK;

      collectedRevenue += assessmentFee;

      itemsList.add({
        'title': "Maintenance Charge - ${data['name']} (${data['flatNo']})",
        'type': 'Revenue Collection',
        'amount': assessmentFee,
        'date': "01/$targetMonth/$targetYear"
      });
    }

    // Baseline functional tracking allocations
    maintenanceSpent = serviceSpent * 0.40;
    parkingSpent = collectedRevenue * 0.05;

    return BudgetSummaryData(
      serviceExpenses: serviceSpent,
      maintenanceExpenses: maintenanceSpent,
      parkingExpenses: parkingSpent,
      totalChargesCollected: collectedRevenue,
      transactionBreakdown: itemsList,
    );
  }
}