// lib/features/member/presentation/screens/member_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/theme.dart';
import '../../shared/services/auth_provider.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/utils/feedback_util.dart'; // ⚡ Import the unified haptics utility

class MemberDashboardScreen extends StatelessWidget {
  const MemberDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
      },
      child: Scaffold(
        appBar: buildMemberAppBar(context, 'My Dashboard'),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _WelcomeCard(name: user.name, flat: user.flatNo),
            const SizedBox(height: 24),

            const SectionHeader(title: 'Quick Actions'),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.6,
              children: [
                _QuickAction(
                  icon: FontAwesomeIcons.triangleExclamation,
                  label: 'Raise Complaint',
                  color: AppColors.warning,
                  onTap: () {
                    FeedbackUtil.light(); // ⚡ Dynamic card navigation micro-tap feel
                    context.push('/member/complaints');
                  },
                ),
                _QuickAction(
                  icon: FontAwesomeIcons.personWalkingArrowRight,
                  label: 'Add Visitor',
                  color: AppColors.success,
                  onTap: () {
                    FeedbackUtil.light(); // ⚡ Dynamic card navigation micro-tap feel
                    context.push('/member/visitors');
                  },
                ),
                _QuickAction(
                  icon: FontAwesomeIcons.clipboardList,
                  label: 'Request Service',
                  color: AppColors.info,
                  onTap: () {
                    FeedbackUtil.light(); // ⚡ Dynamic card navigation micro-tap feel
                    context.push('/member/service-requests');
                  },
                ),
                _QuickAction(
                  icon: FontAwesomeIcons.squareParking,
                  label: 'My Parking',
                  color: AppColors.accent,
                  onTap: () {
                    FeedbackUtil.light(); // ⚡ Dynamic card navigation micro-tap feel
                    context.push('/member/parking');
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            SectionHeader(
              title: 'Recent Complaints',
              actionLabel: 'View all',
              onAction: () {
                FeedbackUtil.light(); // ⚡ Clean link interaction response trigger
                context.push('/member/complaints');
              },
            ),
            const SizedBox(height: 12),
            _DashboardComplaints(uid: user.uid, buildingId: user.buildingId),
          ]),
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  final String name;
  final String? flat;
  const _WelcomeCard({required this.name, this.flat});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        CircleAvatar(
          backgroundColor: Colors.white24,
          radius: 24,
          child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 15),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hi, ${name.split(' ')[0]}!', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(flat != null ? 'Flat $flat' : 'Resident', style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ]),
      ],),
    );
  }
}

class _QuickAction extends StatelessWidget {
  // ✅ FIXED: Converted to dynamic parameter to cleanly accept both Material IconData and FontAwesome FaIconData indicators
  final dynamic icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              // ✅ FIXED: Safely unwraps the dynamic icon runtime object type signature
              icon is IconData
                  ? Icon(icon, color: color, size: 18)
                  : FaIcon(icon, color: color, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color))),
            ]),
          ),
        ),
      ),
    );
  }
}

class _DashboardComplaints extends StatelessWidget {
  final String uid;
  final String buildingId;
  const _DashboardComplaints({required this.uid, required this.buildingId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('complaints')
          .where('buildingId', isEqualTo: buildingId)
          .where('raisedByUid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Text("Error: ${snap.error}", style: const TextStyle(color: Colors.red, fontSize: 10));
        }
        if (snap.connectionState == ConnectionState.waiting) return const LoadingList(count: 2);

        if (!snap.hasData || snap.data!.docs.isEmpty) return const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Text("No recent complaints.", style: TextStyle(color: AppColors.textSecondary)),
        );

        return Column(
          children: snap.data!.docs.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  FeedbackUtil.light();
                },
                child: ListTile(
                  title: Text(d['title'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  trailing: StatusBadge(d['status'] ?? 'open'),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}