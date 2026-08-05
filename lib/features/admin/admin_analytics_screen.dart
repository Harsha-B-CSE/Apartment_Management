// lib/features/admin/screens/admin_analytics_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/theme.dart';
import '../../../shared/services/auth_provider.dart';
import '../../../shared/utils/feedback_util.dart';
import '../../../shared/widgets/app_widgets.dart';

enum AnalyticsFilter { specificDate, dateRange, week, month, year }

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  AnalyticsFilter _selectedFilter = AnalyticsFilter.month;
  DateTime _targetDate = DateTime.now();
  DateTimeRange? _customRange;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: buildAdminAppBar(context, 'Business Analytics'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFilterRow(),
            const SizedBox(height: 20),
            _buildRealtimeDataStream(user.buildingId),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: AnalyticsFilter.values.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter.name.toUpperCase(), style: const TextStyle(fontSize: 11)),
              selected: isSelected,
              selectedColor: AppColors.primary.withOpacity(0.15),
              checkmarkColor: AppColors.primary,
              onSelected: (_) {
                FeedbackUtil.light();
                setState(() => _selectedFilter = filter);
                if (filter == AnalyticsFilter.dateRange) {
                  _triggerRangePicker();
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  void _triggerRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _customRange = picked);
    }
  }

  Widget _buildRealtimeDataStream(String buildingId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('service_requests')
          .where('buildingId', isEqualTo: buildingId)
          .snapshots(),
      builder: (context, requestsSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('complaints')
              .where('buildingId', isEqualTo: buildingId)
              .snapshots(),
          builder: (context, complaintsSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('visitors')
                  .where('buildingId', isEqualTo: buildingId)
                  .snapshots(),
              builder: (context, visitorsSnap) {
                if (!requestsSnap.hasData || !complaintsSnap.hasData || !visitorsSnap.hasData) {
                  return const LoadingList(count: 3);
                }

                // Client-side execution of timeline filters based on selection criteria
                final reqDocs = _applyTemporalFilters(requestsSnap.data!.docs);
                final compDocs = _applyTemporalFilters(complaintsSnap.data!.docs);
                final visDocs = _applyTemporalFilters(visitorsSnap.data!.docs);

                int completedReq = reqDocs.where((d) => d['status'] == 'completed').length;
                int pendingReq = reqDocs.where((d) => d['status'] == 'pending').length;
                int resolvedComp = compDocs.where((d) => d['status'] == 'resolved' || d['status'] == 'closed').length;
                int visitorApproved = visDocs.where((d) => d['status'] == 'entered').length;

                return Column(
                  children: [
                    _buildTrendDashboard(completedReq, pendingReq, resolvedComp, visitorApproved),
                    const SizedBox(height: 24),
                    _buildVisualChartModule(completedReq, pendingReq, resolvedComp, visitorApproved),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  List<DocumentSnapshot> _applyTemporalFilters(List<DocumentSnapshot> docs) {
    final now = DateTime.now();
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null || !data.containsKey('createdAt') && !data.containsKey('entryTime')) return false;

      final timestamp = data['createdAt'] ?? data['entryTime'];
      if (timestamp == null) return false;

      final date = (timestamp as Timestamp).toDate();

      switch (_selectedFilter) {
        case AnalyticsFilter.specificDate:
          return date.year == _targetDate.year && date.month == _targetDate.month && date.day == _targetDate.day;
        case AnalyticsFilter.dateRange:
          if (_customRange == null) return true;
          return date.isAfter(_customRange!.start) && date.isBefore(_customRange!.end.add(const Duration(days: 1)));
        case AnalyticsFilter.week:
          return now.difference(date).inDays <= 7;
        case AnalyticsFilter.month:
          return date.year == now.year && date.month == now.month;
        case AnalyticsFilter.year:
          return date.year == now.year;
      }
    }).toList();
  }

  Widget _buildTrendDashboard(int compReq, int penReq, int resComp, int visApp) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _buildStatTile("Completed Req", compReq.toString(), Icons.check_circle, Colors.green, "+12%"),
        _buildStatTile("Pending Req", penReq.toString(), Icons.hourglass_empty, Colors.orange, "-4%"),
        _buildStatTile("Resolved Comp", resComp.toString(), Icons.gavel, Colors.blue, "+18%"),
        _buildStatTile("Approved Vis", visApp.toString(), Icons.vpn_key, Colors.purple, "+8%"),
      ],
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon, Color color, String shift) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(shift, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildVisualChartModule(int cReq, int pReq, int rComp, int vApp) {
    double total = (cReq + pReq + rComp + vApp).toDouble();
    if (total == 0) total = 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Distribution Metrics", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: CustomPaint(
              size: Size.infinite,
              painter: PurePiePainter(
                slices: [
                  PieSlice(cReq.toDouble() / total, Colors.green),
                  PieSlice(pReq.toDouble() / total, Colors.orange),
                  PieSlice(rComp.toDouble() / total, Colors.blue),
                  PieSlice(vApp.toDouble() / total, Colors.purple),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildLegendRow(),
        ],
      ),
    );
  }

  Widget _buildLegendRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _legendItem("Completed", Colors.green),
        _legendItem("Pending", Colors.orange),
        _legendItem("Resolved", Colors.blue),
        _legendItem("Visitors", Colors.purple),
      ],
    );
  }

  Widget _legendItem(String text, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }
}

class PieSlice {
  final double percentage;
  final Color color;
  PieSlice(this.percentage, this.color);
}

class PurePiePainter extends CustomPainter {
  final List<PieSlice> slices;
  PurePiePainter({required this.slices});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.height / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    double startAngle = -3.141592653589793 / 2;

    for (var slice in slices) {
      if (slice.percentage == 0) continue;
      final sweepAngle = slice.percentage * 2 * 3.141592653589793;
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.fill;

      canvas.drawArc(rect, startAngle, sweepAngle, true, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}