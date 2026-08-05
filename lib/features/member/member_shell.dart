// lib/features/member/presentation/screens/member_shell.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../shared/services/auth_provider.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/utils/feedback_util.dart';

class MemberShell extends StatelessWidget {
  final Widget child;
  const MemberShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    final bool isDashboard = location == '/member';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (!isDashboard) {
          FeedbackUtil.light();
          context.go('/member');
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
        drawer: _MemberDrawer(location: location),
        body: child,
      ),
    );
  }
}

class _MemberDrawer extends StatelessWidget {
  final String location;
  const _MemberDrawer({required this.location});

  // ✅ FIXED: Inserted 'Building Feedback' explicitly into your application's master navigation array
  static const items = [
    _NavItem('/member', FontAwesomeIcons.gaugeHigh, 'Dashboard'),
    _NavItem('/member/complaints', FontAwesomeIcons.triangleExclamation, 'My Complaints'),
    _NavItem('/member/visitors', FontAwesomeIcons.personWalkingArrowRight, 'My Visitors'),
    _NavItem('/member/parking', FontAwesomeIcons.squareParking, 'My Parking'),
    _NavItem('/member/service-requests', FontAwesomeIcons.clipboardList, 'Service Requests'),
    _NavItem('/member/payments', FontAwesomeIcons.fileInvoiceDollar, 'My Payments'),
    _NavItem('/member/feedback', FontAwesomeIcons.solidComments, 'Building Feedback'), // ◄ New live view link entry
    _NavItem('/member/notifications', FontAwesomeIcons.bell, 'Notifications'),
    _NavItem('/member/profile', FontAwesomeIcons.circleUser, 'My Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();

    return Drawer(
      width: 270,
      backgroundColor: AppColors.sidebarBg,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(10)),
              child: const Center(child: FaIcon(FontAwesomeIcons.buildingUser, color: Colors.white, size: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('ApartmentApp', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                Text(auth.user?.name ?? 'Member', style: const TextStyle(color: AppColors.sidebarText, fontSize: 12), overflow: TextOverflow.ellipsis),
              ]),
            ),
          ]),
        ),
        const Divider(color: Color(0xFF2D4270), thickness: 1, height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: items.map((item) => _NavTile(
              item: item,
              isActive: item.route == '/member' ? location == '/member' : location.startsWith(item.route),
              onTap: () {
                FeedbackUtil.light();
                Navigator.pop(context); // Clears the slide drawer container out of the viewport
                context.go(item.route);  // Routes cleanly using the newly declared path mapping matching GoRouter specifications
              },
            )).toList(),
          ),
        ),
        const Divider(color: Color(0xFF2D4270), thickness: 1, height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: _NavTile(
            item: const _NavItem('', FontAwesomeIcons.rightFromBracket, 'Sign Out'),
            isActive: false,
            onTap: () async {
              FeedbackUtil.medium();
              Navigator.pop(context);
              await auth.signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ),
      ]),
    );
  }
}

class _NavItem {
  final String route, label;
  final dynamic icon;
  const _NavItem(this.route, this.icon, this.label);
}

class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;
  const _NavTile({required this.item, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: isActive ? AppColors.accent.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap, borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(children: [
              item.icon is IconData
                  ? Icon(item.icon, size: 15, color: isActive ? AppColors.accent : AppColors.sidebarIcon)
                  : FaIcon(item.icon, size: 15, color: isActive ? AppColors.accent : AppColors.sidebarIcon),
              const SizedBox(width: 12),
              Text(item.label, style: TextStyle(fontSize: 14, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400, color: isActive ? AppColors.accent : AppColors.sidebarText)),
            ]),
          ),
        ),
      ),
    );
  }
}