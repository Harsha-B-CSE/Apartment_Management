// lib/features/admin/presentation/screens/admin_creator.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../firebase_options.dart';
import '../shared/services/auth_service.dart';
import '../core/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AdminCreatorApp());
}

class AdminCreatorApp extends StatelessWidget {
  const AdminCreatorApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const OnboardingHome(),
    );
  }
}

// ─── LANDING SELECTION SCREEN ───
class OnboardingHome extends StatelessWidget {
  const OnboardingHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("SaaS Management Console")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MenuButton(
                title: "CREATE NEW CLIENT",
                subtitle: "Onboard a new building and admin",
                icon: Icons.add_business,
                color: Colors.blue,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCreatorScreen())),
              ),
              const SizedBox(height: 20),
              _MenuButton(
                title: "DELETE CLIENT",
                subtitle: "Remove building and all users (Danger Zone)",
                icon: Icons.delete_forever,
                color: Colors.red,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDeleteScreen())),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── SCREEN 1: CREATE ADMIN ───
class AdminCreatorScreen extends StatefulWidget {
  const AdminCreatorScreen({super.key});
  @override
  State<AdminCreatorScreen> createState() => _AdminCreatorScreenState();
}

class _AdminCreatorScreenState extends State<AdminCreatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _buildingName = TextEditingController();
  final _adminName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _logoBase64;

  Future<void> _pickLogo() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 300, maxHeight: 300, imageQuality: 85);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _logoBase64 = base64Encode(bytes);
        });
      }
    } catch (e) {
      _showError("Failed to pick image: $e");
    }
  }

  Future<void> _createAdmin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final String bName = _buildingName.text.trim();
    final String aName = _adminName.text.trim();

    try {
      final auth = AuthService();
      final String buildingId = await auth.createClientAdmin(
        name: aName,
        email: _email.text.trim(),
        password: _password.text.trim(),
        buildingName: bName,
        logoBase64: _logoBase64,
      );

      // ⚡ SUCCESS LOG: Track system instantiation properties
      await FirebaseFirestore.instance.collection('audit_logs').add({
        'timestamp': FieldValue.serverTimestamp(),
        'buildingId': buildingId,
        'userUid': 'SAAS_ROOT_CONSOLE',
        'userName': 'Root Platform Console',
        'action': 'BUILDING_CREATION',
        'result': 'success',
        'details': "Onboarded new client building listing '$bName' (Assigned Admin: $aName).",
      });

      if (!mounted) return;
      _showSuccess(buildingId);
    } catch (e) {
      // ⚡ FAILURE LOG: Capture server constraints violations locally
      await FirebaseFirestore.instance.collection('audit_logs').add({
        'timestamp': FieldValue.serverTimestamp(),
        'buildingId': 'GLOBAL_SYSTEM',
        'userUid': 'SAAS_ROOT_CONSOLE',
        'userName': 'Root Platform Console',
        'action': 'BUILDING_CREATION',
        'result': 'failure',
        'details': "Failed client onboarding execution flow for target naming parameter '$bName'. Error: $e",
      });

      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSuccess(String id) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("✅ Client Created"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Building and Admin are ready. Copy the ID below to share with tenants:"),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
              child: Text(id, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: id));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ID Copied to clipboard")));
            },
            child: const Text("COPY ID"),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("DONE")),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Client")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(controller: _buildingName, decoration: const InputDecoration(labelText: "Building Name")),
              const SizedBox(height: 16),
              TextFormField(controller: _adminName, decoration: const InputDecoration(labelText: "Admin Full Name")),
              const SizedBox(height: 16),
              TextFormField(controller: _email, decoration: const InputDecoration(labelText: "Admin Email")),
              const SizedBox(height: 16),
              TextFormField(controller: _password, decoration: const InputDecoration(labelText: "Initial Password"), obscureText: true),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickLogo,
                      icon: const Icon(Icons.image),
                      label: Text(_logoBase64 == null ? "Select Building Logo (Optional)" : "Logo Selected"),
                    ),
                  ),
                  if (_logoBase64 != null) ...[
                    const SizedBox(width: 16),
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: MemoryImage(base64Decode(_logoBase64!)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => setState(() => _logoBase64 = null),
                    ),
                  ]
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _createAdmin,
                  child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text("ONBOARD CLIENT"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── SCREEN 2: DELETE ADMIN ───
class AdminDeleteScreen extends StatefulWidget {
  const AdminDeleteScreen({super.key});
  @override
  State<AdminDeleteScreen> createState() => _AdminDeleteScreenState();
}

class _AdminDeleteScreenState extends State<AdminDeleteScreen> {
  final _idController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  void _confirmDeletion() {
    if (_idController.text.isEmpty || _emailController.text.isEmpty || _passwordController.text.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("⚠️ Delete Building?"),
        content: const Text("This will delete the building record and the Admin's access. Continue?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _secondConfirmation();
              },
              child: const Text("NEXT", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }

  void _secondConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.red[50],
        title: const Text("🚨 FINAL WARNING"),
        content: const Text("This action is IRREVERSIBLE. All tenants, flats, and data linked to this building will be wiped from Firestore. Authentication accounts must be manually removed from Firebase Console."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ABORT")),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(ctx);
                _executeDelete();
              },
              child: const Text("I UNDERSTAND, DELETE EVERYTHING", style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );
  }

  Future<void> _executeDelete() async {
    final String targetId = _idController.text.trim();
    setState(() => _loading = true);

    try {
      // Authenticate as the Admin of the building first
      await AuthService().login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      await AuthService().deleteBuildingComplete(targetId);

      // ⚡ SUCCESS LOG: Manual system audit compilation tracking
      await FirebaseFirestore.instance.collection('audit_logs').add({
        'timestamp': FieldValue.serverTimestamp(),
        'buildingId': targetId,
        'userUid': 'SAAS_ROOT_CONSOLE',
        'userName': 'Root Platform Console',
        'action': 'BUILDING_DELETION',
        'result': 'success',
        'details': "Permanently purged building ID '$targetId' and all multi-tenant entity arrays from the database.",
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Building Wiped Successfully")));
      Navigator.pop(context);
    } catch (e) {
  // ⚡ FAILURE LOG: Record configuration script exceptions
  await FirebaseFirestore.instance.collection('audit_logs').add({
  'timestamp': FieldValue.serverTimestamp(),
  'buildingId': targetId.isNotEmpty ? targetId : 'GLOBAL_SYSTEM',
  'userUid': 'SAAS_ROOT_CONSOLE',
  'userName': 'Root Platform Console',
  'action': 'BUILDING_DELETION',
  'result': 'failure',
  'details': "Failed cleanup routine script tracking execution errors on ID '$targetId'. Error: $e",
  });

  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
  } finally { // ✅ FIXED: Changed 'finalBuilding' back to standard 'finally' keyword statement
  if (mounted) setState(() => _loading = false);
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Offboard Client")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 60),
            const SizedBox(height: 16),
            const Text("Enter the Building ID to delete all associated data.", textAlign: TextAlign.center),
            const SizedBox(height: 24),
            TextField(
              controller: _idController,
              decoration: const InputDecoration(labelText: "Target Building ID", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Admin Email", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "Admin Password", border: OutlineInputBorder()),
              obscureText: true,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: _loading ? null : _confirmDeletion,
                child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text("DELETE CLIENT"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── SHARED UI COMPONENT: MENU BUTTON ───
class _MenuButton extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MenuButton({required this.title, required this.subtitle, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(15),
          color: color.withOpacity(0.05),
        ),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: color, child: Icon(icon, color: Colors.white)),
            const SizedBox(width: 20),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ]),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}