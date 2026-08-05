// lib/features/admin/presentation/screens/admin_parking_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../shared/models/parking.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/services/auth_provider.dart';
import '../../shared/widgets/app_widgets.dart';
import 'admin_shell.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/utils/feedback_util.dart';
import '../../shared/services/audit_service.dart'; // ⚡ Import the unified audit system utility

class AdminParkingScreen extends StatefulWidget {
  const AdminParkingScreen({super.key});
  @override
  State<AdminParkingScreen> createState() => _AdminParkingScreenState();
}

class _AdminParkingScreenState extends State<AdminParkingScreen> {
  final _db = FirestoreService();
  String _type = 'all';

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: buildAdminAppBar(context, 'Parking'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          FeedbackUtil.light();
          _showAddDialog(user.buildingId, user.name);
        },
        backgroundColor: AppColors.primary,
        icon: const FaIcon(FontAwesomeIcons.plus, size: 14, color: Colors.white),
        label: const Text('Add Slot', style: TextStyle(color: Colors.white)),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: ['all','car','bike'].map((t) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(t[0].toUpperCase()+t.substring(1)),
              selected: _type == t,
              onSelected: (_) {
                FeedbackUtil.light();
                setState(() => _type = t);
              },
              selectedColor: AppColors.primary.withOpacity(0.12),
              checkmarkColor: AppColors.primary,
              labelStyle: TextStyle(color: _type == t ? AppColors.primary : AppColors.textSecondary, fontSize: 13),
            ),
          )).toList()),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.streamFiltered('parking', buildingId: user.buildingId, orderBy: 'slotNo', descending: false),
            builder: (context, snap) {
              if (snap.hasError) return Center(child: Text("Error: ${snap.error}"));
              if (!snap.hasData) return const LoadingList();
              var docs = snap.data!.docs;
              if (_type != 'all') {
                docs = docs.where((d) => (d.data() as Map)['type'] == _type).toList();
              }
              if (docs.isEmpty) return EmptyState(
                icon: FontAwesomeIcons.squareParking, title: 'No Parking Slots',
                subtitle: 'Add slots to manage parking',
                actionLabel: 'Add Slot',
                onAction: () {
                  FeedbackUtil.light();
                  _showAddDialog(user.buildingId, user.name);
                },
              );
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.1,
                ),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final p = Parking.fromDoc(docs[i]);
                  return _ParkingSlotCard(p, onTap: () {
                    FeedbackUtil.light();
                    _showAllocateDialog(p, user.buildingId, user.name);
                  });
                },
              );
            },
          ),
        ),
      ]),
    );
  }

  void _showAddDialog(String buildingId, String adminName) {
    final slotNo = TextEditingController();
    String type = 'car';
    final formKey = GlobalKey<FormState>();
    showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx2, setS) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Add Parking Slot', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          AppTextField(label: 'Slot No.', hint: 'P-01', controller: slotNo, validator: (v) => v!.isEmpty ? 'Required' : null),
          const SizedBox(height: 14),
          AppDropdown<String>(
            labelText: 'Vehicle Type', value: type,
            items: ['car','bike'].map((t) => DropdownMenuItem(value: t, child: Text(t[0].toUpperCase()+t.substring(1)))).toList(),
            onChanged: (v) {
              FeedbackUtil.light();
              setS(() => type = v!);
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

                try {
                  await _db.add('parking', {
                    'slotNo': slotNo.text,
                    'type': type,
                    'status': 'vacant',
                    'buildingId': buildingId,
                  });

                  // ⚡ SUCCESS LOG: Track inventory registration parameters
                  await AuditService().logAction(
                    buildingId: buildingId,
                    action: "PROFILE_UPDATES",
                    result: "success",
                    details: "Registered a new ${type} parking stall configuration: Slot ${slotNo.text}.",
                    fallbackUserName: adminName,
                  );

                  FeedbackUtil.success();
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  // ⚡ FAILURE LOG: Capture storage constraint failure events
                  await AuditService().logAction(
                    buildingId: buildingId,
                    action: "PROFILE_UPDATES",
                    result: "failure",
                    details: "Failed to allocate parking vacancy context for Slot ${slotNo.text}. Error: $e",
                    fallbackUserName: adminName,
                  );
                  FeedbackUtil.error();
                }
              },
              child: const Text('Add Slot'),
            ),
          ),
        ])),
      )),
    );
  }

  void _showAllocateDialog(Parking p, String buildingId, String adminName) {
    final flatCtrl = TextEditingController(text: p.flatNo ?? '');
    final memberCtrl = TextEditingController(text: p.memberName ?? '');
    final vehicleNo = TextEditingController(text: p.vehicleNo ?? '');
    final vehicleModel = TextEditingController(text: p.vehicleModel ?? '');
    showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Slot ${p.slotNo} — ${p.status == 'allocated' ? 'Edit Allocation' : 'Allocate'}',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          AppTextField(label: 'Flat No.', hint: 'A-101', controller: flatCtrl),
          const SizedBox(height: 14),
          AppTextField(label: 'Member Name', hint: 'John Doe', controller: memberCtrl),
          const SizedBox(height: 14),
          AppTextField(label: 'Vehicle No.', hint: 'KA01AB1234', controller: vehicleNo),
          const SizedBox(height: 14),
          AppTextField(label: 'Vehicle Model', hint: 'Honda City', controller: vehicleModel),
          const SizedBox(height: 24),
          Row(children: [
            if (p.status == 'allocated')
              Expanded(child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: OutlinedButton(
                  onPressed: () async {
                    FeedbackUtil.error();
                    try {
                      await _db.update('parking', p.id, {'status': 'vacant', 'flatNo': null, 'memberName': null, 'vehicleNo': null, 'vehicleModel': null});

                      // ⚡ SUCCESS LOG: Track deallocation event metrics
                      await AuditService().logAction(
                        buildingId: buildingId,
                        action: "REQUEST_REJECTIONS",
                        result: "success",
                        details: "Cleared active residential parking allocation profile from Stall ${p.slotNo}.",
                        fallbackUserName: adminName,
                      );

                      FeedbackUtil.success();
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      // ⚡ FAILURE LOG: Document mutation database exception block
                      await AuditService().logAction(
                        buildingId: buildingId,
                        action: "REQUEST_REJECTIONS",
                        result: "failure",
                        details: "Failed to drop active assignments for Stall ${p.slotNo}. Error: $e",
                        fallbackUserName: adminName,
                      );
                      FeedbackUtil.error();
                    }
                  },
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
                  child: const Text('Deallocate'),
                ),
              )),
            Expanded(child: ElevatedButton(
              onPressed: () async {
                FeedbackUtil.medium();
                try {
                  await _db.update('parking', p.id, {
                    'status': 'allocated', 'flatNo': flatCtrl.text,
                    'memberName': memberCtrl.text, 'vehicleNo': vehicleNo.text, 'vehicleModel': vehicleModel.text,
                  });

                  // ⚡ SUCCESS LOG: Manual ledger assignment synchronization trace
                  await AuditService().logAction(
                    buildingId: buildingId,
                    action: "REQUEST_APPROVAL",
                    result: "success",
                    details: "Allocated Parking Stall ${p.slotNo} to Flat ${flatCtrl.text} (${memberCtrl.text}) for Vehicle ${vehicleNo.text}.",
                    fallbackUserName: adminName,
                  );

                  FeedbackUtil.success();
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  // ⚡ FAILURE LOG: Profile assignment error event catch
                  await AuditService().logAction(
                    buildingId: buildingId,
                    action: "REQUEST_APPROVAL",
                    result: "failure",
                    details: "Allocation process rejected by backend rules on Slot ${p.slotNo} for Flat ${flatCtrl.text}. Error: $e",
                    fallbackUserName: adminName,
                  );
                  FeedbackUtil.error();
                }
              },
              child: const Text('Save'),
            )),
          ]),
        ]),
      ),
    );
  }
}

class _ParkingSlotCard extends StatelessWidget {
  final Parking parking;
  final VoidCallback onTap;
  const _ParkingSlotCard(this.parking, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isAllocated = parking.status == 'allocated';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isAllocated ? AppColors.success.withOpacity(0.3) : AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            FaIcon(parking.type == 'car' ? FontAwesomeIcons.car : FontAwesomeIcons.motorcycle,
                color: isAllocated ? AppColors.success : AppColors.textHint, size: 18),
            StatusBadge(parking.status),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(parking.slotNo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            if (isAllocated && parking.flatNo != null)
              Text('Flat ${parking.flatNo}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            if (isAllocated && parking.vehicleNo != null)
              Text(parking.vehicleNo!, style: const TextStyle(fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.w500)),
          ]),
        ]),
      ),
    );
  }
}