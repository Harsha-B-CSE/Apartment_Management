// lib/features/admin/presentation/screens/admin_service_requests_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../shared/models/service.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/services/notification_service.dart';
import '../../shared/services/auth_provider.dart';
import '../../shared/widgets/app_widgets.dart';
import 'admin_shell.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/utils/feedback_util.dart';
import '../../shared/services/audit_service.dart'; // ⚡ Import the unified audit system utility

class AdminServiceRequestsScreen extends StatefulWidget {
  const AdminServiceRequestsScreen({super.key});
  @override
  State<AdminServiceRequestsScreen> createState() => _AdminServiceRequestsScreenState();
}

class _AdminServiceRequestsScreenState extends State<AdminServiceRequestsScreen> {
  final _db = FirestoreService();
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: buildAdminAppBar(context, 'Service Requests'),
      body: Column(children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            children: ['all','pending','in_progress','completed','rejected'].map((s) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(s.replaceAll('_',' ').toUpperCase(), style: const TextStyle(fontSize: 11)),
                selected: _filter == s,
                onSelected: (_) {
                  FeedbackUtil.light();
                  setState(() => _filter = s);
                },
                selectedColor: AppColors.primary.withOpacity(0.12),
                checkmarkColor: AppColors.primary,
              ),
            )).toList(),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.streamFiltered('service_requests', buildingId: user.buildingId, orderBy: 'createdAt'),
            builder: (context, snap) {
              if (snap.hasError) return Center(child: Text("Error: ${snap.error}"));
              if (!snap.hasData) return const LoadingList();
              var docs = snap.data!.docs;
              if (_filter != 'all') docs = docs.where((d) => (d.data() as Map)['status'] == _filter).toList();
              if (docs.isEmpty) return const EmptyState(
                icon: FontAwesomeIcons.clipboardList,
                title: 'No Service Requests', subtitle: 'All requests will appear here',
              );
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final req = ServiceRequest.fromDoc(docs[i]);
                  return _RequestCard(req, onUpdate: () {
                    FeedbackUtil.light();
                    _updateRequest(req);
                  });
                },
              );
            },
          ),
        ),
      ]),
    );
  }

  void _updateRequest(ServiceRequest req) {
    String status = req.status;
    final noteCtrl = TextEditingController(text: req.adminNote ?? '');
    showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Update Request', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(req.serviceName, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          AppDropdown<String>(
            labelText: 'Status', value: status,
            items: ['pending','in_progress','completed','rejected']
                .map((s) => DropdownMenuItem(value: s, child: Text(s.replaceAll('_',' ')))).toList(),
            onChanged: (v) {
              FeedbackUtil.light();
              setS(() => status = v!);
            },
          ),
          const SizedBox(height: 14),
          AppTextField(label: 'Note to Member', hint: 'e.g. Technician will visit tomorrow...', controller: noteCtrl, maxLines: 3),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () async {
                FeedbackUtil.medium();
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                final currentUser = authProvider.user;

                // Dynamically route log classifications matching our operational specifications
                final String actionType = (status == 'completed' || status == 'in_progress')
                    ? "REQUEST_APPROVAL"
                    : "REQUEST_REJECTIONS";

                try {
                  // 1. Update status tracking properties on the core document
                  await _db.update('service_requests', req.id, {'status': status, 'adminNote': noteCtrl.text});

                  // 2. Transmit background notification payload downstream
                  await NotificationService.sendNotification(
                    title: 'Service Request Update',
                    body: 'Your request for "${req.serviceName}" is now ${status.replaceAll('_',' ')}.',
                    type: 'service', targetUid: req.memberUid,
                  );

                  // ⚡ 3. LOCAL AUDIT SUCCESS LEDGER DISPATCH
                  if (currentUser != null) {
                    await AuditService().logAction(
                      buildingId: currentUser.buildingId,
                      action: actionType,
                      result: "success",
                      details: "Updated ${req.serviceName} ticket status to '$status' for Flat ${req.flatNo} (${req.memberName}).",
                      fallbackUserName: currentUser.name,
                    );
                  }

                  FeedbackUtil.success();
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  // ⚡ LOCAL AUDIT FAILURE LEDGER DISPATCH
                  if (currentUser != null) {
                    await AuditService().logAction(
                      buildingId: currentUser.buildingId,
                      action: actionType,
                      result: "failure",
                      details: "Failed to update service request processing state for target transaction ID: ${req.id}. Error: $e",
                      fallbackUserName: currentUser.name,
                    );
                  }

                  FeedbackUtil.error();
                }
              },
              child: const Text('Update'),
            ),
          ),
        ]),
      )),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final ServiceRequest req;
  final VoidCallback onUpdate;
  const _RequestCard(this.req, {required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onUpdate,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(req.serviceName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
            StatusBadge(req.status),
          ]),
          const SizedBox(height: 4),
          Text('${req.memberName} · Flat ${req.flatNo}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          if (req.notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(req.notes, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
          ],
          if (req.adminNote != null && req.adminNote!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const FaIcon(FontAwesomeIcons.noteSticky, size: 12, color: AppColors.accent),
                const SizedBox(width: 8),
                Expanded(child: Text(req.adminNote!, style: const TextStyle(fontSize: 12, color: AppColors.accent))),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}