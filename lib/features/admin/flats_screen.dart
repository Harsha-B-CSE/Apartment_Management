// lib/features/admin/presentation/screens/flats_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../shared/models/flat.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/services/auth_provider.dart';
import '../../shared/widgets/app_widgets.dart';
import 'admin_shell.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/utils/feedback_util.dart';
import '../../shared/utils/safe_delete_coordinator.dart';
import '../../shared/services/audit_service.dart';

class FlatsScreen extends StatefulWidget {
  const FlatsScreen({super.key});
  @override
  State<FlatsScreen> createState() => _FlatsScreenState();
}

class _FlatsScreenState extends State<FlatsScreen> {
  final _db = FirestoreService();
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: buildAdminAppBar(context, 'Flats'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          FeedbackUtil.light();
          _showFlatDialog(user.buildingId);
        },
        backgroundColor: AppColors.primary,
        icon: const FaIcon(FontAwesomeIcons.plus, size: 14, color: Colors.white),
        label: const Text('Add Flat', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: ['all', 'occupied', 'vacant'].map((f) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(f[0].toUpperCase() + f.substring(1)),
                  selected: _filter == f,
                  onSelected: (_) {
                    FeedbackUtil.light();
                    setState(() => _filter = f);
                  },
                  selectedColor: AppColors.primary.withOpacity(0.12),
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(color: _filter == f ? AppColors.primary : AppColors.textSecondary, fontSize: 13),
                ),
              )).toList(),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db.streamFiltered('flats', buildingId: user.buildingId, orderBy: 'flatNo', descending: false),
              builder: (context, snap) {
                if (snap.hasError) return Center(child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text("Error: ${snap.error}\n\nEnsure BuildingId is correctly set.", textAlign: TextAlign.center),
                ));
                if (!snap.hasData) return const LoadingList();

                var docs = snap.data!.docs.where((d) => d.exists && d.data() != null).toList();

                if (_filter != 'all') {
                  docs = docs.where((d) => (d.data() as Map)['status'] == _filter).toList();
                }
                if (docs.isEmpty){ return EmptyState(
                  icon: Icons.door_front_door, title: 'No Flats Found',
                  subtitle: 'Add flats to get started',
                  actionLabel: 'Add Flat',
                  onAction: () {
                    FeedbackUtil.light();
                    _showFlatDialog(user.buildingId);
                  },
                );}
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (listViewContext, i) {
                    final flat = Flat.fromDoc(docs[i]);
                    return _FlatCard(
                      flat: flat,
                      onEdit: () {
                        FeedbackUtil.light();
                        _showFlatDialog(user.buildingId, flat: flat);
                      },
                      onDelete: () => SafeDeleteCoordinator.trigger(
                        context: context,
                        collection: 'flats',
                        documentId: flat.id,
                        auditBuildingId: user.buildingId,
                        displayLabel: 'Flat',
                        operatorName: user.name,
                        actionDetails: "Permanently purged Flat ${flat.flatNo} from the building asset register index.",
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showFlatDialog(String buildingId, {Flat? flat}) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // ✅ String inputs normalized cleanly with fallback conversions
    final flatNo = TextEditingController(text: flat?.flatNo ?? '');
    final floor = TextEditingController(text: flat?.floor.toString() ?? '');
    final area = TextEditingController(text: flat?.area.toString() ?? '');
    String type = flat?.type ?? '2BHK';
    String status = flat?.status ?? 'vacant';
    String? selectedWingId = flat?.wingId;
    String? selectedWingName = flat?.wingName;
    final formKey = GlobalKey<FormState>();

    // Fetch the wings/buildings for the dropdown
    List<Map<String, String>> availableWings = [];
    bool fetchingWings = true;

    showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setS) {
          // Fetch wings ONCE when the dialog opens
          if (fetchingWings) {
            FirebaseFirestore.instance
                .collection('buildings')
                .where('adminUid', isEqualTo: authProvider.user?.uid) // Ensure we only get wings for this admin
                .get().then((snap) {
              if (ctx2.mounted) {
                setS(() {
                  availableWings = snap.docs.map((d) => {
                    'id': d.id,
                    'name': d.data()['name'].toString(),
                  }).toList();
                  fetchingWings = false;
                  // If editing and the wing is missing from the list, or just default it
                  if (selectedWingId == null && availableWings.isNotEmpty) {
                    selectedWingId = availableWings.first['id'];
                    selectedWingName = availableWings.first['name'];
                  }
                });
              }
            });
          }

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx2).viewInsets.bottom + 20),
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(flat == null ? 'Add New Flat' : 'Edit Flat', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 20),

                // Wing Selection Dropdown
                const Text('Building / Wing', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedWingId,
                  hint: Text(fetchingWings ? 'Loading buildings...' : (availableWings.isEmpty ? 'No buildings added yet' : 'Select Building/Wing')),
                  decoration: const InputDecoration(
                    filled: true, fillColor: AppColors.surfaceVariant,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  dropdownColor: AppColors.surface,
                  items: availableWings.map((w) => DropdownMenuItem(value: w['id'], child: Text(w['name']!))).toList(),
                  onChanged: (fetchingWings || availableWings.isEmpty) ? null : (val) {
                    FeedbackUtil.light();
                    setS(() {
                      selectedWingId = val;
                      selectedWingName = availableWings.firstWhere((w) => w['id'] == val)['name'];
                    });
                  },
                  validator: (v) => v == null ? 'Please select a Building/Wing' : null,
                ),
                const SizedBox(height: 14),

                Row(children: [
                  Expanded(child: AppTextField(label: 'Flat No.', hint: '101', controller: flatNo,
                      validator: (v) => v!.isEmpty ? 'Required' : null)),
                  const SizedBox(width: 12),
                  Expanded(child: AppTextField(label: 'Floor', hint: '1', controller: floor,
                      keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Required' : null)),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: AppTextField(label: 'Area (sq ft)', hint: '850', controller: area,
                      keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: AppDropdown<String>(
                    labelText: 'Type',
                    value: type,
                    items: ['1BHK','2BHK','3BHK','Studio'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) {
                      FeedbackUtil.light();
                      setS(() => type = v!);
                    },
                  )),
                ]),
                const SizedBox(height: 14),
                AppDropdown<String>(
                  labelText: 'Status',
                  value: status,
                  items: ['vacant','occupied'].map((s) => DropdownMenuItem(value: s, child: Text(s[0].toUpperCase()+s.substring(1)))).toList(),
                  onChanged: (v) {
                    FeedbackUtil.light();
                    setS(() => status = v!);
                  },
                ),
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
                      final currentUser = authProvider.user;

                      // Clean inputs immediately to ensure matching logic passes across layers
                      final cleanFlatNo = flatNo.text.trim().toUpperCase();

                      try {
                        final data = {
                          'flatNo': cleanFlatNo,
                          'floor': int.tryParse(floor.text) ?? 0,
                          'area': double.tryParse(area.text) ?? 0.0,
                          'type': type,
                          'status': status,
                          'buildingId': buildingId.trim(),
                          'wingId': selectedWingId,
                          'wingName': selectedWingName,
                        };

                        // ✅ FIXED: Incorporates wingName into the custom doc ID to prevent collisions across wings!
                        final String wingPrefix = selectedWingName != null ? '${selectedWingName!.replaceAll(' ', '')}_' : '';
                        final String customizedDocumentPathId = '${buildingId.trim()}_$wingPrefix$cleanFlatNo';

                        if (flat == null) {
                          // Writes directly to a custom structural key slot instead of generating a randomized string hash
                          await FirebaseFirestore.instance
                              .collection('flats')
                              .doc(customizedDocumentPathId)
                              .set({
                            ...data,
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                        } else {
                          await FirebaseFirestore.instance
                              .collection('flats')
                              .doc(flat.id)
                              .update(data);
                        }

                        if (currentUser != null) {
                          await AuditService().logAction(
                            buildingId: buildingId,
                            action: flat == null ? "BUILDING_CREATION" : "PROFILE_UPDATES",
                            result: "success",
                            details: flat == null
                                ? "Created new asset listing context: Flat $cleanFlatNo ($type, Floor ${floor.text}) in $selectedWingName."
                                : "Modified structural details for Flat $cleanFlatNo in $selectedWingName (Status: $status).",
                            fallbackUserName: currentUser.name,
                          );
                        }

                        FeedbackUtil.success();
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        if (currentUser != null) {
                          await AuditService().logAction(
                            buildingId: buildingId,
                            action: flat == null ? "BUILDING_CREATION" : "PROFILE_UPDATES",
                            result: "failure",
                            details: "Failed to persist asset changes for Flat $cleanFlatNo. Error: $e",
                            fallbackUserName: currentUser.name,
                          );
                        }
                        FeedbackUtil.error();
                      }
                    },
                    child: Text(flat == null ? 'Add Flat' : 'Save Changes'),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _FlatCard extends StatelessWidget {
  final Flat flat;
  final VoidCallback onEdit, onDelete;
  const _FlatCard({required this.flat, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isOccupied = flat.status == 'occupied';
    final String wingDisplay = flat.wingName != null ? ' (${flat.wingName})' : '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: isOccupied ? AppColors.success.withOpacity(0.1) : AppColors.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: FaIcon(FontAwesomeIcons.doorOpen,
              size: 18, color: isOccupied ? AppColors.success : AppColors.warning)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Flat ${flat.flatNo}$wingDisplay', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 2),
          Text('${flat.type} · Floor ${flat.floor} · ${flat.area.toInt()} sq ft',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          if (flat.memberName != null)
            Text(flat.memberName!, style: const TextStyle(color: AppColors.accent, fontSize: 12)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          StatusBadge(flat.status),
          const SizedBox(height: 6),
          Row(mainAxisSize: MainAxisSize.min, children: [
            GestureDetector(
              onTap: onEdit,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: FaIcon(FontAwesomeIcons.penToSquare, size: 13, color: AppColors.info),
              ),
            ),
            GestureDetector(
              onTap: onDelete,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: FaIcon(FontAwesomeIcons.trash, size: 13, color: AppColors.danger),
              ),
            ),
          ]),
        ]),
      ]),
    );
  }
}