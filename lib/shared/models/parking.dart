import 'package:cloud_firestore/cloud_firestore.dart';

class Parking {
  final String id;
  final String slotNo;
  final String type; // 'car', 'bike'
  final String status; // 'allocated', 'vacant'
  final String? flatNo;
  final String? memberName;
  final String? vehicleNo;
  final String? vehicleModel;

  Parking({required this.id, required this.slotNo, required this.type,
    required this.status, this.flatNo, this.memberName, this.vehicleNo, this.vehicleModel});

  factory Parking.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return Parking(
      id: doc.id, 
      slotNo: d['slotNo'] ?? '', 
      type: d['type'] ?? 'car',
      status: d['status'] ?? 'vacant', 
      flatNo: d['flatNo'], 
      memberName: d['memberName'],
      vehicleNo: d['vehicleNo'], 
      vehicleModel: d['vehicleModel']
    );
  }

  Map<String, dynamic> toMap() => {
    'slotNo': slotNo, 'type': type, 'status': status, 'flatNo': flatNo,
    'memberName': memberName, 'vehicleNo': vehicleNo, 'vehicleModel': vehicleModel,
  };
}
