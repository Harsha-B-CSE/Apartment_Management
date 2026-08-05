import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../shared/services/auth_provider.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/utils/feedback_util.dart';

class GuardDashboardScreen extends StatefulWidget {
  const GuardDashboardScreen({super.key});

  @override
  State<GuardDashboardScreen> createState() => _GuardDashboardScreenState();
}

class _GuardDashboardScreenState extends State<GuardDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _updateStatus(String docId, String newStatus) async {
    FeedbackUtil.medium();
    try {
      await FirebaseFirestore.instance.collection('visitors').doc(docId).update({
        'status': newStatus,
        if (newStatus == 'entered') 'entryTime': FieldValue.serverTimestamp(),
        if (newStatus == 'exited') 'exitTime': FieldValue.serverTimestamp(),
      });
      FeedbackUtil.success();
    } catch (e) {
      FeedbackUtil.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Widget _buildVisitorList(List<QueryDocumentSnapshot> docs, String type) {
    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text("No $type visitors", style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (context, i) {
        final d = docs[i].data() as Map<String, dynamic>;
        final String docId = docs[i].id;
        final String visitorName = d['visitorName']?.toString() ?? d['name']?.toString() ?? 'Visitor';
        final String purpose = d['notes']?.toString() ?? d['purpose']?.toString() ?? 'General Visit';
        final String flatNo = d['flatNo']?.toString() ?? 'N/A';
        final String status = d['status']?.toString().toLowerCase() ?? 'expected';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: status == 'expected' ? Colors.orange : (status == 'entered' ? Colors.green : Colors.grey),
              child: const Icon(Icons.person, color: Colors.white),
            ),
            title: Text(visitorName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Flat $flatNo • $purpose'),
            trailing: _buildTrailingAction(status, docId),
          ),
        );
      },
    );
  }

  Widget? _buildTrailingAction(String status, String docId) {
    if (status == 'expected') {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green, 
          foregroundColor: Colors.white,
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        onPressed: () => _updateStatus(docId, 'entered'),
        child: const Text('Check In'),
      );
    } else if (status == 'entered') {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey, 
          foregroundColor: Colors.white,
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        onPressed: () => _updateStatus(docId, 'exited'),
        child: const Text('Check Out'),
      );
    }
    return StatusBadge(status);
  }

  void _showAddWalkInVisitor(BuildContext context, String buildingId, String? guardAssignedWing) async {
    final nameCtrl = TextEditingController();
    final purposeCtrl = TextEditingController();
    String? selectedMemberUid;
    String? selectedFlat;
    String? selectedMemberName;
    bool loading = false;

    final memberSnap = await FirebaseFirestore.instance.collection('users')
        .where('buildingId', isEqualTo: buildingId)
        .where('role', isEqualTo: 'member')
        .get();
    
    final String assignedWing = guardAssignedWing ?? 'ALL';
    final bool isMasterGuard = assignedWing == 'All Buildings (Master Guard)' || assignedWing == 'ALL' || assignedWing == 'N/A';

    final members = memberSnap.docs.map((d) => {'uid': d.id, ...d.data()}).where((m) {
      if (isMasterGuard) return true;
      final flatNo = m['flatNo']?.toString().toLowerCase() ?? '';
      return flatNo.contains(assignedWing.toLowerCase().trim());
    }).toList();

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Log Walk-In Visitor", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              AppTextField(label: 'Visitor Name', controller: nameCtrl),
              const SizedBox(height: 15),
              AppTextField(label: 'Purpose (e.g. Delivery)', controller: purposeCtrl),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: selectedMemberUid,
                hint: const Text('Select Target Flat'),
                decoration: const InputDecoration(filled: true, fillColor: AppColors.surfaceVariant),
                items: members.map((m) {
                  return DropdownMenuItem<String>(
                    value: m['uid'],
                    child: Text('Flat ${m['flatNo']} - ${m['name']}'),
                  );
                }).toList(),
                onChanged: (val) {
                  final m = members.firstWhere((element) => element['uid'] == val);
                  setSheetState(() {
                    selectedMemberUid = val;
                    selectedFlat = m['flatNo'];
                    selectedMemberName = m['name'];
                  });
                },
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: loading ? null : () async {
                    if (nameCtrl.text.isEmpty || selectedMemberUid == null) {
                      FeedbackUtil.error();
                      return;
                    }
                    setSheetState(() => loading = true);
                    FeedbackUtil.medium();
                    try {
                      final uid = Provider.of<AuthProvider>(context, listen: false).user?.uid;
                      
                      // Process Guard's Assigned Wing for Walk-in
                      final String assignedWing = guardAssignedWing ?? 'ALL';
                      final bool isMasterGuard = assignedWing == 'All Buildings (Master Guard)' || assignedWing == 'ALL' || assignedWing == 'N/A';
                      
                      String finalFlatNo = selectedFlat ?? 'N/A';
                      if (!isMasterGuard && !finalFlatNo.contains(assignedWing)) {
                        finalFlatNo = '$finalFlatNo ($assignedWing)';
                      }

                      await FirestoreService().add('visitors', {
                        'buildingId': buildingId,
                        'hostUid': selectedMemberUid,
                        'memberUid': selectedMemberUid,
                        'memberName': selectedMemberName,
                        'visitorName': nameCtrl.text.trim(),
                        'purpose': purposeCtrl.text.trim(),
                        'notes': 'Walk-In Logged by Gate',
                        'flatNo': finalFlatNo,
                        'status': 'entered',
                        'entryTime': FieldValue.serverTimestamp(),
                        'loggedByGuard': uid,
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                      FeedbackUtil.success();
                    } catch (e) {
                      FeedbackUtil.error();
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    } finally {
                      if (ctx.mounted) setSheetState(() => loading = false);
                    }
                  },
                  child: loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('ALLOW ENTRY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: "Expected"),
              Tab(text: "Inside"),
              Tab(text: "History"),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddWalkInVisitor(context, user.buildingId, user.flatNo),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Walk-In', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('visitors')
            .where('buildingId', isEqualTo: user.buildingId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text("Error: ${snap.error}"));
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final docsCopy = List<QueryDocumentSnapshot>.from(snap.data?.docs ?? []);
          // Local ordering newest first based on entryTime or createdAt
          docsCopy.sort((a, b) {
            try {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aRaw = aData['entryTime'] ?? aData['createdAt'];
              final bRaw = bData['entryTime'] ?? bData['createdAt'];
              final aTime = aRaw is Timestamp ? aRaw : Timestamp.now();
              final bTime = bRaw is Timestamp ? bRaw : Timestamp.now();
              return bTime.compareTo(aTime);
            } catch (e) {
              return 0;
            }
          });

          final String assignedWing = user.flatNo ?? 'ALL';
          final bool isMasterGuard = assignedWing == 'All Buildings (Master Guard)' || assignedWing == 'ALL' || assignedWing == 'N/A';

          final filteredDocs = docsCopy.where((d) {
            if (isMasterGuard) return true;
            final visitorFlatNo = (d.data() as Map<String, dynamic>)['flatNo']?.toString().toLowerCase() ?? '';
            return visitorFlatNo.contains(assignedWing.toLowerCase().trim());
          }).toList();

          final expected = filteredDocs.where((d) => ((d.data() as Map<String, dynamic>)['status']?.toString().toLowerCase().trim() ?? 'expected') == 'expected').toList();
          final inside = filteredDocs.where((d) => ((d.data() as Map<String, dynamic>)['status']?.toString().toLowerCase().trim() ?? 'expected') == 'entered').toList();
          final history = filteredDocs.where((d) {
            final status = (d.data() as Map<String, dynamic>)['status']?.toString().toLowerCase().trim() ?? 'expected';
            return status == 'exited' || status == 'rejected';
          }).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildVisitorList(expected, 'Expected'),
              _buildVisitorList(inside, 'Inside'),
              _buildVisitorList(history, 'History'),
            ],
          );
        },
      ),
    );
  }
}
