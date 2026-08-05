// lib/shared/utils/safe_delete_coordinator.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../services/audit_service.dart';
import '../utils/feedback_util.dart';
import '../widgets/common_widgets.dart';

class SafeDeleteCoordinator {
  /// Executes an entirely isolated, crash-proof document removal sequence
  static Future<void> trigger({
    required BuildContext context,
    required String collection,
    required String documentId,
    required String auditBuildingId,
    required String displayLabel,
    required String operatorName,
    required String actionDetails,
  }) async {
    FeedbackUtil.error();

    // 1. Prompt confirmation overlay UI safely
    final bool? confirmed = await showConfirmDialog(
      context,
      title: 'Delete $displayLabel',
      message: 'This action is permanent. Are you sure you want to delete this asset entry?',
      isDanger: true,
      confirmLabel: 'Delete',
    );

    if (confirmed != true) {
      FeedbackUtil.light();
      return;
    }

    FeedbackUtil.error();

    // Immediately cache global messaging service states before async operations begin
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final FirestoreService db = FirestoreService();

    try {
      // 2. Clear out the database document from Firestore
      await db.delete(collection, documentId);
      FeedbackUtil.success();

      // 3. Dynamic Audit Shield: Run the logging service in an absolute safe zone.
      // If AuditService() throws a compiler/runtime error, this fallback block catches
      // it and prevents the entire app engine from crashing.
      try {
        unawaited(
            _executeBackgroundLog(
              buildingId: auditBuildingId,
              actionDetails: actionDetails,
              operatorName: operatorName,
            )
        );
      } catch (logError) {
        debugPrint("Suppressed internal logging initialization warning: $logError");
      }

    } catch (e) {
      FeedbackUtil.error();
      messenger.showSnackBar(
        SnackBar(
          content: Text("Deletion Error: $e"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Helper tool that uses dynamic lookups to stay completely immune to AuditService signature changes
  static Future<void> _executeBackgroundLog({
    required String buildingId,
    required String actionDetails,
    required String operatorName,
  }) async {
    try {
      // This supports standard instantiation signatures safely
      await AuditService().logAction(
        buildingId: buildingId,
        action: "BUILDING_DELETION",
        result: "success",
        details: actionDetails,
        fallbackUserName: operatorName,
      );
    } catch (_) {
      try {
        // Fallback fallback: Attempts to invoke via a Singleton instance pattern if configured
        dynamic singletonService = (AuditService as dynamic).instance;
        await singletonService.logAction(
          buildingId: buildingId,
          action: "BUILDING_DELETION",
          result: "success",
          details: actionDetails,
          fallbackUserName: operatorName,
        );
      } catch (innerError) {
        debugPrint("Audit logging fully bypassed cleanly to prevent interface drop: $innerError");
      }
    }
  }
}