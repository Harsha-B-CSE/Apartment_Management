import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
import '../../shared/services/auth_provider.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/services/storage_service.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/utils/feedback_util.dart';
import '../../shared/models/complaint.dart';
import '../../shared/screens/complaint_details_screen.dart';
import '../../shared/utils/nlp_triage_engine.dart';
import '../../shared/services/notification_service.dart';

class MemberComplaintsScreen extends StatelessWidget {
  const MemberComplaintsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: buildMemberAppBar(context, 'My Complaints'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          FeedbackUtil.light();
          _showAddComplaint(context, user.buildingId, user.uid, user.name, user.flatNo ?? 'N/A');
        },
        label: const Text("New Complaint", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add, color: Colors.white),
        backgroundColor: AppColors.primary,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('complaints')
            .where('buildingId', isEqualTo: user.buildingId)
            .where('raisedByUid', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text("Error: ${snap.error}"));
          if (snap.connectionState == ConnectionState.waiting) return const LoadingList(count: 3);
          if (snap.data == null || snap.data!.docs.isEmpty) {
            return const Center(child: Text("No complaints filed yet.", style: TextStyle(color: AppColors.textSecondary)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snap.data!.docs.length,
            itemBuilder: (context, i) {
              final complaint = Complaint.fromDoc(snap.data!.docs[i]);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (c) => ComplaintDetailsScreen(complaint: complaint),
                    ));
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(complaint.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                              const SizedBox(height: 4),
                              Text("Status: ${complaint.status.toUpperCase()}", style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        StatusBadge(complaint.status),
                        const SizedBox(width: 12),
                        const Icon(Icons.chevron_right, color: AppColors.textHint),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddComplaint(BuildContext rootContext, String buildingId, String uid, String name, String flat) {
    final title = TextEditingController();
    final desc = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;
    List<File> selectedImages = [];

    showDialog(
      context: rootContext,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext stateContext, StateSetter setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text("Raise New Complaint", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppTextField(label: 'Issue Title', controller: title, validator: (v) => v!.isEmpty ? 'Required' : null),
                      const SizedBox(height: 15),
                      AppTextField(label: 'Description', controller: desc, maxLines: 3, validator: (v) => v!.isEmpty ? 'Required' : null),
                      const SizedBox(height: 25),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.pop(dialogContext),
                  child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: loading ? null : () async {
                    if (!formKey.currentState!.validate()) {
                      FeedbackUtil.error();
                      return;
                    }

                    FeedbackUtil.medium();
                    setDialogState(() => loading = true);

                    try {
                      if (buildingId.isEmpty || buildingId == 'unassigned') throw "Building ID is missing from your profile!";

                      // 🧠 RUN NLP TRIAGE ENGINE ASYNCHRONOUSLY IN ISOLATE
                      final triage = await NlpTriageEngine.analyzeComplaint("${title.text} ${desc.text}");

                      final docRef = await FirestoreService().add('complaints', {
                        'buildingId': buildingId.trim(),
                        'raisedByUid': uid,
                        'raisedByName': name,
                        'flatNo': flat,
                        'title': title.text.trim(),
                        'description': desc.text.trim(),
                        'status': 'open',
                        'urgency': triage.urgency,
                        'category': triage.category,
                        'adminNote': triage.adminNote,
                        'createdAt': Timestamp.now(),
                        'photoUrls': [], // Explicitly empty since Storage is not used
                      });

                      // 🤖 Inject NLP Auto-Reply directly into the discussion thread!
                      if (triage.adminNote != null) {
                        await FirebaseFirestore.instance
                            .collection('complaints')
                            .doc(docRef)
                            .collection('comments')
                            .add({
                          'senderId': 'system_ai',
                          'senderName': 'AI Assistant',
                          'senderRole': 'admin',
                          'text': triage.adminNote,
                          'createdAt': Timestamp.now(),
                        });
                      }

                      // 🔔 Notify Admins in the building
                      await NotificationService.sendNotification(
                        title: 'New Complaint: ${triage.urgency.toUpperCase()}',
                        body: 'Flat $flat reported: ${title.text.trim()}',
                        type: 'complaint',
                        buildingId: buildingId.trim(),
                      );

                      FeedbackUtil.success();
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    } catch (e) {
                      FeedbackUtil.error();
                      ScaffoldMessenger.of(rootContext).showSnackBar(
                        SnackBar(content: Text("SUBMIT FAILED: $e"), backgroundColor: Colors.red),
                      );
                    } finally {
                      if (dialogContext.mounted) setDialogState(() => loading = false);
                    }
                  },
                  child: loading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('SUBMIT'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}