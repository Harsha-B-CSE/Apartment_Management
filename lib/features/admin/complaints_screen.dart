// lib/features/admin/presentation/screens/admin_complaints_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../shared/models/complaint.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/services/notification_service.dart';
import '../../shared/services/auth_provider.dart';
import '../../shared/widgets/app_widgets.dart';
import 'admin_shell.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/utils/feedback_util.dart';
import '../../shared/services/audit_service.dart';

import '../../shared/screens/complaint_details_screen.dart';

class AdminComplaintsScreen extends StatefulWidget {
  const AdminComplaintsScreen({super.key});
  @override
  State<AdminComplaintsScreen> createState() => _AdminComplaintsScreenState();
}

class _AdminComplaintsScreenState extends State<AdminComplaintsScreen> {
  final _db = FirestoreService();
  String _filter = 'all';

  final _statuses = ['all', 'open', 'in_progress', 'resolved', 'closed'];

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: buildAdminAppBar(context, 'Complaints'),
      body: Column(children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            children: _statuses.map((s) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(s.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontSize: 11)),
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
            stream: _db.streamFiltered('complaints', buildingId: user.buildingId, orderBy: 'createdAt'),
            builder: (context, snap) {
              if (snap.hasError) return Center(child: Text("Error: ${snap.error}"));
              if (!snap.hasData) return const LoadingList();

              var docs = snap.data!.docs.where((d) => d.exists && d.data() != null).toList();

              if (_filter != 'all') {
                docs = docs.where((d) => (d.data() as Map)['status'] == _filter).toList();
              }

              if (docs.isEmpty){
                return const EmptyState(
                  icon: Icons.assignment_turned_in_rounded,
                  title: 'No Complaints',
                  subtitle: 'All clear! No complaints to show.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _ComplaintCard(
                  Complaint.fromDoc(docs[i]),
                  onUpdate: (complaint) {
                    FeedbackUtil.light();
                    Navigator.push(context, MaterialPageRoute(
                      builder: (c) => ComplaintDetailsScreen(complaint: complaint),
                    ));
                  },
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  final Complaint complaint;
  final Function(Complaint) onUpdate;
  const _ComplaintCard(this.complaint, {required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onUpdate(complaint),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(complaint.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                StatusBadge(complaint.status),
              ]),
              const SizedBox(height: 6),
              Text(complaint.description, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(children: [
                const FaIcon(FontAwesomeIcons.user, size: 11, color: AppColors.textHint),
                const SizedBox(width: 5),
                Text(complaint.raisedByName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(width: 10),
                const FaIcon(FontAwesomeIcons.doorOpen, size: 11, color: AppColors.textHint),
                const SizedBox(width: 5),
                Text('Flat ${complaint.flatNo}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(6)),
                  child: Text(complaint.category, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ),
              ]),
              if (complaint.photoUrls.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.attachment, size: 12, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Text('${complaint.photoUrls.length} attachment(s)', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                  ],
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}