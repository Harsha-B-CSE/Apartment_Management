/*
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../shared/services/auth_provider.dart';
import '../../core/theme.dart';
import '../../shared/utils/feedback_util.dart'; // ⚡ Import the unified haptics utility

class AdminShell extends StatelessWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    final bool isDashboard = location == '/admin';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (!isDashboard) {
          FeedbackUtil.light(); // ⚡ Navigation fall-back trigger
          context.go('/admin');
          return;
        }

        FeedbackUtil.error(); // ⚡ Alert critical warning vibration on back attempt

        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Exit App?"),
            content: const Text("Do you want to close the application?"),
            actions: [
              TextButton(
                onPressed: () {
                  FeedbackUtil.light();
                  Navigator.pop(ctx, false);
                },
                child: const Text("CANCEL"),
              ),
              TextButton(
                onPressed: () {
                  FeedbackUtil.error(); // ⚡ Explicit application shutdown heavy alert
                  Navigator.pop(ctx, true);
                },
                child: const Text("EXIT", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );

        if (shouldExit == true) {
          SystemChannels.platform.invokeMethod('SystemNavigator.pop');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Admin Panel"),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        drawer: const _AdminDrawer(),
        body: child,
      ),
    );
  }
}

// lib/features/admin/presentation/screens/admin_shell.dart

class _AdminDrawer extends StatelessWidget {
  const _AdminDrawer();

  @override
  Widget build(BuildContext context) {
    // ✅ CRITICAL FIX: Use context.watch to safely monitor and adapt to auth changes smoothly
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.user;

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: AppColors.primary),
            // ✅ CRITICAL FIX: Safe, explicit null string fallbacks prevent layout crashes during deletions
            accountName: Text(currentUser?.name ?? 'Admin Session'),
            accountEmail: Text(currentUser?.email ?? 'Updating configuration...'),
            currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white24,
                child: Icon(Icons.admin_panel_settings, color: Colors.white)
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _drawerTile(context, Icons.dashboard, "Dashboard", "/admin"),
                _drawerTile(context, Icons.people, "Members", "/admin/members"),
                _drawerTile(context, Icons.door_front_door, "Flats", "/admin/flats"),
                _drawerTile(context, Icons.warning_amber_rounded, "Complaints", "/admin/complaints"),
                _drawerTile(context, Icons.person_add, "Visitors", "/admin/visitors"),
                _drawerTile(context, Icons.local_parking, "Parking", "/admin/parking"),
                _drawerTile(context, Icons.build_circle, "Service Requests", "/admin/service-requests"),
                _drawerTile(context, Icons.settings_suggest, "Manage Services", "/admin/services"),
                _drawerTile(context, Icons.business, "Buildings", "/admin/buildings"),
                _drawerTile(context, Icons.campaign, "Notifications", "/admin/notifications"),
                const Divider(),
                _drawerTile(context, Icons.person, "My Profile", "/admin/profile"),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout", style: TextStyle(color: Colors.red)),
            onTap: () async {
              FeedbackUtil.medium();
              Navigator.pop(context);
              await authProvider.signOut();
              if (context.mounted) context.go('/login');
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _drawerTile(BuildContext context, IconData icon, String title, String route) {
    final bool isActive = GoRouterState.of(context).uri.toString() == route;
    return ListTile(
      leading: Icon(icon, color: isActive ? AppColors.primary : null),
      title: Text(title, style: TextStyle(fontWeight: isActive ? FontWeight.bold : null)),
      selected: isActive,
      onTap: () {
        FeedbackUtil.light();
        Navigator.pop(context);
        context.go(route);
      },
    );
  }
}
*/
// lib/features/admin/presentation/screens/admin_shell.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/services/auth_provider.dart';
import '../../core/theme.dart';
import '../../shared/utils/feedback_util.dart';
import '../../shared/utils/predictive_maintenance.dart';

