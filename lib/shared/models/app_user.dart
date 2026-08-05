import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String? flatNo;
  final String buildingId;
  final DateTime createdAt;
  final bool isActive;
  final String? photoUrl;
  final int parkingSlotsCount; // ✅ Fixed: Added for inventory tracking

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.flatNo,
    required this.buildingId,
    required this.createdAt,
    this.isActive = true,
    this.photoUrl,
    this.parkingSlotsCount = 1, // ✅ Default to 1 slot
  });

  factory AppUser.fromMap(Map<String, dynamic> m) {
    return AppUser(
      uid: m['uid'] ?? '',
      name: m['name'] ?? '',
      email: m['email'] ?? '',
      phone: m['phone'] ?? '',
      role: m['role'] ?? 'member',
      flatNo: m['flatNo'],
      buildingId: m['buildingId'] ?? 'unassigned',
      photoUrl: m['photoUrl'],
      parkingSlotsCount: m['parkingSlotsCount'] ?? 1,
      createdAt: m['createdAt'] is Timestamp
          ? (m['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      isActive: m['isActive'] ?? true,
    );
  }

  factory AppUser.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppUser.fromMap({...data, 'uid': doc.id});
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'flatNo': flatNo,
      'buildingId': buildingId,
      'photoUrl': photoUrl,
      'parkingSlotsCount': parkingSlotsCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
    };
  }
}