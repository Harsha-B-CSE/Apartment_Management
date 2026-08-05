// lib/shared/models/flat.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Flat {
  final String id;
  final String flatNo;
  final String buildingId;
  final String buildingName;
  final int floor;
  final String type; // '1BHK', '2BHK', '3BHK'
  final double area;
  final String status; // 'occupied', 'vacant'
  final String? memberUid;
  final String? memberName;
  final String? wingId;
  final String? wingName;

  Flat({
    required this.id,
    required this.flatNo,
    required this.buildingId,
    required this.buildingName,
    required this.floor,
    required this.type,
    required this.area,
    required this.status,
    this.memberUid,
    this.memberName,
    this.wingId,
    this.wingName,
  });

  factory Flat.fromDoc(DocumentSnapshot doc) {
    // ✅ CRITICAL FIX: Safe cast using a fallback map if data vanishes
    final d = (doc.data() as Map<String, dynamic>?) ?? {};

    return Flat(
      id: doc.id,
      flatNo: d['flatNo'] ?? '',
      buildingId: d['buildingId'] ?? '',
      buildingName: d['buildingName'] ?? '',
      floor: d['floor'] ?? 0,
      type: d['type'] ?? '2BHK',
      // Safe dynamic numeric conversion tracking
      area: (d['area'] ?? 0).toDouble(),
      status: d['status'] ?? 'vacant',
      memberUid: d['memberUid'],
      memberName: d['memberName'],
      wingId: d['wingId'],
      wingName: d['wingName'],
    );
  }

  Map<String, dynamic> toMap() => {
    'flatNo': flatNo, 'buildingId': buildingId, 'buildingName': buildingName,
    'floor': floor, 'type': type, 'area': area, 'status': status,
    'memberUid': memberUid, 'memberName': memberName,
    'wingId': wingId, 'wingName': wingName,
  };
}