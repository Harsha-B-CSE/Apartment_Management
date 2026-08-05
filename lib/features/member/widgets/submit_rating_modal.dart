// lib/features/member/widgets/submit_rating_modal.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme.dart';
import '../../../shared/utils/feedback_util.dart';
import '../../../shared/widgets/app_widgets.dart';

class SubmitRatingModal extends StatefulWidget {
  final String buildingId;
  final String tenantUid;
  final String tenantName;
  final String flatNo;

  const SubmitRatingModal({
    super.key,
    required this.buildingId,
    required this.tenantUid,
    required this.tenantName,
    required this.flatNo,
  });

  @override
  State<SubmitRatingModal> createState() => _SubmitRatingModalState();
}

class _SubmitRatingModalState extends State<SubmitRatingModal> {
  int _ratingScore = 5;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Rate Building Management", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starValue = index + 1;
              return IconButton(
                icon: Icon(
                  Icons.star,
                  size: 32,
                  color: starValue <= _ratingScore ? Colors.amber : Colors.grey[300],
                ),
                onPressed: () {
                  FeedbackUtil.light();
                  setState(() => _ratingScore = starValue);
                },
              );
            }),
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: "Comments & Feedback",
            hint: "Let management know how they are doing...",
            controller: _commentCtrl,
            maxLines: 3,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _submitting ? null : _executeSubmission,
              child: _submitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("SUBMIT FEEDBACK"),
            ),
          )
        ],
      ),
    );
  }

  void _executeSubmission() async {
    if (_commentCtrl.text.trim().isEmpty) {
      FeedbackUtil.error();
      return;
    }
    FeedbackUtil.medium();
    setState(() => _submitting = true);

    try {
      await FirebaseFirestore.instance.collection('ratings').add({
        'timestamp': FieldValue.serverTimestamp(),
        'buildingId': widget.buildingId,
        'tenantUid': widget.tenantUid,
        'tenantName': widget.tenantName,
        'flatNo': widget.flatNo,
        'ratingScore': _ratingScore.toDouble(),
        'feedbackComment': _commentCtrl.text.trim(),
      });

      FeedbackUtil.success();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      FeedbackUtil.error();
      setState(() => _submitting = false);
    }
  }
}