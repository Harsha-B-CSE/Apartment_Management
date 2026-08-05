// lib/features/admin/presentation/screens/admin_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme.dart';
import '../../shared/services/auth_provider.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/utils/feedback_util.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: buildAdminAppBar(context, 'Admin Dashboard'),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── 🏢 BUILDING ID HEADER WITH LIVE COPY & QR ONBOARDING ───
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppColors.primary.withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.business,
                        color: AppColors.primary, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "ASSIGNED WORKSPACE ID",
                            style: TextStyle(
                                fontSize: 9,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user.buildingId,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 0.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.copy_rounded,
                          color: AppColors.primary, size: 20),
                      tooltip: 'Copy Code String',
                      onPressed: () {
                        FeedbackUtil.success();
                        Clipboard.setData(ClipboardData(text: user.buildingId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text("Building Code copied to clipboard!"),
                              behavior: SnackBarBehavior.floating),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const FaIcon(FontAwesomeIcons.qrcode,
                          color: AppColors.primary, size: 18),
                      tooltip: 'Show Registration QR',
                      onPressed: () {
                        FeedbackUtil.medium();
                        _showTenantQrModal(context, user.buildingId);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const SectionHeader(title: "Operational Records"),
              const SizedBox(height: 12),

              // ✅ FIX: Enhanced Aspect Ratio (1.25) to provide more vertical padding for grid content
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.25,
                children: [
                  _AdminStatCard(
                    title: "Members",
                    collection: "users",
                    buildingId: user.buildingId,
                    icon: FontAwesomeIcons.users,
                    color: Colors.blue,
                    onTap: () {
                      FeedbackUtil.light();
                      context.push('/admin/members');
                    },
                  ),
                  _AdminStatCard(
                    title: "Complaints",
                    collection: "complaints",
                    buildingId: user.buildingId,
                    icon: FontAwesomeIcons.triangleExclamation,
                    color: Colors.orange,
                    onTap: () {
                      FeedbackUtil.light();
                      context.push('/admin/complaints');
                    },
                  ),
                  _AdminStatCard(
                    title: "Visitors",
                    collection: "visitors",
                    buildingId: user.buildingId,
                    icon: FontAwesomeIcons.userPlus,
                    color: Colors.green,
                    onTap: () {
                      FeedbackUtil.light();
                      context.push('/admin/visitors');
                    },
                  ),
                  _AdminStatCard(
                    title: "Parking Slots",
                    collection: "parking",
                    buildingId: user.buildingId,
                    icon: FontAwesomeIcons.p,
                    color: Colors.purple,
                    onTap: () {
                      FeedbackUtil.light();
                      context.push('/admin/parking');
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),
              // ✅ FIX: Cleaned and shortened section header to guarantee zero wrap overflow
              const SectionHeader(title: "System & Platform Management"),
              const SizedBox(height: 12),

              ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _ManagementRowTile(
                    title: "System Audit Logs",
                    subtitle: "Track historical tenant entry actions",
                    icon: Icons.lock_clock_rounded,
                    color: Colors.blueGrey,
                    onTap: () {
                      FeedbackUtil.light();
                      context.push('/admin/audit');
                    },
                  ),
                  const SizedBox(height: 10),
                  _ManagementRowTile(
                    title: "Analytical Dashboards",
                    subtitle: "View community data projections",
                    icon: Icons.analytics_outlined,
                    color: Colors.teal,
                    onTap: () {
                      FeedbackUtil.light();
                      context.push('/admin/analytics');
                    },
                  ),
                  const SizedBox(height: 10),
                  _ManagementRowTile(
                    title: "Performance Metrics & KPIs",
                    subtitle: "Track incident response delays",
                    icon: Icons.speed_rounded,
                    color: Colors.indigo,
                    onTap: () {
                      FeedbackUtil.light();
                      context.push('/admin/performance');
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),
              const SectionHeader(title: "Infrastructure Overview"),
              const SizedBox(height: 12),
              _BuildingCapacityCard(buildingId: user.buildingId),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showTenantQrModal(BuildContext context, String buildingId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text("Onboard New Residents",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 6),
            const Text(
                "Tenants scan this code using their phone during registration to link automatically to this building.",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 24),
            QrImageView(
              data: buildingId,
              version: QrVersions.auto,
              size: 180.0,
              gapless: false,
              foregroundColor: AppColors.textPrimary,
            ),
            const SizedBox(height: 16),
            Text("Building Token: $buildingId",
                style: const TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 11,
                    color: AppColors.textHint,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _ManagementRowTile extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ManagementRowTile(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        onTap: onTap,
        dense: true, // ✅ FIX: Tights padding inner dimensions safely
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle,
            style:
                const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.arrow_forward_ios_rounded,
            size: 12, color: AppColors.textHint),
      ),
    );
  }
}

class _AdminStatCard extends StatelessWidget {
  final String title, collection, buildingId;
  final dynamic icon;
  final Color color;
  final VoidCallback onTap;
  final Map<String, dynamic>? where;

  const _AdminStatCard({
    required this.title,
    required this.collection,
    required this.buildingId,
    required this.icon,
    required this.color,
    required this.onTap,
    this.where,
  });

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance
        .collection(collection)
        .where('buildingId', isEqualTo: buildingId);
    if (where != null) {
      where!
          .forEach((key, value) => query = query.where(key, isEqualTo: value));
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.15)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              icon is IconData
                  ? Icon(icon, color: color, size: 22)
                  : FaIcon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              StreamBuilder<QuerySnapshot>(
                stream: query.snapshots(),
                builder: (context, snap) {
                  if (snap.hasError)
                    return const Text("!",
                        style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold));
                  final count = snap.hasData ? snap.data!.docs.length : 0;
                  return Text("$count",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: color));
                },
              ),
              const SizedBox(height: 2),
              // ✅ FIX: Rigid containment parameters to guard text dimensions
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                      fontSize: 11,
                      color: color.withOpacity(0.9),
                      fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BuildingCapacityCard extends StatelessWidget {
  final String buildingId;
  const _BuildingCapacityCard({required this.buildingId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('buildings')
          .doc(buildingId)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError)
          return const Text("Permission Error or Loading...",
              style: TextStyle(fontSize: 12, color: Colors.red));
        if (!snap.hasData || !snap.data!.exists) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.1))),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey, size: 20),
                SizedBox(width: 12),
                Expanded(
                    child: Text("Building document not found.",
                        style: TextStyle(color: Colors.grey, fontSize: 12))),
              ],
            ),
          );
        }

        final data = snap.data!.data() as Map<String, dynamic>;
        return Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppColors.border)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const CircleAvatar(
                      backgroundColor: AppColors.primary,
                      child:
                          Icon(Icons.business, color: Colors.white, size: 18)),
                  title: Text(data['name'] ?? 'Building Info',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(data['address'] ?? 'No address',
                      style: const TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.layers,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        const Text("Floors: ",
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textSecondary)),
                        Text("${data['totalFloors'] ?? 0}",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.door_front_door,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        const Text("Flats: ",
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textSecondary)),
                        Text("${data['totalFlats'] ?? 0}",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
