import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../shared/models/payment.dart';
import '../../shared/services/auth_provider.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/utils/feedback_util.dart';
import '../../shared/utils/crypto_ledger.dart';

class AdminPaymentsScreen extends StatefulWidget {
  const AdminPaymentsScreen({super.key});

  @override
  State<AdminPaymentsScreen> createState() => _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends State<AdminPaymentsScreen> {
  final _db = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: buildAdminAppBar(context, 'Maintenance & Payments'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDue(context, user.buildingId),
        label: const Text('Add Due'),
        icon: const Icon(Icons.add),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('payments')
            .where('buildingId', isEqualTo: user.buildingId)
            .orderBy('dueDate', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text("Error: ${snap.error}"));
          if (!snap.hasData) return const LoadingList();

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const EmptyState(icon: Icons.receipt_long, title: 'No Payments', subtitle: 'No maintenance dues have been recorded yet.');
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (c, i) => const SizedBox(height: 12),
            itemBuilder: (c, i) {
              final payment = Payment.fromDoc(docs[i]);
              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  title: Text(payment.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Flat ${payment.flatNo} • \$${payment.amount.toStringAsFixed(2)}'),
                  trailing: _buildStatusChip(payment.status),
                  onTap: () => _showPaymentDetails(context, payment),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch(status) {
      case 'paid': color = Colors.blue; break;
      case 'verified': color = Colors.green; break;
      default: color = Colors.orange;
    }
    return Chip(
      label: Text(status.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
    );
  }

  void _showAddDue(BuildContext context, String buildingId) {
    final title = TextEditingController();
    final amount = TextEditingController();
    final flatNo = TextEditingController(); // In real app, you might pick from a list
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Add Maintenance Due', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            AppTextField(label: 'Title (e.g. June Maintenance)', controller: title, validator: (v) => v!.isEmpty ? 'Required' : null),
            const SizedBox(height: 15),
            AppTextField(label: 'Amount (\$)', controller: amount, validator: (v) => v!.isEmpty ? 'Required' : null, keyboardType: TextInputType.number),
            const SizedBox(height: 15),
            AppTextField(label: 'Flat Number', controller: flatNo, validator: (v) => v!.isEmpty ? 'Required' : null),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    FeedbackUtil.medium();
                    // Let's resolve the user for this flat
                    final users = await FirebaseFirestore.instance.collection('users').where('buildingId', isEqualTo: buildingId).where('flatNo', isEqualTo: flatNo.text.trim()).limit(1).get();
                    if (users.docs.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No user found for this flat!')));
                      return;
                    }
                    final targetUid = users.docs.first.id;

                    final hashData = {
                      'buildingId': buildingId,
                      'title': title.text.trim(),
                      'amount': double.tryParse(amount.text.trim()) ?? 0.0,
                      'targetUid': targetUid,
                      'flatNo': flatNo.text.trim(),
                      'status': 'pending',
                    };
                    final cryptoHash = await CryptoLedger.generateTransactionHash(hashData);

                    await FirebaseFirestore.instance.collection('payments').add({
                      ...hashData,
                      'dueDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
                      'cryptographicHash': cryptoHash,
                    });
                    FeedbackUtil.success();
                    if (ctx.mounted) Navigator.pop(ctx);
                  }
                },
                child: const Text('Add Due'),
              ),
            )
          ]),
        ),
      ),
    );
  }

  void _showPaymentDetails(BuildContext context, Payment payment) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(payment.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text('Flat: ${payment.flatNo}'),
          Text('Amount: \$${payment.amount.toStringAsFixed(2)}'),
          Text('Status: ${payment.status.toUpperCase()}'),
          if (payment.transactionId != null) Text('Transaction ID: ${payment.transactionId}'),
          if (payment.status == 'verified' && payment.cryptographicHash != null) ...[
            const SizedBox(height: 10),
            const Text('Blockchain Signature (SHA-256):', style: TextStyle(fontSize: 12, color: Colors.grey)),
            Text(payment.cryptographicHash!, style: const TextStyle(fontSize: 10, color: Colors.blueGrey, fontFamily: 'monospace')),
          ],
          const SizedBox(height: 20),
          if (payment.status == 'paid')
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                onPressed: () async {
                  // Pop modal immediately to prevent double-clicks and async context issues
                  if (ctx.mounted) Navigator.pop(ctx);
                  
                  final hashData = {
                    'paymentId': payment.id,
                    'status': 'verified',
                    'transactionId': payment.transactionId,
                    'amount': payment.amount,
                    'targetUid': payment.targetUid,
                  };
                  final cryptoHash = await CryptoLedger.generateTransactionHash(hashData);

                  await FirebaseFirestore.instance.collection('payments').doc(payment.id).update({
                    'status': 'verified',
                    'cryptographicHash': cryptoHash,
                  });
                  FeedbackUtil.success();
                },
                child: const Text('Verify Payment'),
              ),
            )
        ]),
      ),
    );
  }
}
