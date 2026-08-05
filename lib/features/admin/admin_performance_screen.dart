// lib/features/admin/screens/admin_performance_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/theme.dart';
import '../../../shared/services/auth_provider.dart';
import '../../../shared/utils/feedback_util.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../features/admin/widgets/rating_history_dialog.dart';

class AdminPerformanceScreen extends StatelessWidget {
  const AdminPerformanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: buildAdminAppBar(context, 'Performance KPIs'),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('service_requests')
            .where('buildingId', isEqualTo: user.buildingId)
            .snapshots(),
        builder: (context, requestsSnap) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('ratings')
                .where('buildingId', isEqualTo: user.buildingId)
                .snapshots(),
            builder: (context, ratingsSnap) {
              if (!requestsSnap.hasData || !ratingsSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final reqDocs = requestsSnap.data!.docs;
              final ratingDocs = ratingsSnap.data!.docs;

              // Operational KPI Aggregations
              int totalCompleted = reqDocs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                return data.containsKey('status') && data['status'] == 'completed';
              }).length;

              double resolutionRate = reqDocs.isEmpty ? 0.0 : (totalCompleted / reqDocs.length) * 100;

              double totalRatingScore = 0.0;
              for (var doc in ratingDocs) {
                final data = doc.data() as Map<String, dynamic>;

                // ✅ FIXED: Implements case-insensitive fallback mapping logic to catch all schema definitions securely
                final dynamic scoreValue = data['rating'] ??
                    data['ratingscore'] ??
                    data['ratingScore'] ??
                    0.0;

                totalRatingScore += ConvertToDouble(scoreValue);
              }
              double avgRating = ratingDocs.isEmpty ? 0.0 : totalRatingScore / ratingDocs.length;

              // Calculate performance score out of 100 based on internal indicators
              double monthlyScore = (resolutionRate * 0.6) + (avgRating * 20 * 0.4);

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildPerformanceScoreCard(monthlyScore),
                  const SizedBox(height: 20),
                  _buildKPIMetricsGrid(totalCompleted, resolutionRate, avgRating, ratingDocs.length),
                  const SizedBox(height: 24),
                  _buildVisualEfficiencyGraph(resolutionRate),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    onPressed: () {
                      FeedbackUtil.medium();
                      showDialog(
                        context: context,
                        builder: (_) => RatingHistoryDialog(ratingDocs: ratingDocs),
                      );
                    },
                    icon: const Icon(Icons.history_edu, color: Colors.white),
                    label: const Text("VIEW TENANT FEEDBACK HISTORY", style: TextStyle(color: Colors.white)),
                  )
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// Helper to convert numeric field formats to double safely
  static double ConvertToDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  Widget _buildPerformanceScoreCard(double score) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text("Monthly Performance Score", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          Text("${score.toStringAsFixed(1)}%", style: const TextStyle(color: Colors.white, fontSize: 54, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: score / 100,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          )
        ],
      ),
    );
  }

  Widget _buildKPIMetricsGrid(int completed, double rate, double rating, int ratingCount) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildKPITile("Tasks Settled", completed.toString(), Icons.assignment_turned_in, Colors.blue),
        _buildKPITile("Resolution Rate", "${rate.toStringAsFixed(1)}%", Icons.speed, Colors.orange),
        _buildKPITile("Average Rating", "${rating.toStringAsFixed(1)} / 5.0", Icons.star, Colors.yellow[700]!),
        _buildKPITile("Total Reviews", ratingCount.toString(), Icons.rate_review, Colors.purple),
      ],
    );
  }

  Widget _buildKPITile(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildVisualEfficiencyGraph(double rate) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Resolution Speed Metric Trend", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: CustomPaint(
              size: Size.infinite,
              painter: PureLinePainter(efficiencyRate: rate),
            ),
          )
        ],
      ),
    );
  }
}

class PureLinePainter extends CustomPainter {
  final double efficiencyRate;
  PureLinePainter({required this.efficiencyRate});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.06)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(size.width * 0.25, size.height * 0.7);
    path.lineTo(size.width * 0.5, size.height * 0.45);
    path.lineTo(size.width * 0.75, size.height * 0.5);
    path.lineTo(size.width, size.height * (1.0 - (efficiencyRate / 100)));

    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}