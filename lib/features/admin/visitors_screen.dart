// lib/features/admin/presentation/screens/admin_visitors_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminVisitorsScreen extends StatefulWidget {
  const AdminVisitorsScreen({super.key});

  @override
  State<AdminVisitorsScreen> createState() => _AdminVisitorsScreenState();
}

class _AdminVisitorsScreenState extends State<AdminVisitorsScreen> {
  StreamSubscription<QuerySnapshot>? _streamSubscription;
  List<DocumentSnapshot> _visitorDocs = [];
  bool _isLoading = true;
  String? _networkError;
  int _renderId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectToRawDatabase();
    });
  }

  void _connectToRawDatabase() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _networkError = null;
    });

    _streamSubscription?.cancel();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final buildingId = userDoc.data()?['buildingId'];
      
      if (buildingId == null) throw Exception("No building associated");

      _streamSubscription = FirebaseFirestore.instance
          .collection('visitors')
          .where('buildingId', isEqualTo: buildingId)
          .snapshots()
          .listen(
          (snapshot) {
        if (mounted) {
          setState(() {
            _visitorDocs = snapshot.docs;
            _isLoading = false;
            _networkError = null;
            _renderId++;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _networkError = error.toString();
            _isLoading = false;
          });
        }
      },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _networkError = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Clean off-white background
      appBar: AppBar(
        title: const Text('Manage Visitors', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF673AB7), // Deep purple production branding
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _connectToRawDatabase,
          )
        ],
      ),
      body: Builder(
        builder: (innerContext) {
          if (currentUser == null) {
            return const Center(child: Text("Please login first.", style: TextStyle(color: Colors.red)));
          }

          if (_networkError != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text("Connection Error:\n$_networkError", textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            );
          }

          if (_isLoading) {
            return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFF673AB7))));
          }

          return Column(
            children: [
              // 🏢 Active Scope Sub-Header Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: const Color(0xFF673AB7).withOpacity(0.06),
                child: Row(
                  children: [
                    const Icon(Icons.apartment, size: 16, color: Color(0xFF673AB7)),
                    const SizedBox(width: 8),
                    const Text("Active Live Context Rows:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
                    const SizedBox(width: 6),
                    Text(
                      "${_visitorDocs.length} Total Logs",
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _visitorDocs.isEmpty
                    ? const Center(
                        child: Text("No visitor records found for this building.", style: TextStyle(color: Colors.grey, height: 1.4)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _visitorDocs.length,
                        itemBuilder: (context, index) {
                          final doc = _visitorDocs[index];
                          try {
                            final d = doc.data() as Map<String, dynamic>? ?? {};

                            final String visitorName = d['visitorName']?.toString() ?? d['name']?.toString() ?? 'Guest';
                            final String currentStatus = (d['status'] ?? 'expected').toString().toLowerCase();
                            final bool isExpected = currentStatus == 'expected';

                            final String flatNo = (d['flatNo'] ?? 'N/A').toString();
                            final String residentName = d['memberName']?.toString() ?? d['residentName']?.toString() ?? 'Resident';
                            final String memberNote = d['notes']?.toString() ?? d['purpose']?.toString() ?? d['comments']?.toString() ?? '';

                            return Card(
                              key: ValueKey('prod_card_${doc.id}'),
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey.shade200, width: 1),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const CircleAvatar(
                                        backgroundColor: Color(0xFF673AB7),
                                        child: Icon(Icons.person, color: Colors.white),
                                      ),
                                      title: Text(visitorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Text("Visiting: $residentName (Flat $flatNo)", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                      ),
                                      trailing: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isExpected ? Colors.orange.shade50 : (currentStatus == 'entered' ? Colors.green.shade50 : Colors.red.shade50),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          currentStatus.toUpperCase(),
                                          style: TextStyle(
                                              color: isExpected ? Colors.orange.shade800 : (currentStatus == 'entered' ? Colors.green.shade800 : Colors.red.shade800),
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (memberNote.trim().isNotEmpty) ...[
                                      const Divider(height: 24),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.comment, size: 14, color: Colors.grey),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              "Note: $memberNote",
                                              style: const TextStyle(fontSize: 12, color: Colors.black87, fontStyle: FontStyle.italic),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    if (isExpected) ...[
                                      const Divider(height: 24),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: () => _processAction(context, doc.id, 'rejected'),
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(color: Colors.red),
                                              foregroundColor: Colors.red,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            ),
                                            icon: const Icon(Icons.close, size: 14),
                                            label: const Text("REJECT", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton.icon(
                                            onPressed: () => _processAction(context, doc.id, 'entered'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                              elevation: 0,
                                            ),
                                            icon: const Icon(Icons.check, size: 14),
                                            label: const Text("ACCEPT", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          } catch (e) {
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text("Error loading visitor row: $e", style: const TextStyle(color: Colors.red)),
                              ),
                            );
                          }
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _processAction(BuildContext context, String docId, String targetStatus) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Updating server..."), duration: Duration(milliseconds: 500)),
      );

      await FirebaseFirestore.instance.collection('visitors').doc(docId).update({
        'status': targetStatus,
        'actualEntryTime': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Successfully updated to $targetStatus!"), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed: $e"), backgroundColor: Colors.red),
      );
    }
  }
}