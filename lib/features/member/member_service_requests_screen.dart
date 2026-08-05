// lib/features/member/presentation/screens/member_service_requests_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../shared/services/auth_provider.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../core/theme.dart';
import '../../shared/utils/feedback_util.dart';

class MemberServiceRequestsScreen extends StatelessWidget {
  const MemberServiceRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: buildMemberAppBar(context, 'Service Requests'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          FeedbackUtil.light();
          _showRequestModal(context, user.uid, user.buildingId, user.name, user.flatNo ?? 'N/A');
        },
        label: const Text("New Request", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.build, color: Colors.white),
        backgroundColor: AppColors.primary,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('service_requests')
            .where('buildingId', isEqualTo: user.buildingId)
            .where('memberUid', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text("Error: ${snap.error}"));
          if (snap.connectionState == ConnectionState.waiting) return const LoadingList(count: 3);
          if (snap.data == null || snap.data!.docs.isEmpty) {
            return const Center(child: Text("No requests found.", style: TextStyle(color: AppColors.textSecondary)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snap.data!.docs.length,
            itemBuilder: (context, i) {
              final d = snap.data!.docs[i].data() as Map<String, dynamic>;

              final String serviceName = d['serviceName'] ?? 'Service Request';
              final String requestStatus = d['status'] ?? 'pending';
              final String notesText = d['notes'] ?? 'General maintenance requirement.';

              // ✅ FIXED: Case-safely handles 'adminNote' strings matching your DB configuration rules
              final String adminRemark = d['adminNote'] ?? d['adminNotes'] ?? '';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ExpansionTile(
                  shape: const Border(),
                  collapsedShape: const Border(),
                  title: Text(serviceName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                  subtitle: Text("Status: ${requestStatus.toUpperCase()}", style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  trailing: StatusBadge(requestStatus),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(),
                          const SizedBox(height: 6),
                          const Text("My Details / Notes:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                          const SizedBox(height: 2),
                          Text(notesText, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.3)),

                          // ✅ FIXED: Dynamically injects management feedback container when populated
                          if (adminRemark.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange.withOpacity(0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.admin_panel_settings, size: 16, color: Colors.orange),
                                      SizedBox(width: 6),
                                      Text("Management Update:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                      adminRemark,
                                      style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: AppColors.textPrimary, height: 1.3)
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showRequestModal(BuildContext context, String uid, String bId, String name, String flatNo) {
    String? selectedServiceId;
    String? selectedServiceName;
    double selectedServiceCost = 0.0;
    
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;
    
    List<Map<String, dynamic>> availableServices = [];
    bool fetchingServices = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          if (fetchingServices) {
            FirebaseFirestore.instance
                .collection('services')
                .where('buildingId', isEqualTo: bId)
                .where('isActive', isEqualTo: true)
                .get()
                .then((snap) {
              if (context.mounted) {
                setModalState(() {
                  availableServices = snap.docs.map((d) {
                    final data = d.data();
                    return {
                      'id': d.id,
                      'name': data['name'] ?? '',
                      'cost': (data['cost'] ?? 0.0).toDouble(),
                    };
                  }).toList();
                  fetchingServices = false;
                });
              }
            });
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 10),
                const Text("Request a Service", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 20),
                
                const Text('Service Needed', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedServiceId,
                  hint: Text(fetchingServices ? 'Loading services...' : (availableServices.isEmpty ? 'No services available' : 'Select a Service')),
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  dropdownColor: AppColors.surface,
                  items: availableServices.map((srv) {
                    final double cost = srv['cost'];
                    final String costStr = cost > 0 ? ' (₹${cost.toStringAsFixed(0)})' : ' (Free)';
                    return DropdownMenuItem<String>(
                      value: srv['id'],
                      child: Text('${srv['name']}$costStr', style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                    );
                  }).toList(),
                  onChanged: (fetchingServices || availableServices.isEmpty) ? null : (val) {
                    FeedbackUtil.light();
                    setModalState(() {
                      selectedServiceId = val;
                      final srv = availableServices.firstWhere((s) => s['id'] == val);
                      selectedServiceName = srv['name'];
                      selectedServiceCost = srv['cost'];
                    });
                  },
                  validator: (v) => v == null ? 'Please select a service' : null,
                ),
                const SizedBox(height: 15),

                AppTextField(
                  label: "Description",
                  hint: "Explain the requirement",
                  controller: noteController,
                  maxLines: 2,
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: loading ? null : () async {
                      if (!formKey.currentState!.validate()) {
                        FeedbackUtil.error();
                        return;
                      }

                      FeedbackUtil.medium();
                      setModalState(() => loading = true);

                      try {
                        // 1. Create the Service Request
                        await FirebaseFirestore.instance.collection('service_requests').add({
                          'buildingId': bId,
                          'memberUid': uid,
                          'memberName': name,
                          'flatNo': flatNo,
                          'serviceId': selectedServiceId,
                          'serviceName': selectedServiceName,
                          'notes': noteController.text.trim(),
                          'status': 'pending',
                          'createdAt': FieldValue.serverTimestamp(),
                        });

                        // 2. Automatically generate a Payment Due record if the service costs money
                        if (selectedServiceCost > 0) {
                          // The user requested: "it show flat no and building name and serviced guy and amount "
                          // Let's create a detailed title string. We don't have the exact Society name here easily, 
                          // but we have flatNo and member name. 
                          final paymentTitle = "Service Request: $selectedServiceName (Flat $flatNo, $name)";

                          await FirebaseFirestore.instance.collection('payments').add({
                            'buildingId': bId,
                            'title': paymentTitle,
                            'amount': selectedServiceCost,
                            'targetUid': uid,
                            'flatNo': flatNo,
                            'status': 'pending',
                            'dueDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 10))), // "10 days from service"
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                        }

                        FeedbackUtil.success();
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        FeedbackUtil.error();
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
                          );
                        }
                      } finally {
                        if (ctx.mounted) setModalState(() => loading = false);
                      }
                    },
                    child: loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text("SUBMIT REQUEST", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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