// lib/features/admin/widgets/rating_history_dialog.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme.dart';

class RatingHistoryDialog extends StatelessWidget {
  final List<DocumentSnapshot> ratingDocs;
  const RatingHistoryDialog({super.key, required this.ratingDocs});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Tenant Reviews Matrix", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: AppColors.surface,
      content: SizedBox(
        width: double.maxFinite,
        height: 350,
        child: ratingDocs.isEmpty
            ? const Center(child: Text("No systemic tenant reviews reported yet.", style: TextStyle(color: AppColors.textSecondary)))
            : ListView.builder(
          itemCount: ratingDocs.length,
          itemBuilder: (context, index) {
            final data = ratingDocs[index].data() as Map<String, dynamic>;

            // ✅ FIXED: Support all possible fallback case variations for the numeric scores
            final num scoreValue = data['rating'] ?? data['ratingscore'] ?? data['ratingScore'] ?? 0.0;
            final double score = scoreValue.toDouble();

            // ✅ FIXED: Support 'flatNo' properties if mapped from the user entity context elsewhere
            final String flatNo = data['flatNo'] ?? 'N/A';

            // ✅ FIXED: Unified comment text extraction to catch 'feedback' securely from your submission form layout
            final String commentText = data['feedback'] ??
                data['comment'] ??
                data['feedbackComment'] ??
                'No text comment provided.';

            return Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(data['tenantName'] ?? 'Anonymous Tenant', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      Row(
                        children: List.generate(5, (i) => Icon(
                          Icons.star,
                          size: 12,
                          color: i < score ? Colors.amber : Colors.grey[300],
                        )),
                      )
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      "Flat $flatNo \nComment: $commentText",
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                    ),
                  ),
                ),
                const Divider(color: AppColors.border),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("CLOSE MATRIX", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
        )
      ],
    );
  }
}