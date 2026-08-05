// lib/features/admin/presentation/screens/admin_notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../shared/services/auth_provider.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/services/notification_service.dart';
import '../../shared/utils/feedback_util.dart';
import '../../shared/services/audit_service.dart'; // ⚡ Import the unified audit system utility

class AdminNotificationsScreen extends StatelessWidget {
  const AdminNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: buildAdminAppBar(context, 'Manage Notifications'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          FeedbackUtil.light();
          _showCreateNotification(context, user.buildingId, user.name);
        },
        icon: const Icon(Icons.add_comment, color: Colors.white),
        label: const Text("New Notice", style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('notifications')
            .where('buildingId', isEqualTo: user.buildingId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text("Error: ${snap.error}"));
          if (snap.connectionState == ConnectionState.waiting) return const LoadingList();

          if (snap.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.speaker_notes_off, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text("No notifications sent yet.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snap.data!.docs.length,
            itemBuilder: (context, i) {
              final d = snap.data!.docs[i].data() as Map<String, dynamic>;
              final docId = snap.data!.docs[i].id;
              final String noticeTitle = d['title'] ?? 'No Title';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.campaign, color: Colors.white, size: 20),
                  ),
                  title: Text(noticeTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(d['message'] ?? d['body'] ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () {
                      FeedbackUtil.error();
                      _confirmDelete(context, docId, noticeTitle, user.buildingId, user.name);
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showCreateNotification(BuildContext context, String buildingId, String adminName) {
    final titleCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                const Text("Broadcast to Residents", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                AppTextField(
                  label: 'Title',
                  hint: 'e.g., Water Maintenance',
                  controller: titleCtrl,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 15),
                AppTextField(
                  label: 'Message',
                  hint: 'Enter details...',
                  controller: messageCtrl,
                  maxLines: 4,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: loading ? null : () async {
                      if (!formKey.currentState!.validate()) {
                        FeedbackUtil.error();
                        return;
                      }

                      FeedbackUtil.medium();
                      setModalState(() => loading = true);

                      try {
                        await NotificationService.sendNotification(
                          title: titleCtrl.text.trim(),
                          body: messageCtrl.text.trim(),
                          type: 'broadcast',
                          buildingId: buildingId,
                        );

                        // ⚡ SUCCESS LOG: Record notification dispatch event
                        await AuditService().logAction(
                          buildingId: buildingId,
                          action: "PROFILE_UPDATES",
                          result: "success",
                          details: "Broadcasted global notice bulletin: '${titleCtrl.text.trim()}'.",
                          fallbackUserName: adminName,
                        );

                        FeedbackUtil.success();
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        // ⚡ FAILURE LOG: Capture storage write errors
                        await AuditService().logAction(
                          buildingId: buildingId,
                          action: "PROFILE_UPDATES",
                          result: "failure",
                          details: "Failed to broadcast notice bulletin '${titleCtrl.text.trim()}'. Error: $e",
                          fallbackUserName: adminName,
                        );

                        FeedbackUtil.error();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                        }
                      } finally {
                        setModalState(() => loading = false);
                      }
                    },
                    child: loading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                        : const Text("SEND NOTIFICATION", style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String docId, String noticeTitle, String buildingId, String adminName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Notification?"),
        content: const Text("This will remove the message for all residents."),
        actions: [
          TextButton(
            onPressed: () {
              FeedbackUtil.light();
              Navigator.pop(ctx);
            },
            child: const Text("CANCEL"),
          ),
          TextButton(
            onPressed: () async {
              FeedbackUtil.error();
              try {
                // 1. Remove database document references
                await FirebaseFirestore.instance.collection('notifications').doc(docId).delete();

                // ⚡ 2. SUCCESS LOG: Manual system audit compilation tracking
                await AuditService().logAction(
                  buildingId: buildingId,
                  action: "BUILDING_DELETION",
                  result: "success",
                  details: "Purged active notice billboard broadcast item: '$noticeTitle' (ID: $docId).",
                  fallbackUserName: adminName,
                );

                if (context.mounted) Navigator.pop(ctx);
              } catch (e) {
                // ⚡ FAILURE LOG: Record deletion operation exceptions
                await AuditService().logAction(
                  buildingId: buildingId,
                  action: "BUILDING_DELETION",
                  result: "failure",
                  details: "Failed to drop notice item '$noticeTitle' from database cache. Error: $e",
                  fallbackUserName: adminName,
                );

                FeedbackUtil.error();
              }
            },
            child: const Text("DELETE", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}