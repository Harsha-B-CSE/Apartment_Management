// lib/shared/services/firestore_service.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'cache_service.dart';
import 'connectivity_service.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  static const int pageSize = 20;

  // ── Input sanitisation ─────────────────────────────────────────────
  Map<String, dynamic> _sanitise(Map<String, dynamic> data) {
    return data.map((k, v) {
      if (v is String) {
        return MapEntry(k, v.replaceAll(RegExp(r'<[^>]*>'), '').trim());
      }
      return MapEntry(k, v);
    });
  }

  // ── CRUD ───────────────────────────────────────────────────────────
  Future<String> add(String collection, Map<String, dynamic> data) async {
    final id = _uuid.v4();
    final clean = _sanitise(data);

    await _withRetry(() => _db.collection(collection).doc(id).set({
      'id': id,
      'createdAt': FieldValue.serverTimestamp(),
      ...clean,
    }));

    return id;
  }

  Future<void> update(
      String collection, String id, Map<String, dynamic> data) async {
    final clean = _sanitise(data);

    await _withRetry(() => _db.collection(collection).doc(id).update({
      'updatedAt': FieldValue.serverTimestamp(),
      ...clean,
    }));
  }

  Future<void> delete(String collection, String id) {
    return _withRetry(() => _db.collection(collection).doc(id).delete());
  }

  // ── BUILDING FILTERED STREAM ──────────────────────────────────────
  // This ensures multi-tenancy sync
  Stream<QuerySnapshot> streamFiltered(
      String collection, {
        required String buildingId,
        String? orderBy,
        bool descending = true,
      }) {
    Query q = _db.collection(collection).where('buildingId', isEqualTo: buildingId);

    if (orderBy != null) {
      q = q.orderBy(orderBy, descending: descending);
    }

    return q.snapshots();
  }

  // ── Backward compatibility stream helper ──────────────────────────
  Stream<QuerySnapshot> stream(
      String collection, {
        String? orderBy,
        bool descending = false,
      }) {
    Query q = _db.collection(collection);
    if (orderBy != null) {
      q = q.orderBy(orderBy, descending: descending);
    }
    return q.snapshots();
  }

  // ── Retry wrapper ──────────────────────────────────────────────────
  Future<T> _withRetry<T>(
      Future<T> Function() fn, {
        int retries = 3,
        Duration delay = const Duration(seconds: 1),
      }) async {
    int attempt = 0;
    while (true) {
      try {
        return await fn();
      } catch (e) {
        if (attempt >= retries - 1) rethrow;
        attempt++;
        await Future.delayed(delay * attempt);
      }
    }
  }
}
