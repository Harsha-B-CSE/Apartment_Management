import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type; // 'complaint', 'visitor', 'service', 'general'
  final String? targetUid; // null = broadcast to all
  final bool isRead;
  final DateTime createdAt;

  AppNotification({required this.id, required this.title, required this.body,
    required this.type, this.targetUid, required this.isRead, required this.createdAt});

  factory AppNotification.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id, title: d['title'] ?? '', body: d['body'] ?? '',
      type: d['type'] ?? 'general', targetUid: d['targetUid'],
      isRead: d['isRead'] ?? false, createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title, 'body': body, 'type': type, 'targetUid': targetUid,
    'isRead': isRead, 'createdAt': Timestamp.fromDate(createdAt),
  };
}
