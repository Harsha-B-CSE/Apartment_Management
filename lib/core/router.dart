// lib/core/router.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../shared/services/auth_provider.dart';

// 🔐 AUTH SCREENS
import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';

// 🏢 ADMIN SCREENS
import '../features/admin/admin_shell.dart';
import '../features/admin/admin_dashboard_screen.dart';
import '../features/admin/members_screen.dart';
import '../features/admin/admin_notifications_screen.dart';
import '../features/admin/visitors_screen.dart';
import '../features/admin/complaints_screen.dart';
import '../features/admin/parking_screen.dart';
import '../features/admin/flats_screen.dart';
import '../features/admin/services_screen.dart';
import '../features/admin/buildings_screen.dart';
import '../features/admin/service_requests_screen.dart';
import '../features/admin/admin_payments_screen.dart'; // ✅ NEW

// 📊 ADVANCED ADMIN MODULES
import '../features/admin/admin_analytics_screen.dart';
import '../features/admin/admin_performance_screen.dart';
import '../features/admin/audit_log_screen.dart';

// 👥 MEMBER (TENANT) SCREENS
import '../features/member/member_shell.dart';
import '../features/member/member_dashboard_screen.dart';
import '../features/member/member_visitors_screen.dart';
import '../features/member/member_complaints_screen.dart';
import '../features/member/member_notifications_screen.dart';
import '../features/member/member_parking_screen.dart';
import '../features/member/member_service_requests_screen.dart';
import '../features/member/member_feedback_screen.dart';
import '../features/member/member_payments_screen.dart'; // ✅ NEW

// ⚙️ GUARD SCREENS
import '../features/guard/guard_shell.dart';
import '../features/guard/guard_dashboard_screen.dart';

// ⚙️ SHARED SCREENS
import '../features/profile/profile_screen.dart';
import '../features/profile/change_password_screen.dart';

GoRouter createRouter(AuthProvider auth) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: auth,
    redirect: (context, state) {
      final bool loggedIn = auth.isAuthenticated;
      final bool isAuthPath = state.matchedLocation == '/login' || state.matchedLocation == '/signup';

      if (auth.status == AuthStatus.loading || (loggedIn && auth.user == null)) return null;

      if (!loggedIn) return isAuthPath ? null : '/login';

      if (isAuthPath) {
        if (auth.isAdmin) return '/admin';
        if (auth.isGuard) return '/guard';
        return '/member';
      }

      if (state.matchedLocation.startsWith('/admin') && !auth.isAdmin) return auth.isGuard ? '/guard' : '/member';
      if (state.matchedLocation.startsWith('/guard') && !auth.isGuard) return auth.isAdmin ? '/admin' : '/member';
      if (state.matchedLocation.startsWith('/member') && (auth.isAdmin || auth.isGuard)) return auth.isAdmin ? '/admin' : '/guard';

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (c, s) => const SignupScreen()),

      // ADMIN SECTION
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(path: '/admin', builder: (c, s) => const AdminDashboardScreen()),
          GoRoute(path: '/admin/members', builder: (c, s) => const MembersScreen()),
          GoRoute(
            path: '/admin/visitors', // ◄ Make sure this matches exactly!
            builder: (context, state) => AdminVisitorsScreen(), // ◄ No const keyword here
          ),
          GoRoute(path: '/admin/complaints', builder: (c, s) => const AdminComplaintsScreen()),
          GoRoute(path: '/admin/payments', builder: (c, s) => const AdminPaymentsScreen()), // ✅ NEW
          GoRoute(path: '/admin/parking', builder: (c, s) => const AdminParkingScreen()),
          GoRoute(path: '/admin/notifications', builder: (c, s) => const AdminNotificationsScreen()),
          GoRoute(path: '/admin/flats', builder: (c, s) => const FlatsScreen()),
          GoRoute(path: '/admin/services', builder: (c, s) => const AdminServicesScreen()),
          GoRoute(path: '/admin/buildings', builder: (c, s) => const BuildingsScreen()),
          GoRoute(path: '/admin/service-requests', builder: (c, s) => const AdminServiceRequestsScreen()),
          GoRoute(path: '/admin/profile', builder: (c, s) => const ProfileScreen()),
          GoRoute(path: '/admin/change-password', builder: (c, s) => const ChangePasswordScreen()),

          // ✅ FIXED & CLEANED: Standardized builders with absolute 0 parameter conflicts
          GoRoute(path: '/admin/analytics', builder: (c, s) => const AdminAnalyticsScreen()),
          GoRoute(path: '/admin/performance', builder: (c, s) => const AdminPerformanceScreen()),
          GoRoute(path: '/admin/audit', builder: (c, s) => const AuditLogScreen()),
        ],
      ),

      // MEMBER SECTION
      ShellRoute(
        builder: (context, state, child) => MemberShell(child: child),
        routes: [
          GoRoute(
            path: '/member/feedback',
            builder: (context, state) => const MemberFeedbackScreen(), // ◄ Make sure this points to your new Stateful version!
          ),
          GoRoute(path: '/member', builder: (c, s) => const MemberDashboardScreen()),
          GoRoute(path: '/member/visitors', builder: (c, s) => const MemberVisitorsScreen()),
          GoRoute(path: '/member/complaints', builder: (c, s) => const MemberComplaintsScreen()),
          GoRoute(path: '/member/payments', builder: (c, s) => const MemberPaymentsScreen()), // ✅ NEW
          GoRoute(path: '/member/notifications', builder: (c, s) => const MemberNotificationsScreen()),
          GoRoute(path: '/member/parking', builder: (c, s) => const MemberParkingScreen()),
          GoRoute(path: '/member/service-requests', builder: (c, s) => const MemberServiceRequestsScreen()),
          GoRoute(path: '/member/profile', builder: (c, s) => const ProfileScreen()),
          GoRoute(path: '/member/change-password', builder: (c, s) => const ChangePasswordScreen()),
        ],
      ),

      // GUARD SECTION
      ShellRoute(
        builder: (context, state, child) => GuardShell(child: child),
        routes: [
          GoRoute(path: '/guard', builder: (c, s) => const GuardDashboardScreen()),
          GoRoute(path: '/guard/profile', builder: (c, s) => const ProfileScreen()),
          GoRoute(path: '/guard/change-password', builder: (c, s) => const ChangePasswordScreen()),
        ],
      ),
    ],
  );
}