import 'package:cloud_firestore/cloud_firestore.dart';

class Visitor {
  final String id;
  final String flatNo;
  final String memberName;
  final String visitorName;
  final String purpose;
  final String phone;
  final DateTime entryTime;
  final DateTime? exitTime;
  final String status; // 'expected', 'entered', 'exited'

  Visitor({required this.id, required this.flatNo, required this.memberName,
    required this.visitorName, required this.purpose, required this.phone,
    required this.entryTime, this.exitTime, required this.status});

  factory Visitor.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return Visitor(
      id: doc.id, 
      flatNo: d['flatNo'] ?? '', 
      memberName: d['memberName'] ?? '',
      visitorName: d['visitorName'] ?? 'Guest', 
      purpose: d['purpose'] ?? 'Visit',
      phone: d['phone'] ?? 'N/A',
      entryTime: (d['entryTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      exitTime: (d['exitTime'] as Timestamp?)?.toDate(), 
      status: d['status'] ?? 'expected',
    );
  }

  Map<String, dynamic> toMap() => {
    'flatNo': flatNo, 'memberName': memberName, 'visitorName': visitorName,
    'purpose': purpose, 'phone': phone, 'entryTime': Timestamp.fromDate(entryTime),
    'exitTime': exitTime != null ? Timestamp.fromDate(exitTime!) : null, 'status': status,
  };
}
