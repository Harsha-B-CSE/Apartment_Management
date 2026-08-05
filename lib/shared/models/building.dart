// lib/shared/models/building.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Building {
  final String id;
  final String name;
  final int totalFloors;
  final int totalFlats;
  final String address;

  Building({required this.id, required this.name, required this.totalFloors, required this.totalFlats, required this.address});

  factory Building.fromDoc(DocumentSnapshot doc) {
    // ✅ CRITICAL FIX: Prevent explicit null map type rejections
    final d = (doc.data() as Map<String, dynamic>?) ?? {};

    return Building(
      id: doc.id,
      name: d['name'] ?? '',
      totalFloors: d['totalFloors'] ?? 0,
      totalFlats: d['totalFlats'] ?? 0,
      address: d['address'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {'name': name, 'totalFloors': totalFloors, 'totalFlats': totalFlats, 'address': address};
}