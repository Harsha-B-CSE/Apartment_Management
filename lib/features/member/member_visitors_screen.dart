// lib/features/member/presentation/screens/member_visitors_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../shared/services/auth_provider.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/utils/feedback_util.dart';

class MemberVisitorsScreen extends StatelessWidget {
  const MemberVisitorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    // ✅ Sanitized: Strip out any hidden spaces before processing the stream query
    final String cleanMemberBuildingId = user.buildingId.trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: buildMemberAppBar(context, 'My Visitors'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          FeedbackUtil.light();
          _showAddVisitor(context, user.name, user.flatNo ?? 'N/A', cleanMemberBuildingId);
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Visitor', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('visitors')
            .where('memberUid', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text("Query Error: ${snap.error}"));
          if (snap.connectionState == ConnectionState.waiting) return const LoadingList(count: 3);

          final memberDocs = snap.data?.docs ?? [];

          if (memberDocs.isEmpty) {
            return const EmptyState(
                icon: Icons.people_outline,
                title: "No Visitors",
                subtitle: "Pre-register guests here"
            );
          }

          // Local chronological layout ordering
          memberDocs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final Timestamp aTime = aData['entryTime'] ?? aData['createdAt'] ?? Timestamp.now();
            final Timestamp bTime = bData['entryTime'] ?? bData['createdAt'] ?? Timestamp.now();
            return bTime.compareTo(aTime);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: memberDocs.length,
            itemBuilder: (context, i) {
              final d = memberDocs[i].data() as Map<String, dynamic>;

              final String visitorName = d['visitorName'] ?? 'Visitor';
              final String visitPurpose = d['notes'] ?? d['purpose'] ?? 'General Visit';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.person_outline, color: Colors.white),
                  ),
                  title: Text(visitorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(visitPurpose, style: const TextStyle(fontSize: 12)),
                  trailing: StatusBadge(d['status'] ?? 'expected'),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddVisitor(BuildContext context, String hostName, String flatNo, String buildingId) {
    final name = TextEditingController();
    final purpose = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 10),
              const Text("Pre-register Visitor", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 20),
              AppTextField(label: 'Visitor Name', controller: name, validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 15),
              AppTextField(label: 'Purpose of Visit / Notes', controller: purpose, validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: loading ? null : () async {
                    if (!formKey.currentState!.validate()) {
                      FeedbackUtil.error();
                      return;
                    }

                    FeedbackUtil.medium();
                    setSheetState(() => loading = true);

                    try {
                      final auth = Provider.of<AuthProvider>(context, listen: false);
                      final uid = auth.user?.uid;

                      if (uid == null) throw "Authentication session expired.";

                      // ✅ Fixed Form Map: Auto-trims IDs and logs both field keys to keep rules happy
                      await FirestoreService().add('visitors', {
                        'buildingId': buildingId.trim(),
                        'hostUid': uid,
                        'memberUid': uid,
                        'memberName': hostName,
                        'visitorName': name.text.trim(),
                        'purpose': purpose.text.trim(),
                        'notes': purpose.text.trim(), // Synchronizes clean data onto the Admin Card notes block
                        'flatNo': flatNo,
                        'status': 'expected',
                        'entryTime': FieldValue.serverTimestamp(),
                      });

                      if (!ctx.mounted) return;
                      FeedbackUtil.success();
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      FeedbackUtil.error();
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
                        );
                      }
                    } finally {
                      if (ctx.mounted) {
                        setSheetState(() => loading = false);
                      }
                    }
                  },
                  child: loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('REGISTER VISITOR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}