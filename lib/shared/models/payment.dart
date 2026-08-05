import 'package:cloud_firestore/cloud_firestore.dart';

class Payment {
  final String id;
  final String buildingId;
  final String title; // e.g. "June 2026 Maintenance"
  final double amount;
  final String targetUid; // User this due is generated for
  final String flatNo;
  final String status; // 'pending', 'paid', 'verified'
  final DateTime dueDate;
  final DateTime? paidAt;
  final String? receiptUrl; // User can upload a receipt or screenshot
  final String? transactionId;
  final String? cryptographicHash; // Fraud-proof ledger hash

  Payment({
    required this.id,
    required this.buildingId,
    required this.title,
    required this.amount,
    required this.targetUid,
    required this.flatNo,
    required this.status,
    required this.dueDate,
    this.paidAt,
    this.receiptUrl,
    this.transactionId,
    this.cryptographicHash,
  });

  factory Payment.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Payment(
      id: doc.id,
      buildingId: d['buildingId'] ?? '',
      title: d['title'] ?? 'Maintenance Due',
      amount: (d['amount'] ?? 0.0).toDouble(),
      targetUid: d['targetUid'] ?? '',
      flatNo: d['flatNo'] ?? '',
      status: d['status'] ?? 'pending',
      dueDate: (d['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      paidAt: (d['paidAt'] as Timestamp?)?.toDate(),
      receiptUrl: d['receiptUrl'],
      transactionId: d['transactionId'],
      cryptographicHash: d['cryptographicHash'],
    );
  }

  Map<String, dynamic> toMap() => {
    'buildingId': buildingId,
    'title': title,
    'amount': amount,
    'targetUid': targetUid,
    'flatNo': flatNo,
    'status': status,
    'dueDate': Timestamp.fromDate(dueDate),
    'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
    'receiptUrl': receiptUrl,
    'transactionId': transactionId,
    'cryptographicHash': cryptographicHash,
  };
}
