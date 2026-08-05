import 'package:cloud_firestore/cloud_firestore.dart';

class Complaint {
  final String id;
  final String raisedByUid;
  final String raisedByName;
  final String flatNo;
  final String title;
  final String description;
  final String status; // 'open', 'in_progress', 'resolved', 'closed'
  final String category;
  final DateTime createdAt;
  final String? adminNote;
  final List<String> photoUrls;

  Complaint({required this.id, required this.raisedByUid, required this.raisedByName,
    required this.flatNo, required this.title, required this.description,
    required this.status, required this.category, required this.createdAt, this.adminNote, this.photoUrls = const []});

  factory Complaint.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Complaint(
      id: doc.id, raisedByUid: d['raisedByUid'] ?? '', raisedByName: d['raisedByName'] ?? '',
      flatNo: d['flatNo'] ?? '', title: d['title'] ?? '', description: d['description'] ?? '',
      status: d['status'] ?? 'open', category: d['category'] ?? 'General',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      adminNote: d['adminNote'],
      photoUrls: List<String>.from(d['photoUrls'] ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
    'raisedByUid': raisedByUid, 'raisedByName': raisedByName, 'flatNo': flatNo,
    'title': title, 'description': description, 'status': status, 'category': category,
    'createdAt': Timestamp.fromDate(createdAt), 'adminNote': adminNote, 'photoUrls': photoUrls,
  };
}
