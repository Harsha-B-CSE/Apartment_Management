// lib/shared/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/app_user.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ─── ACTIVITY LOGGING (Audit System Schema Mapping) ─────────────────────────

  /// 📝 Internal helper to log every major action in the system matching the /audit_logs schema
  Future<void> _logActivity({
    required String buildingId,
    required String action,
    required String result,
    required String details,
    String? fallbackUserName,
  }) async {
    if (buildingId.isEmpty || buildingId == 'unassigned') return;

    try {
      final User? currentUser = _auth.currentUser;

      String operatorName = "System Operator";
      if (currentUser?.displayName != null && currentUser!.displayName!.trim().isNotEmpty) {
        operatorName = currentUser.displayName!.trim();
      } else if (fallbackUserName != null && fallbackUserName.trim().isNotEmpty) {
        operatorName = fallbackUserName.trim();
      }

      final String operatorUid = currentUser?.uid ?? "unauthenticated_cron";
      final String standardizedAction = action.trim().toUpperCase().replaceAll(' ', '_');
      final String standardizedResult = result.trim().toLowerCase();

      await _db.collection('audit_logs').add({
        'timestamp': FieldValue.serverTimestamp(),
        'buildingId': buildingId.trim(),
        'userUid': operatorUid,
        'userName': operatorName,
        'action': standardizedAction,
        'result': standardizedResult,
        'details': details.trim(),
      });
    } catch (e) {
      print('🚨 Internal Audit Log Trace Failure: $e');
    }
  }

  // ─── CORE AUTH METHODS ──────────────────────────────────────────────

  /// ✅ Fetches the custom user document from Firestore
  Future<AppUser?> getCurrentAppUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final snap = await _db.collection('users').doc(user.uid).get();
    return snap.exists ? AppUser.fromDoc(snap) : null;
  }

  /// ✅ Standard Login with Haptic Feedback and Logging
  Future<AppUser> login(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: email.trim().toLowerCase(), password: password);

      final snap = await _db.collection('users').doc(cred.user!.uid).get();
      if (!snap.exists) {
        throw Exception('User profile not found in database.');
      }

      final appUser = AppUser.fromDoc(snap);

      HapticFeedback.mediumImpact();

      await _logActivity(
        buildingId: appUser.buildingId,
        action: 'USER_LOGIN',
        result: 'success',
        details: 'User ${appUser.email} logged in successfully.',
        fallbackUserName: appUser.name,
      );

      return appUser;
    } catch (e) {
      HapticFeedback.heavyImpact();

      await _logActivity(
        buildingId: 'GLOBAL_SYSTEM',
        action: 'USER_LOGIN',
        result: 'failure',
        details: 'Authentication trace error encountered for identity context "$email". Exception: $e',
      );
      rethrow;
    }
  }

  /// ✅ Standard Profile Update logic
  Future<void> updateProfile({required String uid, required Map<String, dynamic> data, required String buildingId}) async {
    try {
      await _db.collection('users').doc(uid).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _logActivity(
        buildingId: buildingId,
        action: 'PROFILE_UPDATES',
        result: 'success',
        details: 'Modified core data profile mapping fields: ${data.keys.join(", ")}.',
      );
    } catch (e) {
      await _logActivity(
        buildingId: buildingId,
        action: 'PROFILE_UPDATES',
        result: 'failure',
        details: 'Failed profile synchronization update routine for user target $uid. Error: $e',
      );
      rethrow;
    }
  }

  Future<void> signOut(String buildingId, String currentUserName) async {
    await _logActivity(
      buildingId: buildingId,
      action: 'USER_LOGOUT',
      result: 'success',
      details: 'Active authorization session voluntarily cleared by operator.',
      fallbackUserName: currentUserName,
    );
    await _auth.signOut();
  }

  // ─── SAAS SIGNUP & ONBOARDING ───────────────────────────────────────

  /// 👥 Tenant Signup - Step 1: Create Auth Credentials and User Profile Document
  /// ✅ FIXED: Decoupled building collection dependency entirely to bypass security rule conflicts
  Future<AppUser> signup({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String buildingId,
    required String flatNo,
    String? inviteToken,
  }) async {
    // 1. Validate Building exists
    final buildingSnap = await _db.collection('buildings').doc(buildingId).get();
    if (!buildingSnap.exists) {
      HapticFeedback.heavyImpact();
      throw Exception('Building Code "$buildingId" is invalid. Please contact your Admin.');
    }

    // 2. Create core Firebase Auth Credentials
    UserCredential cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(
          email: email.trim().toLowerCase(), password: password);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        try {
          // Attempt to authenticate the orphaned account
          cred = await _auth.signInWithEmailAndPassword(
              email: email.trim().toLowerCase(), password: password);
          
          // Verify they don't already have an active profile in another building
          final userDoc = await _db.collection('users').doc(cred.user!.uid).get();
          if (userDoc.exists) {
            final data = userDoc.data()!;
            final currentBuilding = data['buildingId'];
            if (currentBuilding != null && currentBuilding != 'unassigned' && currentBuilding.trim().isNotEmpty) {
              throw Exception('Account is already assigned to a building. Please ask your current Admin to remove you first, or log in directly.');
            }
          }
        } on FirebaseAuthException catch (signInError) {
          if (signInError.code == 'wrong-password' || signInError.code == 'invalid-credential') {
            throw Exception('Email is already registered. To re-claim a flat, please enter your correct existing password.');
          }
          throw Exception('Email is already in use. Account recovery failed: ${signInError.message}');
        }
      } else {
        throw Exception(e.message ?? e.code);
      }
    }

    try {
      final user = AppUser(
        uid: cred.user!.uid,
        name: name,
        email: email.trim().toLowerCase(),
        phone: phone,
        role: 'member',
        flatNo: flatNo.trim().toUpperCase(),
        buildingId: buildingId.trim(),
        createdAt: DateTime.now(),
      );

      // 3. Persist the user profile document (Guaranteed to pass via uid == userId rules)
      await _db.collection('users').doc(user.uid).set(user.toMap());

      return user;
    } catch (e) {
      // Automatic cleanup rollback if registration profile write fails
      await cred.user?.delete();
      HapticFeedback.heavyImpact();
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// 🔑 Tenant Signup - Step 2: Claim and Occupy the Flat Asset Sequentially
  /// ✅ FIXED: Runs smoothly right after Step 1 establishes a fully validated auth session token.
  Future<void> claimFlatAsset({
    required String buildingId,
    required String wingName,
    required String flatNo,
    required String uid,
    required String name,
  }) async {
    final String wingPrefix = '${wingName.trim().replaceAll(' ', '')}_';
    final DocumentReference flatDocRef = _db.collection('flats').doc('${buildingId.trim()}_$wingPrefix${flatNo.trim().toUpperCase()}');

    try {
      // Update the master flat tracking file state details dynamically
      await flatDocRef.update({
        'status': 'occupied',
        'tenantUid': uid,
        'tenantName': name,
        'occupiedAt': FieldValue.serverTimestamp(),
      });

      // Increment total building tenant counter metrics now that auth propagation is resolved
      await _db.collection('buildings').doc(buildingId).update({
        'totalTenants': FieldValue.increment(1),
      });

      // Audit Logging Traces
      await _logActivity(
        buildingId: buildingId,
        action: 'MEMBER_SIGNUP_AUTO_ALLOCATION',
        result: 'success',
        details: 'Resident profile linked cleanly to allocated flat unit "$flatNo".',
        fallbackUserName: name,
      );

      HapticFeedback.vibrate();
    } catch (e) {
      print('🚨 Asset assignment post-process update failed: $e');
    }
  }

  /// 🛡️ Create Guard (Admin Only)
  /// Uses a secondary Firebase App instance so the Admin doesn't get logged out
  Future<void> createGuardByAdmin({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String buildingId,
    required String assignedWing,
  }) async {
    FirebaseApp? secondaryApp;
    try {
      secondaryApp = await Firebase.initializeApp(
        name: 'SecondaryApp',
        options: Firebase.app().options,
      );

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      UserCredential cred;
      try {
        cred = await secondaryAuth.createUserWithEmailAndPassword(
          email: email.trim().toLowerCase(),
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          // Attempt to reuse the orphaned auth account
          cred = await secondaryAuth.signInWithEmailAndPassword(
            email: email.trim().toLowerCase(),
            password: password,
          );
        } else {
          rethrow;
        }
      }

      final user = AppUser(
        uid: cred.user!.uid,
        name: name,
        email: email.trim().toLowerCase(),
        phone: phone,
        role: 'guard',
        flatNo: assignedWing.trim(),
        buildingId: buildingId.trim(),
        createdAt: DateTime.now(),
      );

      await _db.collection('users').doc(user.uid).set(user.toMap());

      await _logActivity(
        buildingId: buildingId,
        action: 'GUARD_CREATED',
        result: 'success',
        details: 'Admin created guard profile for ${user.email}.',
      );

      HapticFeedback.mediumImpact();
    } catch (e) {
      HapticFeedback.heavyImpact();
      throw Exception('Failed to create guard: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (secondaryApp != null) {
        await secondaryApp.delete();
      }
    }
  }

  // ─── DANGER ZONE: ADMIN & CLEANUP ──────────────────────────────────

  Future<void> removeMember(String targetUid, String buildingId) async {
    try {
      final admin = await getCurrentAppUser();
      if (admin?.role != 'admin' || admin?.buildingId != buildingId) {
        throw Exception('Unauthorized: Only building admins can remove members.');
      }

      await _db.collection('users').doc(targetUid).delete();

      // Vacate any flats occupied by this user
      final flatsQuery = await _db.collection('flats')
          .where('buildingId', isEqualTo: buildingId)
          .where('tenantUid', isEqualTo: targetUid)
          .get();

      final batch = _db.batch();
      for (var flatDoc in flatsQuery.docs) {
        batch.update(flatDoc.reference, {
          'status': 'vacant',
          'tenantUid': FieldValue.delete(),
          'tenantName': FieldValue.delete(),
        });
      }
      
      // Also decrement total tenants in building
      if (flatsQuery.docs.isNotEmpty) {
        batch.update(_db.collection('buildings').doc(buildingId), {
          'totalTenants': FieldValue.increment(-flatsQuery.docs.length),
        });
      }
      
      await batch.commit();

      await _logActivity(
        buildingId: buildingId,
        action: 'MEMBER_REMOVAL',
        result: 'success',
        details: 'Purged record structure mapping completely for active resident entity Target ID: $targetUid. Vacated ${flatsQuery.docs.length} flats.',
        fallbackUserName: admin?.name,
      );

      HapticFeedback.mediumImpact();
    } catch (e) {
      HapticFeedback.heavyImpact();

      final admin = await getCurrentAppUser();
      await _logActivity(
        buildingId: buildingId,
        action: 'MEMBER_REMOVAL',
        result: 'failure',
        details: 'Administrative data drop pipeline tracking error encountered for target: $targetUid. Error: $e',
        fallbackUserName: admin?.name,
      );
      throw Exception('Failed to remove member: ${e.toString()}');
    }
  }

  Future<void> deleteBuildingComplete(String buildingId) async {
    final collections = [
      'complaints', 'visitors', 'parking',
      'service_requests', 'notifications',
      'flats', 'payments', 'ratings', 'services', 'users'
    ];

    final adminProfile = await getCurrentAppUser();

    try {
      // 1. Delete the building record first while admin permissions are fully intact
      try {
        await _db.collection('buildings').doc(buildingId).delete();
      } catch (e) {
        throw Exception('Failed to delete building $buildingId: $e');
      }

      // 2. Log the activity before we lose the building or user context
      await _logActivity(
        buildingId: buildingId,
        action: 'BUILDING_DELETION',
        result: 'success',
        details: 'Building $buildingId and all multi-tenant entity relational tables cleanly dropped.',
        fallbackUserName: adminProfile?.name,
      );

      List<String> errors = [];
      // 3. Delete all other multi-tenant data
      for (var col in collections) {
        try {
          final snap = await _db.collection(col).where('buildingId', isEqualTo: buildingId).get();

          final chunks = (snap.docs.length / 100).ceil();
          for (var i = 0; i < chunks; i++) {
            final batch = _db.batch();
            final start = i * 100;
            final end = (i + 1) * 100 > snap.docs.length ? snap.docs.length : (i + 1) * 100;

            for (var doc in snap.docs.sublist(start, end)) {
              // Skip deleting the admin's own profile until everything else is done
              if (col == 'users' && doc.id == adminProfile?.uid) continue;
              batch.delete(doc.reference);
            }
            await batch.commit();
          }
        } catch (colError) {
          errors.add('$col: $colError');
        }
      }

      if (errors.isNotEmpty) {
        throw Exception('Failed on collections: ${errors.join(", ")}');
      }

      // 4. Finally, delete the admin's own profile document
      if (adminProfile != null) {
        await _db.collection('users').doc(adminProfile.uid).delete();
        try {
          // Attempt to delete the Firebase Auth account itself
          await _auth.currentUser?.delete();
        } catch (authError) {
          print('Notice: Failed to delete Firebase Auth user account: $authError');
        }
      }

      HapticFeedback.vibrate();
    } catch (e) {
      await _logActivity(
        buildingId: buildingId,
        action: 'BUILDING_DELETION',
        result: 'failure',
        details: 'Cascading deletion script encountered tracking exception errors. Context data state corrupted: $e',
        fallbackUserName: adminProfile?.name,
      );
      throw Exception('Cleanup failed: $e');
    }
  }

  Future<String> createClientAdmin({
    required String name,
    required String email,
    required String password,
    required String buildingName,
    String? logoBase64,
  }) async {
    final DocumentReference newBuildingRef = _db.collection('buildings').doc();
    final String buildingId = newBuildingRef.id;

    UserCredential cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        try {
          cred = await _auth.signInWithEmailAndPassword(
            email: email.trim().toLowerCase(),
            password: password,
          );
          
          final userDoc = await _db.collection('users').doc(cred.user!.uid).get();
          if (userDoc.exists) {
            final data = userDoc.data()!;
            if (data['buildingId'] != null && data['buildingId'] != 'unassigned' && data['buildingId'] != buildingId) {
              throw Exception('Email is already assigned to another active building. Please use a different email.');
            }
          }
        } catch (signInError) {
          throw Exception('Email is already in use. If this is an orphaned account, please provide the exact correct password to reclaim it.');
        }
      } else {
        throw Exception(e.message ?? e.code);
      }
    }

    try {
      final String adminUid = cred.user!.uid;
      final WriteBatch batch = _db.batch();

      batch.set(newBuildingRef, {
        'id': buildingId,
        'name': buildingName,
        'address': 'Pending Address Setup',
        'totalFloors': 0,
        'totalFlats': 0,
        'totalTenants': 0,
        'adminUid': adminUid,
        if (logoBase64 != null) 'logoBase64': logoBase64,
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.set(_db.collection('users').doc(adminUid), {
        'uid': adminUid,
        'name': name,
        'email': email.trim().toLowerCase(),
        'phone': 'Not Provided Yet',
        'role': 'admin',
        'buildingId': buildingId,
        'flatNo': 'N/A',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return buildingId;
    } catch (e) {
      await cred.user?.delete();
      throw Exception('SaaS Client Provisioning Failed: ${e.toString()}');
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());

      await _logActivity(
        buildingId: 'GLOBAL_SYSTEM',
        action: 'PASSWORD_RESET_REQUEST',
        result: 'success',
        details: 'Password recovery dispatch initialized for identifier targeting: $email.',
      );
    } catch (e) {
      await _logActivity(
        buildingId: 'GLOBAL_SYSTEM',
        action: 'PASSWORD_RESET_REQUEST',
        result: 'failure',
        details: 'Recovery dispatch rejected for identity checkpoint context: $email. Error: $e',
      );
      rethrow;
    }
  }
}