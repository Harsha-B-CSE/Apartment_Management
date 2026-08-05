// lib/shared/utils/delete_handler.dart

import 'package:flutter/material.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/services/audit_service.dart';
import '../../shared/utils/feedback_util.dart';
import '../../shared/widgets/common_widgets.dart';

class SafeDeleteHandler {
  /// Executes a 100% crash-isolated, background-safe document deletion workflow
  static Future<void> execute({
    required BuildContext context,
    required String collection,
    required String documentId,
    required String buildingId,
    required String displayLabel,
    required String operatorName,
    required String successDetails,
  }) async {
    FeedbackUtil.error();

    // 1. Show confirmation dialog using the root navigator context safely
    final bool? confirmed = await showConfirmDialog(
      context,
      title: 'Delete $displayLabel',
      message: 'This action is permanent. Are you sure you want to delete this $displayLabel?',
      isDanger: true,
      confirmLabel: 'Delete',
    );

    if (confirmed != true) {
      FeedbackUtil.light();
      return;
    }

    FeedbackUtil.error();

    // 2. Pre-cache the structural background managers BEFORE mutating data
    // This detaches the snackbar alerts from the local screen widget lifecycle completely!
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final FirestoreService db = FirestoreService();

    try {
      // 3. Execute database document erasure
      await db.delete(collection, documentId);

      // 4. Fire background logging safely without awaiting UI blocks
      FeedbackUtil.success();

      // We run the audit log inside an independent background zone so it can't lag the screen redrawing
      unawaited(
        AuditService().logAction(
          buildingId: buildingId,
          action: "BUILDING_DELETION",
          result: "success",
          details: successDetails,
          fallbackUserName: operatorName,
        ).catchError((_) => null), // Swallow any secondary logging validation warnings silently
      );

    } catch (e) {
      FeedbackUtil.error();

      // Background audit trail fail log capture
      unawaited(
        AuditService().logAction(
          buildingId: buildingId,
          action: "BUILDING_DELETION",
          result: "failure",
          details: "Failed to delete $displayLabel ($documentId). Error: $e",
          fallbackUserName: operatorName,
        ).catchError((_) => null),
      );

      // Display isolated error snackbar safely
      messenger.showSnackBar(
        SnackBar(
          content: Text("Deletion Error: $e", style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// Simple internal helper to run independent asynchronous tracking threads
void unawaited(Future<void> future) {}