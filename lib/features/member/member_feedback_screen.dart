// lib/features/member/presentation/screens/member_feedback_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/theme.dart';
import '../../../shared/services/auth_provider.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback_util.dart';

class MemberFeedbackScreen extends StatefulWidget {
  const MemberFeedbackScreen({super.key});

  @override
  State<MemberFeedbackScreen> createState() => _MemberFeedbackScreenState();
}

class _MemberFeedbackScreenState extends State<MemberFeedbackScreen> {
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Building Feedback', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 0,
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFeedbackSheet(
          context,
          user.buildingId,
          user.name,
          user.uid,
          user.flatNo,
        ),
        backgroundColor: AppColors.primary,
        icon: const FaIcon(FontAwesomeIcons.pen, size: 14, color: Colors.white),
        label: const Text('Give Feedback', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('ratings')
            .where('buildingId', isEqualTo: user.buildingId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const LoadingList(count: 4);
          if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
            return const EmptyState(
              icon: FontAwesomeIcons.comments,
              title: 'No Feedback Yet',
              subtitle: 'Tap the button below to leave the first review!',
            );
          }

          final feedbackDocs = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: feedbackDocs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final data = feedbackDocs[index].data() as Map<String, dynamic>;
              final String reviewText = data['feedback'] ?? 'No text comment provided.';
              final double ratingValue = (data['rating'] ?? 0.0).toDouble();
              final String tenantName = data['tenantName'] ?? 'Anonymous Resident';
              final String displayedFlat = data['flatNo'] ?? 'N/A';
              final Timestamp? timestamp = data['createdAt'] as Timestamp?;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // ✅ Displaying the flat number inside the list view interface card
                        Text('$tenantName (Flat $displayedFlat)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        if (timestamp != null)
                          Text(
                            '${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: List.generate(5, (starIndex) {
                        return Icon(
                          starIndex < ratingValue ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 16,
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Text(reviewText, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.4)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showFeedbackSheet(BuildContext ctx, String buildingId, String tenantName, String tenantUid, String? initialFlatNo) {
    int localRating = 5;
    final feedbackController = TextEditingController();

    // ✅ ADDED: Flat number specific controller to capture or verify information
    final flatNoController = TextEditingController(text: (initialFlatNo != null && initialFlatNo != "N/A") ? initialFlatNo : "");
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Write a Review', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary)),
                const SizedBox(height: 16),

                // ⭐ Interactive Star Rating Selector Matrix
                const Text('Rating', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Row(
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < localRating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 32,
                      ),
                      onPressed: () {
                        FeedbackUtil.light();
                        setModalState(() => localRating = index + 1);
                      },
                    );
                  }),
                ),
                const SizedBox(height: 16),

                // 🏢 ADDED: Visual validation verification text field for the flat number asset
                AppTextField(
                  label: 'Flat / Unit Number',
                  hint: 'e.g. A-104, 5B',
                  controller: flatNoController,
                  validator: (v) => v!.trim().isEmpty ? 'Flat number assignment is required' : null,
                ),
                const SizedBox(height: 16),

                AppTextField(
                  label: 'Your Review',
                  hint: 'Share your experience living here...',
                  controller: feedbackController,
                  maxLines: 3,
                  validator: (v) => v!.isEmpty ? 'Please write your feedback comment' : null,
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      FeedbackUtil.medium();

                      try {
                        String realFlatNo = flatNoController.text.trim();

                        // Fallback lookup failsafe logic if the controller value was tampered with
                        if (realFlatNo.isEmpty) {
                          final freshUserDoc = await FirebaseFirestore.instance
                              .collection('users')
                              .doc(tenantUid)
                              .get();

                          if (freshUserDoc.exists) {
                            final userData = freshUserDoc.data() as Map<String, dynamic>?;
                            realFlatNo = userData?['flatNo'] ?? "N/A";
                          }
                        }

                        // Write to the ratings collection with absolute data integrity assurance
                        await FirebaseFirestore.instance.collection('ratings').add({
                          'buildingId': buildingId,
                          'tenantUid': tenantUid,
                          'tenantName': tenantName,
                          'flatNo': realFlatNo.toUpperCase(),
                          'rating': localRating,
                          'feedback': feedbackController.text.trim(),
                          'createdAt': FieldValue.serverTimestamp(),
                        });

                        FeedbackUtil.success();
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        FeedbackUtil.error();
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Submission rejected: $e'), backgroundColor: AppColors.danger),
                        );
                      }
                    },
                    child: const Text('Submit Feedback'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}