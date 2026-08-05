import 'package:cloud_firestore/cloud_firestore.dart';

class Service {
  final String id;
  final String name;
  final String description;
  final bool isActive;
  final String category;
  final double cost;

  Service({required this.id, required this.name, required this.description, required this.isActive, required this.category, required this.cost});

  factory Service.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Service(id: doc.id, name: d['name'] ?? '', description: d['description'] ?? '',
      isActive: d['isActive'] ?? true, category: d['category'] ?? 'General', cost: (d['cost'] ?? 0.0).toDouble());
  }

  Map<String, dynamic> toMap() => {'name': name, 'description': description, 'isActive': isActive, 'category': category, 'cost': cost};
}

class ServiceRequest {
  final String id;
  final String memberUid;
  final String memberName;
  final String flatNo;
  final String serviceId;
  final String serviceName;
  final String status; // 'pending', 'in_progress', 'completed', 'rejected'
  final String notes;
  final DateTime createdAt;
  final String? adminNote;

  ServiceRequest({required this.id, required this.memberUid, required this.memberName,
    required this.flatNo, required this.serviceId, required this.serviceName,
    required this.status, required this.notes, required this.createdAt, this.adminNote});

  factory ServiceRequest.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ServiceRequest(
      id: doc.id, memberUid: d['memberUid'] ?? '', memberName: d['memberName'] ?? '',
      flatNo: d['flatNo'] ?? '', serviceId: d['serviceId'] ?? '', serviceName: d['serviceName'] ?? '',
      status: d['status'] ?? 'pending', notes: d['notes'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(), adminNote: d['adminNote'],
    );
  }

  Map<String, dynamic> toMap() => {
    'memberUid': memberUid, 'memberName': memberName, 'flatNo': flatNo,
    'serviceId': serviceId, 'serviceName': serviceName, 'status': status,
    'notes': notes, 'createdAt': Timestamp.fromDate(createdAt), 'adminNote': adminNote,
  };
}