class AdminShell extends StatefulWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  bool _hasInitialDataLoaded = false;

  @override
  void initState() {
    super.initState();
    // 🛡️ Ensure context is fully mounted before kicking off our stream listener
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initNotificationPipeline();
      
      // 🧠 TRIGGER AI PREDICTIVE MAINTENANCE
      final user = context.read<AuthProvider>().user;
      if (user != null && user.buildingId.isNotEmpty) {
        PredictiveMaintenance.triggerAnalysis(user.buildingId);
      }
    });
  }

  void _initNotificationPipeline() {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    // Safety clean: Kill any existing subscription listeners to prevent duplicate instances
    _notificationSubscription?.cancel();

    _notificationSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('buildingId', isEqualTo: user.buildingId)
        .snapshots()
        .listen((snapshot) {
      // 🛑 PREVENT POPUP FLOOD: Ignore the very first snapshot load of old entries
      if (!_hasInitialDataLoaded) {
        _hasInitialDataLoaded = true;
        return;
      }

      for (var change in snapshot.docChanges) {
        // 🔔 Only trigger an alert dialog for real-time fresh additions
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>?;
          if (data != null) {
            FeedbackUtil.medium(); // Haptic alert pulse
            _triggerSystemAlertDialog(
              context,
              data['title'] ?? 'System Announcement',
              data['body'] ?? 'A new management update has been published.',
            );
          }
        }
      }
    }, onError: (error) {
      debugPrint("Silent notification listener block: $error");
    });
  }

  void _triggerSystemAlertDialog(BuildContext context, String title, String body) {
    showDialog(
      context: context,
      barrierDismissible: false, // Forces intentional dismissal
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.notifications_active, color: Colors.purple, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text(body, style: const TextStyle(fontSize: 13, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () {
              FeedbackUtil.light();
              Navigator.pop(ctx);
            },
            child: const Text(
              "DISMISS",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // 🧼 Clean cleanup footprint on unmount/sign-out sequences
    _notificationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    final bool isDashboard = location == '/admin';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (!isDashboard) {
          FeedbackUtil.light();
          context.go('/admin');
          return;
        }

        FeedbackUtil.error();

        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Exit App?"),
            content: const Text("Do you want to close the application?"),
            actions: [
              TextButton(
                onPressed: () {
                  FeedbackUtil.light();
                  Navigator.pop(ctx, false);
                },
                child: const Text("CANCEL"),
              ),
              TextButton(
                onPressed: () {
                  FeedbackUtil.error();
                  Navigator.pop(ctx, true);
                },
                child: const Text("EXIT", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );

        if (shouldExit == true) {
          SystemChannels.platform.invokeMethod('SystemNavigator.pop');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Admin Panel"),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        drawer: const _AdminDrawer(),
        body: widget.child,
      ),
    );
  }
}

class _AdminDrawer extends StatelessWidget {
  const _AdminDrawer();

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.user;

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: AppColors.primary),
            accountName: Text(currentUser?.name ?? 'Admin Session'),
            accountEmail: Text(currentUser?.email ?? 'Updating configuration...'),
            currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white24,
                child: Icon(Icons.admin_panel_settings, color: Colors.white)
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _drawerTile(context, Icons.dashboard, "Dashboard", "/admin"),
                _drawerTile(context, Icons.people, "Members", "/admin/members"),
                _drawerTile(context, Icons.door_front_door, "Flats", "/admin/flats"),
                _drawerTile(context, Icons.warning_amber_rounded, "Complaints", "/admin/complaints"),
                _drawerTile(context, Icons.person_add, "Visitors", "/admin/visitors"),
                _drawerTile(context, Icons.local_parking, "Parking", "/admin/parking"),
                _drawerTile(context, Icons.build_circle, "Service Requests", "/admin/service-requests"),
                _drawerTile(context, Icons.settings_suggest, "Manage Services", "/admin/services"),
                _drawerTile(context, Icons.business, "Buildings", "/admin/buildings"),
                _drawerTile(context, Icons.receipt_long, "Payments", "/admin/payments"),
                _drawerTile(context, Icons.campaign, "Notifications", "/admin/notifications"),
                const Divider(),
                _drawerTile(context, Icons.person, "My Profile", "/admin/profile"),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout", style: TextStyle(color: Colors.red)),
            onTap: () async {
              FeedbackUtil.medium();
              Navigator.pop(context);
              await authProvider.signOut();
              if (context.mounted) context.go('/login');
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _drawerTile(BuildContext context, IconData icon, String title, String route) {
    final bool isActive = GoRouterState.of(context).uri.toString() == route;
    return ListTile(
      leading: Icon(icon, color: isActive ? AppColors.primary : null),
      title: Text(title, style: TextStyle(fontWeight: isActive ? FontWeight.bold : null)),
      selected: isActive,
      onTap: () {
        FeedbackUtil.light();
        Navigator.pop(context);
        context.go(route);
      },
    );
  }
}