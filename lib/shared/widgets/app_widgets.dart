// lib/shared/widgets/app_widgets.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme.dart';
import '../services/connectivity_service.dart';

// ── 1. GLOBAL APP BARS ───────────────────────────────────────────────────────

/// 👥 Used by MemberDashboard and Visitors Screen
PreferredSizeWidget buildMemberAppBar(BuildContext context, String title) {
  return AppBar(
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
    centerTitle: false,
    backgroundColor: Colors.white,
    foregroundColor: AppColors.primary,
    elevation: 0,
    actions: [
      IconButton(
        icon: const FaIcon(FontAwesomeIcons.bell, size: 18),
        onPressed: () => context.push('/member/notifications'),
      ),
      IconButton(
        icon: const Icon(Icons.person_pin, size: 26),
        onPressed: () => context.push('/member/profile'),
      ),
      const SizedBox(width: 8),
    ],
  );
}

/// 🏢 Used by AdminDashboard and Admin Screens
/// ✅ FIXED: Cleaned layout structure completely eliminates hardcoded string spacing leaks
PreferredSizeWidget buildAdminAppBar(BuildContext context, String title) {
  return AppBar(
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
    centerTitle: false,
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    elevation: 0,
    actions: [
      IconButton(
        icon: const Icon(Icons.admin_panel_settings_outlined),
        onPressed: () => context.push('/admin/profile'),
      ),
      const SizedBox(width: 8),
    ],
  );
}

// ── 2. STATUS HELPERS (REQUIRED FOR STATUS BADGE) ─────────────────────────────

Color statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'open':
    case 'expected':
    case 'pending':
      return AppColors.warning;
    case 'resolved':
    case 'inside':
    case 'arrived':
    case 'active':
      return AppColors.success;
    case 'rejected':
    case 'closed':
    case 'danger':
      return AppColors.danger;
    default:
      return AppColors.textSecondary;
  }
}

Color statusBg(String status) {
  return statusColor(status).withOpacity(0.1);
}

// ── 3. CORE PRESENTATION WIDGETS ─────────────────────────────────────────────

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final dynamic icon;
  final Color color;
  final VoidCallback? onTap;

  const StatCard({super.key, required this.title, required this.value, required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: icon is IconData
                  ? Icon(icon, color: color, size: 18)
                  : FaIcon(icon, color: color, size: 18),
            ),
            const FaIcon(FontAwesomeIcons.arrowUpRightFromSquare, size: 12, color: AppColors.textHint),
          ]),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ]),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: statusBg(status),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor(status).withOpacity(0.3)),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor(status), letterSpacing: 0.5),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      if (actionLabel != null)
        TextButton(
          onPressed: onAction,
          child: Text(actionLabel!, style: const TextStyle(color: AppColors.accent, fontSize: 13)),
        ),
    ]);
  }
}

class LoadingList extends StatelessWidget {
  final int count;
  const LoadingList({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: Column(
        children: List.generate(count, (i) => Container(
          height: 72,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
        )),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String title;
  final String? subtitle;
  final dynamic icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.actionLabel,
    this.onAction
  });

  @override
  Widget build(BuildContext context) {
    final activeIcon = icon ?? Icons.inbox;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          activeIcon is IconData
              ? Icon(activeIcon, size: 64, color: Colors.grey)
              : FaIcon(activeIcon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ]),
      ),
    );
  }
}

class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});
  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> with SingleTickerProviderStateMixin {
  bool _isOnline = true;
  StreamSubscription<bool>? _sub;
  late AnimationController _ctrl;
  late Animation<double> _heightAnim;

  @override
  void initState() {
    super.initState();
    _isOnline = ConnectivityService.isOnline;
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _heightAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    if (!_isOnline) _ctrl.value = 1.0;
    _sub = ConnectivityService.stream.listen((online) {
      setState(() => _isOnline = online);
      online ? _ctrl.reverse() : _ctrl.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _heightAnim,
      child: Container(
        width: double.infinity,
        color: AppColors.danger.withOpacity(0.9),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: const Row(children: [
          Icon(Icons.wifi_off, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Expanded(child: Text('No internet — showing cached data', style: TextStyle(color: Colors.white, fontSize: 13))),
        ]),
      ),
    );
  }

  @override
  void dispose() { _sub?.cancel(); _ctrl.dispose(); super.dispose(); }
}

class AppTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool enabled;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final int maxLines;
  final Iterable<String>? autofillHints;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.focusNode,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
    this.suffix,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
    this.autofillHints,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        obscureText: obscureText,
        enabled: enabled,
        maxLines: obscureText ? 1 : maxLines,
        enableSuggestions: false,
        autocorrect: false,
        enableIMEPersonalizedLearning: false,
        enableInteractiveSelection: false,
        onChanged: onChanged,
        validator: validator,
        autofillHints: autofillHints,
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          suffix: suffix,
          filled: true,
          fillColor: enabled ? AppColors.surfaceVariant : AppColors.border.withOpacity(0.3),
        ),
      ),
    ]);
  }
}