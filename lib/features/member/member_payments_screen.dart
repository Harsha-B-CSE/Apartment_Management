import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../shared/models/payment.dart';
import '../../shared/services/auth_provider.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/utils/feedback_util.dart';
import '../../shared/utils/crypto_ledger.dart';

class MemberPaymentsScreen extends StatelessWidget {
  const MemberPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: buildMemberAppBar(context, 'My Dues & Payments'),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('payments')
            .where('buildingId', isEqualTo: user.buildingId)
            .where('targetUid', isEqualTo: user.uid)
            .orderBy('dueDate', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text("Error: ${snap.error}"));
          if (!snap.hasData) return const LoadingList();

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const EmptyState(icon: Icons.check_circle_outline, title: 'All Caught Up!', subtitle: 'You have no pending maintenance dues.');
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (c, i) => const SizedBox(height: 12),
            itemBuilder: (c, i) {
              final payment = Payment.fromDoc(docs[i]);
              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(payment.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                          const SizedBox(width: 8),
                          Text('\$${payment.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Status: ${payment.status.toUpperCase()}', style: TextStyle(color: payment.status == 'pending' ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
                      if (payment.status == 'pending') ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity, height: 45,
                          child: ElevatedButton(
                            onPressed: () => _showPayModal(context, payment),
                            child: const Text('Mark as Paid / Enter Details'),
                          ),
                        )
                      ]
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showPayModal(BuildContext context, Payment payment) {
    final transId = TextEditingController();
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Submit Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          const Text('Please transfer the amount to your building management and enter the transaction ID below for verification.'),
          const SizedBox(height: 20),
          AppTextField(label: 'Transaction Reference ID', controller: transId),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: () async {
                if (transId.text.trim().isEmpty) return;
                FeedbackUtil.medium();
                try {
                  final hashData = {
                    'paymentId': payment.id,
                    'status': 'paid',
                    'transactionId': transId.text.trim(),
                    'amount': payment.amount,
                    'targetUid': payment.targetUid,
                  };
                  final cryptoHash = await CryptoLedger.generateTransactionHash(hashData);

                  await FirebaseFirestore.instance.collection('payments').doc(payment.id).update({
                    'status': 'paid',
                    'transactionId': transId.text.trim(),
                    'paidAt': Timestamp.now(),
                    'cryptographicHash': cryptoHash,
                  });
                  FeedbackUtil.success();
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  FeedbackUtil.error();
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Payment update failed: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Submit'),
            ),
          )
        ]),
      ),
    );
  }
}
