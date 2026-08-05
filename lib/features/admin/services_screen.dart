// lib/features/admin/presentation/screens/services_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/theme.dart';
import '../../shared/models/service.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/services/auth_provider.dart';
import '../../shared/widgets/app_widgets.dart';
import 'admin_shell.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/utils/feedback_util.dart';
import '../../shared/services/audit_service.dart';

class AdminServicesScreen extends StatelessWidget {
  const AdminServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = FirestoreService();
    final user = context.watch<AuthProvider>().user;

    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: buildAdminAppBar(context, 'Services'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          FeedbackUtil.light();
          _showDialog(context, db, user.buildingId, user.name);
        },
        backgroundColor: AppColors.primary,
        icon: const FaIcon(FontAwesomeIcons.plus, size: 14, color: Colors.white),
        label: const Text('Add Service', style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: db.streamFiltered('services', buildingId: user.buildingId, orderBy: 'name', descending: false),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text("Access Blocked: ${snap.error}", textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
              ),
            );
          }
          if (!snap.hasData) return const LoadingList();
          if (snap.data!.docs.isEmpty){
            return EmptyState(
              icon: FontAwesomeIcons.screwdriverWrench,
              title: 'No Services',
              subtitle: 'Add services that members can request',
              actionLabel: 'Add Service',
              onAction: () {
                FeedbackUtil.light();
                _showDialog(context, db, user.buildingId, user.name);
              },
            );
          }

          return ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: snap.data!.docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final s = Service.fromDoc(snap.data!.docs[i]);
              return _ServiceCard(
                s,
                onEdit: () {
                  FeedbackUtil.light();
                  _showDialog(context, db, user.buildingId, user.name, service: s);
                },
                onToggle: () async {
                  FeedbackUtil.light();
                  final bool targetStatus = !s.isActive;

                  try {
                    await db.update('services', s.id, {'isActive': targetStatus});

                    await AuditService().logAction(
                      buildingId: user.buildingId,
                      action: "PROFILE_UPDATES",
                      result: "success",
                      details: "Toggled service state availability for '${s.name}' to ${targetStatus ? 'Active' : 'Inactive'}.",
                      fallbackUserName: user.name,
                    );
                  } catch (e) {
                    await AuditService().logAction(
                      buildingId: user.buildingId,
                      action: "PROFILE_UPDATES",
                      result: "failure",
                      details: "Failed to toggle service visibility parameter state for '${s.name}'. Error: $e",
                      fallbackUserName: user.name,
                    );
                  }
                },
                onDelete: () async {
                  FeedbackUtil.error();
                  final ok = await showConfirmDialog(
                    context,
                    title: 'Delete Service',
                    message: 'This service will no longer be available to members.',
                    isDanger: true,
                    confirmLabel: 'Delete',
                  );
                  if (ok == true) {
                    FeedbackUtil.error();
                    try {
                      await db.delete('services', s.id);

                      await AuditService().logAction(
                        buildingId: user.buildingId,
                        action: "BUILDING_DELETION",
                        result: "success",
                        details: "Purged custom category catalog service '${s.name}' from building inventory registers.",
                        fallbackUserName: user.name,
                      );
                      FeedbackUtil.success();
                    } catch (e) {
                      await AuditService().logAction(
                        buildingId: user.buildingId,
                        action: "BUILDING_DELETION",
                        result: "failure",
                        details: "Failed to delete catalog service element '${s.name}'. Error: $e",
                        fallbackUserName: user.name,
                      );
                    }
                  } else {
                    FeedbackUtil.light();
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showDialog(BuildContext context, FirestoreService db, String buildingId, String adminName, {Service? service}) {
    final name = TextEditingController(text: service?.name ?? '');
    final desc = TextEditingController(text: service?.description ?? '');
    final costController = TextEditingController(text: service != null ? (service.cost > 0 ? service.cost.toStringAsFixed(2) : '0') : '');
    String category = service?.category ?? 'Maintenance';
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx2).viewInsets.bottom + 20),
          // ✅ FIX: Wrapped with a scrollable container to prevent soft keyboard rendering layout overflow crashes
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(service == null ? 'Add Service' : 'Edit Service', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 20),
                  AppTextField(label: 'Service Name', hint: 'Plumbing Repair', controller: name, validator: (v) => v!.isEmpty ? 'Required' : null),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: AppDropdown<String>(
                          labelText: 'Category',
                          value: category,
                          items: ['Maintenance','Cleaning','Security','Utilities','Other']
                              .map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (v) {
                            FeedbackUtil.light();
                            setS(() => category = v!);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppTextField(
                          label: 'Cost (₹)',
                          hint: '0 for free',
                          controller: costController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) {
                            if (v != null && v.isNotEmpty && double.tryParse(v) == null) {
                              return 'Invalid amount';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  AppTextField(label: 'Description', hint: 'Describe what this service covers...', controller: desc, maxLines: 3),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) {
                          FeedbackUtil.error();
                          return;
                        }

                        FeedbackUtil.medium();

                        try {
                          final data = {
                            'name': name.text,
                            'description': desc.text,
                            'category': category,
                            'cost': double.tryParse(costController.text) ?? 0.0,
                            'isActive': service?.isActive ?? true,
                            'buildingId': buildingId,
                          };
                          if (service == null) {
                            await db.add('services', data);
                          } else {
                            await db.update('services', service.id, data);
                          }

                          await AuditService().logAction(
                            buildingId: buildingId,
                            action: service == null ? "BUILDING_CREATION" : "PROFILE_UPDATES",
                            result: "success",
                            details: service == null
                                ? "Appended a new catalog service: '${name.text}' under section '$category' (Cost: ₹${data['cost']})."
                                : "Modified baseline parameters for service item entry '${name.text}'.",
                            fallbackUserName: adminName,
                          );

                          FeedbackUtil.success();
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          await AuditService().logAction(
                            buildingId: buildingId,
                            action: service == null ? "BUILDING_CREATION" : "PROFILE_UPDATES",
                            result: "failure",
                            details: "Failed to persist service mutations for element target '${name.text}'. Error: $e",
                            fallbackUserName: adminName,
                          );
                          FeedbackUtil.error();
                        }
                      },
                      child: Text(service == null ? 'Add Service' : 'Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final Service service;
  final VoidCallback onEdit, onToggle, onDelete;
  const _ServiceCard(this.service, {required this.onEdit, required this.onToggle, required this.onDelete});

  static const _categoryIcons = {
    'Maintenance': FontAwesomeIcons.screwdriverWrench,
    'Cleaning': FontAwesomeIcons.broom,
    'Security': FontAwesomeIcons.shieldHalved,
    'Utilities': FontAwesomeIcons.bolt,
    'Other': FontAwesomeIcons.circleInfo,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: (service.isActive ? AppColors.primary : AppColors.textHint).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: FaIcon(
                _categoryIcons[service.category] ?? FontAwesomeIcons.gear,
                color: service.isActive ? AppColors.primary : AppColors.textHint,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: service.isActive ? AppColors.textPrimary : AppColors.textHint,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(service.category, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    if (service.cost > 0) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text('·', style: TextStyle(color: AppColors.textHint, fontSize: 11)),
                      ),
                      Text('₹${service.cost.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
                if (service.description.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    service.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textHint, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: service.isActive,
            onChanged: (_) => onToggle(),
            activeColor: AppColors.success,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              FeedbackUtil.light();
              if (v == 'edit') onEdit();
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.danger))),
            ],
          ),
        ],
      ),
    );
  }
}