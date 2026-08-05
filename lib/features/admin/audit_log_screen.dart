// lib/features/admin/presentation/screens/audit_log_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/theme.dart';
import '../../../shared/services/auth_provider.dart';
import '../../../shared/utils/feedback_util.dart';
import '../../../shared/widgets/app_widgets.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  String _actionQuery = 'ALL';

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: buildAdminAppBar(context, 'System Audit Logs'),
      body: Column(
        children: [
          _buildFilterPipeline(),
          Expanded(child: _buildLogConsumer(user.buildingId)),
        ],
      ),
    );
  }

  Widget _buildFilterPipeline() {
    final logCategories = ['ALL', 'SECURITY', 'INFRASTRUCTURE', 'MEMBERSHIP', 'OPERATIONS'];
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: logCategories.length,
        itemBuilder: (context, index) {
          final cat = logCategories[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(cat, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              selected: _actionQuery == cat,
              selectedColor: AppColors.primary.withOpacity(0.12),
              onSelected: (selected) {
                if (selected) {
                  FeedbackUtil.light();
                  setState(() => _actionQuery = cat);
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogConsumer(String buildingId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('audit_logs')
          .where('buildingId', isEqualTo: buildingId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text("Audit Log Streaming Fault: ${snap.error}"));
        if (!snap.hasData) return const LoadingList(count: 5);

        var docs = snap.data!.docs;

        // Perform category logic lookups optimized to route standard UPPER_CASE action maps
        if (_actionQuery != 'ALL') {
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final act = (data['action'] ?? '').toString().toUpperCase();

            if (_actionQuery == 'SECURITY') return act.contains('LOGIN') || act.contains('LOGOUT');
            if (_actionQuery == 'INFRASTRUCTURE') return act.contains('BUILDING') || act.contains('FLAT') || act.contains('PROFILE');
            if (_actionQuery == 'MEMBERSHIP') return act.contains('MEMBER');
            if (_actionQuery == 'OPERATIONS') return act.contains('APPROVAL') || act.contains('REJECTION') || act.contains('UPDATE') || act.contains('COMPLAINT');
            return false;
          }).toList();
        }

        if (docs.isEmpty) {
          return const Center(child: Text("No audit records found matching parameters."));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final d = docs[index].data() as Map<String, dynamic>;
            final time = (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
            final isSuccess = d['result'] == 'success';

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.border),
              ),
              child: ListTile(
                leading: Icon(
                  isSuccess ? Icons.verified_user : Icons.gpp_bad,
                  color: isSuccess ? Colors.green : Colors.red,
                ),
                title: Text(d['action'] ?? 'UNKNOWN_ACTION', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: Text("Operator: ${d['userName']} \nInfo: ${d['details'] ?? ''}", style: const TextStyle(fontSize: 11)),
                trailing: Text(
                  "${time.hour}:${time.minute.toString().padLeft(2, '0')}",
                  style: const TextStyle(color: AppColors.textHint, fontSize: 11),
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }
}