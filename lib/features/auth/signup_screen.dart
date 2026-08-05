// lib/features/auth/signup_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/services/auth_provider.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/utils/feedback_util.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _buildingId = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _auth = AuthService();

  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _buildingIdFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  String? _selectedFlat;
  List<String> _vacantFlats = [];
  bool _loading = false;
  bool _fetchingFlats = false;

  String? _selectedWingId;
  String? _selectedWingName;
  List<Map<String, String>> _availableWings = [];
  bool _fetchingWings = false;

  /// Queries Firestore to retrieve the wings belonging to the Society Code
  Future<void> _loadWings(String buildingCode) async {
    final cleanCode = buildingCode.trim();
    if (cleanCode.isEmpty) return;

    setState(() {
      _fetchingWings = true;
      _availableWings = [];
      _selectedWingId = null;
      _selectedWingName = null;
      _vacantFlats = [];
      _selectedFlat = null;
    });

    try {
      // Step 1: Verify Society Code exists and get adminUid
      final societySnap = await FirebaseFirestore.instance.collection('buildings').doc(cleanCode).get();
      if (!societySnap.exists) {
        throw Exception('Building Code "$cleanCode" could not be resolved.');
      }
      
      final String adminUid = societySnap.data()?['adminUid'] ?? '';
      
      // Step 2: Fetch all wings belonging to this admin
      final wingsSnap = await FirebaseFirestore.instance
          .collection('buildings')
          .where('adminUid', isEqualTo: adminUid)
          .get();

      setState(() {
        _availableWings = wingsSnap.docs.map((d) => {
          'id': d.id,
          'name': d.data()['name'].toString(),
        }).toList();
      });
    } catch (e) {
      print('Error querying available wings: $e');
      if (mounted) _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _fetchingWings = false);
    }
  }

  /// Queries Firestore in real-time to retrieve unassigned flats for the chosen wing
  Future<void> _loadFlatsForWing(String wingId) async {
    final cleanCode = _buildingId.text.trim();
    if (cleanCode.isEmpty) return;

    setState(() {
      _fetchingFlats = true;
      _vacantFlats = [];
      _selectedFlat = null;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('flats')
          .where('buildingId', isEqualTo: cleanCode)
          .where('wingId', isEqualTo: wingId)
          .where('status', isEqualTo: 'vacant')
          .get();

      final List<String> extractedFlats = snapshot.docs
          .map((doc) => doc.data()['flatNo'].toString())
          .toList();

      extractedFlats.sort();

      setState(() {
        _vacantFlats = extractedFlats;
      });
    } catch (e) {
      print('Error querying available asset records: $e');
    } finally {
      if (mounted) setState(() => _fetchingFlats = false);
    }
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) {
      FeedbackUtil.error();
      return;
    }
    if (_selectedWingId == null) {
      FeedbackUtil.error();
      _showError('Please select a Building/Wing.');
      return;
    }
    if (_selectedFlat == null) {
      FeedbackUtil.error();
      _showError('Please pick an available flat from the inventory list.');
      return;
    }
    if (_password.text != _confirm.text) {
      FeedbackUtil.error();
      _showError('Passwords do not match');
      return;
    }

    FeedbackUtil.medium();
    setState(() => _loading = true);

    final cleanBuildingId = _buildingId.text.trim();

    try {
      final buildingSnap = await FirebaseFirestore.instance
          .collection('buildings')
          .doc(cleanBuildingId)
          .get();

      if (!buildingSnap.exists) {
        throw Exception('Building Code "$cleanBuildingId" could not be resolved in the system registry.');
      }

      // 1️⃣ Run account authentication and basic user profiling creation
      final String fullFlatName = '$_selectedFlat ($_selectedWingName)';
      final appUser = await _auth.signup(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        phone: _phone.text.trim(),
        buildingId: cleanBuildingId,
        flatNo: fullFlatName,
      );

      if (!mounted) return;

      // 2️⃣ Hydrate the local auth state context provider
      context.read<AuthProvider>().setUser(appUser);

      // 3️⃣ Sequentially claim the vacant flat now that user propagation is fully authenticated
      await _auth.claimFlatAsset(
        buildingId: cleanBuildingId,
        wingName: _selectedWingName!,
        flatNo: _selectedFlat!,
        uid: appUser.uid,
        name: appUser.name,
      );

      FeedbackUtil.medium();
      context.go('/member');
    } catch (e) {
      FeedbackUtil.error();
      if (e.toString().contains('permission-denied')) {
        _showError('Registration rules conflict. Please contact your building Administrator.');
      } else {
        _showError(e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.danger,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const FaIcon(FontAwesomeIcons.buildingUser, size: 50, color: AppColors.primary),
                const SizedBox(height: 20),
                Text('Join Building', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 32),

                AppTextField(
                  label: 'Society Code',
                  hint: 'Enter or scan Admin\'s QR code',
                  controller: _buildingId,
                  onChanged: (val) => _loadWings(val),
                  validator: (v) => v!.isEmpty ? 'Society Code is required' : null,
                  suffix: IconButton(
                    icon: const Icon(Icons.qr_code_scanner, color: AppColors.primary),
                    onPressed: () async {
                      FeedbackUtil.light();

                      final String? scannedCode = await showModalBottomSheet<String>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.black,
                        builder: (context) => SizedBox(
                          height: MediaQuery.of(context).size.height * 0.7,
                          child: Stack(
                            children: [
                              MobileScanner(
                                onDetect: (capture) {
                                  final List<Barcode> barcodes = capture.barcodes;
                                  if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                                    FeedbackUtil.medium();
                                    Navigator.pop(context, barcodes.first.rawValue);
                                  }
                                },
                              ),
                              Positioned(
                                top: 40,
                                right: 20,
                                child: CircleAvatar(
                                  backgroundColor: Colors.white24,
                                  child: IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                ),
                              ),
                              const Center(
                                child: Icon(Icons.crop_free, size: 280, color: Colors.white54),
                              ),
                            ],
                          ),
                        ),
                      );

                      if (scannedCode != null && mounted) {
                        setState(() {
                          _buildingId.text = scannedCode;
                        });
                        _loadWings(scannedCode);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Building Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedWingId,
                      hint: Text(_fetchingWings
                          ? 'Fetching buildings...'
                          : _buildingId.text.isEmpty
                          ? 'Enter Society Code first'
                          : _availableWings.isEmpty
                          ? 'No buildings found'
                          : 'Choose Building Name'),
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: AppColors.surfaceVariant,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                      dropdownColor: AppColors.surface,
                      items: _availableWings.map((wing) {
                        return DropdownMenuItem<String>(
                          value: wing['id'],
                          child: Text(wing['name']!, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                        );
                      }).toList(),
                      onChanged: (_fetchingWings || _availableWings.isEmpty) ? null : (val) {
                        setState(() {
                          _selectedWingId = val;
                          _selectedWingName = _availableWings.firstWhere((w) => w['id'] == val)['name'];
                        });
                        if (val != null) _loadFlatsForWing(val);
                      },
                      validator: (v) => v == null ? 'Please select your building' : null,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Available Flats', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedFlat,
                      hint: Text(_fetchingFlats
                          ? 'Fetching properties...'
                          : _selectedWingId == null
                          ? 'Select Building first'
                          : _vacantFlats.isEmpty
                          ? 'No vacant units found'
                          : 'Choose Flat'),
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: AppColors.surfaceVariant,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                      dropdownColor: AppColors.surface,
                      items: _vacantFlats.map((flat) {
                        return DropdownMenuItem<String>(
                          value: flat,
                          child: Text(flat, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                        );
                      }).toList(),
                      onChanged: (_fetchingFlats || _vacantFlats.isEmpty) ? null : (val) {
                        setState(() => _selectedFlat = val);
                      },
                      validator: (v) => v == null ? 'Please select your flat assignment' : null,
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const SizedBox(height: 16),
                AppTextField(label: 'Full Name', controller: _name, focusNode: _nameFocus, validator: (v) => v!.isEmpty ? 'Required' : null),
                const SizedBox(height: 16),
                AppTextField(label: 'Email', controller: _email, focusNode: _emailFocus, keyboardType: TextInputType.text, validator: (v) => (v == null || !v.contains('@')) ? 'Invalid email' : null),
                const SizedBox(height: 16),
                AppTextField(label: 'Phone', controller: _phone, focusNode: _phoneFocus, keyboardType: TextInputType.phone, validator: (v) => v!.isEmpty ? 'Required' : null),
                const SizedBox(height: 16),
                AppTextField(label: 'Password', controller: _password, focusNode: _passwordFocus, obscureText: true, validator: (v) => (v?.length ?? 0) < 6 ? 'Min 6 characters' : null),
                const SizedBox(height: 16),
                AppTextField(label: 'Confirm Password', controller: _confirm, focusNode: _confirmFocus, obscureText: true, validator: (v) => v!.isEmpty ? 'Required' : null),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _signup,
                    child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Register and Claim Unit'),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    FeedbackUtil.light();
                    context.go('/login');
                  },
                  child: const Text('Already have an account? Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _buildingId.dispose();
    _password.dispose();
    _confirm.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _buildingIdFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }
}