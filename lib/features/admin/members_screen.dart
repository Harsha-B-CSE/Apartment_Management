// lib/features/admin/presentation/screens/members_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../shared/services/auth_provider.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/utils/feedback_util.dart';
import '../../shared/services/audit_service.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../core/theme.dart';

class MembersScreen extends StatelessWidget {
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AuthProvider>().user;
    if (admin == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text("Building Residents & Staff")),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddGuardDialog(context, admin.buildingId),
        icon: const Icon(Icons.security, color: Colors.white),
        label: const Text('Add Guard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users')
            .where('buildingId', isEqualTo: admin.buildingId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text("Error: ${snap.error}", style: const TextStyle(color: Colors.red)));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          
          final docs = snap.data!.docs.where((doc) {
            final role = (doc.data() as Map<String, dynamic>)['role'];
            return role == 'member' || role == 'guard';
          }).toList();

          if (docs.isEmpty) return const Center(child: Text("No members or staff found in this building."));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final d = doc.data() as Map<String, dynamic>;
              final String memberName = d['name'] ?? 'No Name';
              final String flatNo = d['flatNo'] ?? 'N/A';
              final String role = d['role'] ?? 'member';
              final bool currentActiveStatus = d['isActive'] ?? true;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                clipBehavior: Clip.antiAlias, // Ensures the InkWell ripple respects Card corners
                child: InkWell(
                  onTap: () {
                    FeedbackUtil.light(); // ⚡ Instantly registers a light tap response when selecting a resident profile
                  },
                  onLongPress: () async {
                    // ⚡ Medium tactile feedback indicating operational modal option triggering
                    FeedbackUtil.medium();

                    final bool nextStatus = !currentActiveStatus;
                    final String actionLabel = nextStatus ? "MEMBER_ADDITION" : "MEMBER_REMOVAL";

                    try {
                      // 1. Persist the updated state to the tenant document profile
                      await FirebaseFirestore.instance.collection('users').doc(doc.id).update({
                        'isActive': nextStatus,
                      });

                      // ⚡ 2. LOCAL AUDIT SUCCESS LEDGER DISPATCH
                      await AuditService().logAction(
                        buildingId: admin.buildingId,
                        action: actionLabel,
                        result: "success",
                        details: "Changed active status of $memberName (Flat $flatNo) to: ${nextStatus ? 'Active' : 'Inactive'}.",
                        fallbackUserName: admin.name,
                      );

                      FeedbackUtil.success();
                    } catch (e) {
                      // ⚡ 3. LOCAL AUDIT FAILURE LEDGER DISPATCH
                      await AuditService().logAction(
                        buildingId: admin.buildingId,
                        action: actionLabel,
                        result: "failure",
                        details: "Failed to modify structural activity parameter state for member account profile target UID: ${doc.id}. Error: $e",
                        fallbackUserName: admin.name,
                      );

                      FeedbackUtil.error();
                    }
                  },
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: role == 'guard' ? Colors.blueGrey : AppColors.primary,
                      child: Icon(role == 'guard' ? Icons.security : Icons.person, color: Colors.white),
                    ),
                    title: Text(memberName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(role == 'guard' ? "Guard • ${d['phone'] ?? 'No Phone'}" : "Flat: $flatNo • ${d['phone'] ?? 'No Phone'}"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          color: currentActiveStatus ? Colors.green : Colors.red,
                          size: 12
                        ),
                        PopupMenuButton<String>(
                          onSelected: (val) async {
                            if (val == 'toggle') {
                              FeedbackUtil.medium();
                              final bool nextStatus = !currentActiveStatus;
                              try {
                                await FirebaseFirestore.instance.collection('users').doc(doc.id).update({
                                  'isActive': nextStatus,
                                });
                                await AuditService().logAction(
                                  buildingId: admin.buildingId,
                                  action: nextStatus ? "MEMBER_ADDITION" : "MEMBER_REMOVAL",
                                  result: "success",
                                  details: "Changed active status of $memberName (Flat $flatNo) to: ${nextStatus ? 'Active' : 'Inactive'}.",
                                  fallbackUserName: admin.name,
                                );
                                FeedbackUtil.success();
                              } catch (e) {
                                FeedbackUtil.error();
                              }
                            } else if (val == 'delete') {
                              FeedbackUtil.error();
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete Member?'),
                                  content: Text('Are you sure you want to completely remove $memberName? This will also vacate their flat ($flatNo).'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true), 
                                      child: const Text('Delete', style: TextStyle(color: Colors.red))
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                try {
                                  // removeMember handles user deletion AND vacates the flats automatically
                                  await AuthService().removeMember(doc.id, admin.buildingId);
                                  FeedbackUtil.success();
                                } catch (e) {
                                  FeedbackUtil.error();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                  }
                                }
                              }
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'toggle',
                              child: Text(currentActiveStatus ? 'Deactivate Member' : 'Activate Member'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete Member & Vacate Flat', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddGuardDialog(BuildContext context, String buildingId) {
    final name = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    final password = TextEditingController();
    final formKey = GlobalKey<FormState>();
    
    bool loading = false;
    bool fetchingWings = true;
    List<Map<String, String>> availableWings = [];
    String? selectedWing;

    // Fetch buildings/wings
    FirebaseFirestore.instance
        .collection('buildings')
        .where('adminUid', isEqualTo: context.read<AuthProvider>().user?.uid ?? '')
        .get()
        .then((snap) {
      if (snap.docs.isNotEmpty) {
        availableWings = snap.docs.map((d) => {
          'id': d.id,
          'name': d.data()['name'].toString(),
        }).toList();
        // Option to assign to all buildings
        availableWings.insert(0, {'id': 'ALL', 'name': 'All Buildings (Master Guard)'});
      }
    }).catchError((e) {
      print('Error fetching wings for guard: $e');
    }).whenComplete(() {
      fetchingWings = false;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Polling the future completion for UI update without complex futures
          if (fetchingWings) {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (ctx.mounted) setDialogState(() {});
            });
          }

          return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Security Guard', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(label: 'Full Name', controller: name, validator: (v) => v!.isEmpty ? 'Required' : null),
                  const SizedBox(height: 12),
                  AppTextField(label: 'Email', controller: email, keyboardType: TextInputType.emailAddress, validator: (v) => v!.isEmpty ? 'Required' : null),
                  const SizedBox(height: 12),
                  AppTextField(label: 'Phone', controller: phone, keyboardType: TextInputType.phone, validator: (v) => v!.isEmpty ? 'Required' : null),
                  const SizedBox(height: 12),
                  AppTextField(label: 'Password', controller: password, obscureText: true, validator: (v) => (v?.length ?? 0) < 6 ? 'Min 6 chars' : null),
                  const SizedBox(height: 16),
                  const Align(alignment: Alignment.centerLeft, child: Text('Assign to Building', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    value: selectedWing,
                    hint: Text(fetchingWings ? 'Loading buildings...' : (availableWings.isEmpty ? 'No buildings found' : 'Select Building')),
                    items: availableWings.map((w) => DropdownMenuItem(value: w['name'], child: Text(w['name']!))).toList(),
                    onChanged: fetchingWings || availableWings.isEmpty ? null : (val) => setDialogState(() => selectedWing = val),
                    validator: (v) => v == null ? 'Required' : null,
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: Color(0xFFF0F2F5),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(ctx),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: loading ? null : () async {
                if (!formKey.currentState!.validate()) return;
                setDialogState(() => loading = true);
                FeedbackUtil.medium();
                try {
                  await AuthService().createGuardByAdmin(
                    name: name.text.trim(),
                    email: email.text.trim(),
                    phone: phone.text.trim(),
                    password: password.text,
                    buildingId: buildingId,
                    assignedWing: selectedWing!,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  FeedbackUtil.success();
                } catch (e) {
                  FeedbackUtil.error();
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                  }
                } finally {
                  if (ctx.mounted) setDialogState(() => loading = false);
                }
              },
              child: loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('CREATE'),
            ),
          ],
        );
        },
      ),
    );
  }
}