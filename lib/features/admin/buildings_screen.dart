// lib/features/admin/presentation/screens/buildings_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../shared/models/building.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/services/auth_provider.dart';
import '../../shared/widgets/app_widgets.dart';
import 'admin_shell.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/utils/feedback_util.dart';
import '../../shared/utils/safe_delete_coordinator.dart'; // ⚡ Import the newly added coordinator
import '../../shared/services/audit_service.dart'; // ⚡ Import the unified audit service class

class BuildingsScreen extends StatelessWidget {
  const BuildingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = FirestoreService();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.user;

    return Scaffold(
      appBar: buildAdminAppBar(context, 'Buildings'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          FeedbackUtil.light();
          _showDialog(context, db);
        },
        backgroundColor: AppColors.primary,
        icon: const FaIcon(FontAwesomeIcons.plus, size: 14, color: Colors.white),
        label: const Text('Add Building', style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('buildings')
            .where('id', isEqualTo: currentUser?.buildingId ?? '')
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text("Error: ${snap.error}"));
          if (!snap.hasData) return const LoadingList();

          // ✅ Hard-copy only active items to protect the list rendering tree
          final docs = snap.data!.docs.where((d) => d.exists && d.data() != null).toList();

          if (docs.isEmpty) {
            return EmptyState(
              icon: Icons.business,
              title: 'No Buildings',
              subtitle: 'Add buildings to organise your flats',
              actionLabel: 'Add Building',
              onAction: () {
                FeedbackUtil.light();
                _showDialog(context, db);
              },
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (listViewContext, i) {
              final b = Building.fromDoc(docs[i]);
              return _BuildingCard(
                b,
                onEdit: () {
                  FeedbackUtil.light();
                  _showDialog(context, db, building: b);
                },
                // ✅ ROUTE VIA DECOUPLED COORDINATOR CLASS
                onDelete: () => SafeDeleteCoordinator.trigger(
                  context: context,
                  collection: 'buildings',
                  documentId: b.id,
                  auditBuildingId: b.id,
                  displayLabel: 'Building',
                  operatorName: currentUser?.name ?? 'System Admin',
                  actionDetails: "Permanently deleted building profile '${b.name}' located at '${b.address}'.",
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showDialog(BuildContext context, FirestoreService db, {Building? building}) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    final name = TextEditingController(text: building?.name ?? '');
    final floors = TextEditingController(text: building?.totalFloors.toString() ?? '');
    final flats = TextEditingController(text: building?.totalFlats.toString() ?? '');
    final address = TextEditingController(text: building?.address ?? '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(building == null ? 'Add Building' : 'Edit Building', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            AppTextField(label: 'Building Name', hint: 'Block A', controller: name, validator: (v) => v!.isEmpty ? 'Required' : null),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: AppTextField(label: 'Total Floors', hint: '10', controller: floors, keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: AppTextField(label: 'Total Flats', hint: '40', controller: flats, keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 14),
            AppTextField(label: 'Address', hint: '123 Main Street', controller: address),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) {
                    FeedbackUtil.error();
                    return;
                  }

                  FeedbackUtil.medium();

                  final data = {
                    'name': name.text,
                    'totalFloors': int.tryParse(floors.text) ?? 0,
                    'totalFlats': int.tryParse(flats.text) ?? 0,
                    'address': address.text,
                    'adminUid': user?.uid,
                  };
                  try {
                    String finalBuildingId = building?.id ?? '';

                    if (building == null) {
                      final String generatedId = await db.add('buildings', data);
                      finalBuildingId = generatedId;
                    } else {
                      await db.update('buildings', building.id, data);
                    }

                    if (user != null) {
                      await AuditService().logAction(
                        buildingId: finalBuildingId.isNotEmpty ? finalBuildingId : user.buildingId,
                        action: building == null ? "BUILDING_CREATION" : "PROFILE_UPDATES",
                        result: "success",
                        details: building == null
                            ? "Instantiated a new infrastructural mapping context under name '${name.text}' with ${floors.text} levels."
                            : "Modified baseline parameters for building identity profile context '${name.text}'.",
                        fallbackUserName: user.name,
                      );
                    }

                    FeedbackUtil.success();
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    if (user != null) {
                      // ✅ FIXED: Restored missing constructor parentheses () to AuditService class instantiation here
                      await AuditService().logAction(
                        buildingId: building?.id ?? user.buildingId,
                        action: building == null ? "BUILDING_CREATION" : "PROFILE_UPDATES",
                        result: "failure",
                        details: "Infrastructural transaction execution failure encountered for parameters '${name.text}'. Error: $e",
                        fallbackUserName: user.name,
                      );
                    }

                    FeedbackUtil.error();
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text("Error: $e")));
                    }
                  }
                },
                child: Text(building == null ? 'Add Building' : 'Save Changes'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _BuildingCard extends StatelessWidget {
  final Building building;
  final VoidCallback onEdit, onDelete;
  const _BuildingCard(this.building, {required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
          child: const Center(child: FaIcon(FontAwesomeIcons.building, color: AppColors.primary, size: 20)),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(building.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 4),
          Text('${building.totalFloors} floors · ${building.totalFlats} flats',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          if (building.address.isNotEmpty)
            Text(building.address, style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
        ])),
        Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.penToSquare, size: 14, color: AppColors.info),
            onPressed: onEdit,
          ),
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.trash, size: 14, color: AppColors.danger),
            onPressed: onDelete,
          ),
        ]),
      ]),
    );
  }
}