// lib/features/profile/presentation/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/services/auth_provider.dart';
import '../../core/theme.dart';
import '../../shared/utils/feedback_util.dart'; // ⚡ Import the unified haptics utility

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text("My Profile"), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const CircleAvatar(radius: 50, backgroundColor: AppColors.primary, child: Icon(Icons.person, size: 50, color: Colors.white)),
          const SizedBox(height: 16),
          Text(user.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(user.email, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 10),
          Chip(label: Text(user.role.toUpperCase()), backgroundColor: AppColors.primary.withOpacity(0.1)),

          const SizedBox(height: 40),
          _ProfileTile(icon: Icons.home, title: "Building ID", subtitle: user.buildingId),
          _ProfileTile(icon: Icons.apartment, title: "Flat Number", subtitle: user.flatNo ?? "Not assigned"),
          _ProfileTile(icon: Icons.phone, title: "Phone", subtitle: user.phone),

          const SizedBox(height: 40),
          const SizedBox(height: 40),
          if (user.role != 'admin' && user.flatNo != null && user.flatNo != 'N/A')
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () async {
                  FeedbackUtil.medium();
                  await _showVacateDisclaimerDialog(context, user);
                },
                icon: const Icon(Icons.exit_to_app, color: Colors.orange),
                label: const Text("VACATE FLAT", style: TextStyle(color: Colors.orange)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.orange)),
              ),
            ),
          if (user.role != 'admin' && user.flatNo != null && user.flatNo != 'N/A')
            const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () async {
                // ⚡ Medium impact tap confirmation when checking systemic lifecycle actions
                FeedbackUtil.medium();
                final confirm = await _showLogoutDialog(context);
                if (confirm == true) {
                  // ⚡ Dynamic session-clear haptic bump
                  FeedbackUtil.medium();
                  await auth.signOut();

                  // ⚡ Success feedback pattern after session destroys cleanly
                  FeedbackUtil.success();
                  if (context.mounted) context.go('/login'); // ✅ Clean jump to login
                }
              },
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text("SIGN OUT", style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _showVacateDisclaimerDialog(BuildContext rootContext, dynamic user) async {
    showDialog(
      context: rootContext,
      builder: (ctx) => AlertDialog(
        title: const Text("Vacate Disclaimer"),
        content: const Text(
          "Please read before vacating:\n\n"
          "• While moving your items make sure to follow safety precautions.\n"
          "• Make sure not to damage properties of others while moving.\n"
          "• Clear any unpaid dues before leaving.",
        ),
        actions: [
          TextButton(
            onPressed: () {
              FeedbackUtil.light();
              Navigator.pop(ctx);
            },
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              FeedbackUtil.medium();
              try {
                // Create a vacate request in service_requests
                await FirebaseFirestore.instance.collection('service_requests').add({
                  'buildingId': user.buildingId,
                  'memberUid': user.uid,
                  'memberName': user.name,
                  'flatNo': user.flatNo,
                  'serviceName': 'Vacate Flat Request',
                  'cost': 0,
                  'status': 'pending',
                  'adminNote': 'Tenant has requested to vacate the flat and agreed to the disclaimer.',
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(rootContext).showSnackBar(
                    const SnackBar(content: Text("Vacate request sent to admin."), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                FeedbackUtil.error();
                if (ctx.mounted) {
                  ScaffoldMessenger.of(rootContext).showSnackBar(
                    SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text("AGREE & REQUEST", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showLogoutDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Sign Out"),
        content: const Text("Are you sure you want to exit?"),
        actions: [
          TextButton(
            onPressed: () {
              FeedbackUtil.light(); // ⚡ Smooth micro-interaction cancel touch response
              Navigator.pop(ctx, false);
            },
            child: const Text("CANCEL"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("SIGN OUT"),
          ),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _ProfileTile({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black)),
    );
  }
}