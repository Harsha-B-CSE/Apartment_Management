// lib/features/member/presentation/screens/member_parking_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../shared/services/auth_provider.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../core/theme.dart';
import '../../shared/utils/feedback_util.dart'; // ⚡ Import the unified haptics utility

class MemberParkingScreen extends StatelessWidget {
  const MemberParkingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: buildMemberAppBar(context, 'My Parking'),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Column(children: [
              const Icon(Icons.local_parking, size: 50, color: Colors.blue),
              const SizedBox(height: 10),
              const Text("Assigned Parking Slots", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              Text(
                  "${user.parkingSlotsCount}",
                  style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: Colors.blue)
              ),
            ]),
          ),
          const SizedBox(height: 32),
          const Text(
            "Each resident receives 1 default parking slot. If you require an additional space, please submit a request below.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: () {
                // ⚡ Medium impact provides interactive tactile validation response on tap
                FeedbackUtil.medium();
                _requestExtraSlot(
                    context,
                    user.uid,
                    user.buildingId,
                    user.name,
                    user.flatNo ?? 'N/A'
                );
              },
              icon: const Icon(Icons.add_circle_outline, color: Colors.white),
              label: const Text("REQUEST EXTRA SLOT", style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _requestExtraSlot(BuildContext context, String uid, String bId, String name, String flatNo) async {
    try {
      // ✅ FIXED: Write to service_requests so Admin can actually see and action this
      await FirebaseFirestore.instance.collection('service_requests').add({
        'memberUid': uid,
        'memberName': name,
        'flatNo': flatNo,
        'buildingId': bId,
        'serviceName': 'Extra Parking Slot',
        'notes': 'Resident requested an additional parking space.',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // ⚡ Success feedback sequence once transaction successfully streams to cloud store
      FeedbackUtil.success();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Parking request submitted to Admin! Check Service Requests for updates."))
        );
      }
    } catch (e) {
      // ⚡ Failure warning pulse if operational network disruptions occur
      FeedbackUtil.error();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Request Failed: $e"), backgroundColor: Colors.red)
        );
      }
    }
  }
}