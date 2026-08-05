// lib/features/notifications/presentation/screens/notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../shared/models/notification_model.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/services/notification_service.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/utils/feedback_util.dart'; // ⚡ Import the unified haptics utility

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: AuthService().getCurrentAppUser(),
      builder: (context, snap) {
        if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final user = snap.data!;
        final isAdmin = user.role == 'admin';

        return Scaffold(
          appBar: AppBar(
            title: const Text('Notifications'),
            leading: Builder(builder: (ctx) => IconButton(
              icon: const FaIcon(FontAwesomeIcons.bars, size: 18),
              onPressed: () {
                FeedbackUtil.light(); // ⚡ Dynamic structural sidebar draw tap feel
                Scaffold.of(ctx).openDrawer();
              },
            )),
            actions: isAdmin ? [
              TextButton.icon(
                onPressed: () {
                  FeedbackUtil.light(); // ⚡ Provide smooth micro-interaction response on launch
                  _showBroadcastDialog(context);
                },
                icon: const FaIcon(FontAwesomeIcons.bullhorn, size: 13),
                label: const Text('Broadcast'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ] : null,
            bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('notifications')
                .where('targetUid', isEqualTo: user.uid)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const LoadingList();
              if (snap.data!.docs.isEmpty){ return const EmptyState(
                icon: FontAwesomeIcons.bell,
                title: 'No Notifications',
                subtitle: 'You\'re all caught up! Nothing new to see.',
              );}
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: snap.data!.docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final n = AppNotification.fromDoc(snap.data!.docs[i]);
                  return _NotifCard(n, onTap: () {
                    FeedbackUtil.light(); // ⚡ Immediate feedback when reading a notice card
                    if (!n.isRead) FirestoreService().update('notifications', n.id, {'isRead': true});
                  });
                },
              );
            },
          ),
        );
      },
    );
  }

  void _showBroadcastDialog(BuildContext context) {
    final title = TextEditingController();
    final body = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Send Broadcast', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          const Text('This will notify all members.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),
          AppTextField(label: 'Title', hint: 'e.g. Maintenance Notice', controller: title, validator: (v) => v!.isEmpty ? 'Required' : null),
          const SizedBox(height: 14),
          AppTextField(label: 'Message', hint: 'Write your announcement...', controller: body, maxLines: 4, validator: (v) => v!.isEmpty ? 'Required' : null),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) {
                  FeedbackUtil.error(); // ⚡ Incomplete text inputs error notification trigger
                  return;
                }

                // ⚡ Medium impact gives distinct functional click confirmation
                FeedbackUtil.medium();

                try {
                  // Get all members and send to each
                  final members = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'member').get();
                  for (final m in members.docs) {
                    await NotificationService.sendNotification(
                      title: title.text, body: body.text,
                      type: 'general', targetUid: m.id,
                    );
                  }

                  // ⚡ Dynamic transmission complete success ripple pulse
                  FeedbackUtil.success();

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Broadcast sent to ${members.docs.length} members'), backgroundColor: AppColors.success),
                    );
                  }
                } catch (e) {
                  FeedbackUtil.error(); // ⚡ Operational network crash error catch block
                }
              },
              child: const Text('Send Broadcast'),
            ),
          ),
        ])),
      ),
    );
  }
}

class _NotifCard extends StatelessWidget {
  final AppNotification notif;
  final VoidCallback onTap;
  const _NotifCard(this.notif, {required this.onTap});

  static const _typeIcons = {
    'complaint': FontAwesomeIcons.triangleExclamation,
    'visitor': FontAwesomeIcons.person,
    'service': FontAwesomeIcons.screwdriverWrench,
    'general': FontAwesomeIcons.bullhorn,
  };

  static const _typeColors = {
    'complaint': AppColors.warning,
    'visitor': AppColors.success,
    'service': AppColors.info,
    'general': AppColors.accent,
  };

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM, hh:mm a');
    final color = _typeColors[notif.type] ?? AppColors.accent;
    final icon = _typeIcons[notif.type] ?? FontAwesomeIcons.bell;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notif.isRead ? AppColors.surface : color.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: notif.isRead ? AppColors.border : color.withOpacity(0.25)),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Center(child: FaIcon(icon, color: color, size: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(notif.title,
                  style: TextStyle(fontWeight: notif.isRead ? FontWeight.w500 : FontWeight.w700, fontSize: 13))),
              if (!notif.isRead)
                Container(width: 8, height: 8,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            ]),
            const SizedBox(height: 3),
            Text(notif.body, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 4),
            Text(fmt.format(notif.createdAt), style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
          ])),
        ]),
      ),
    );
  }
}