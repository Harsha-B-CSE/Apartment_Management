import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/complaint.dart';
import '../services/auth_provider.dart';
import '../services/firestore_service.dart';
import '../../core/theme.dart';
import '../widgets/app_widgets.dart';

class ComplaintDetailsScreen extends StatefulWidget {
  final Complaint complaint;
  const ComplaintDetailsScreen({super.key, required this.complaint});

  @override
  State<ComplaintDetailsScreen> createState() => _ComplaintDetailsScreenState();
}

class _ComplaintDetailsScreenState extends State<ComplaintDetailsScreen> {
  final _commentCtrl = TextEditingController();
  bool _isSending = false;

  void _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    setState(() => _isSending = true);
    try {
      await FirebaseFirestore.instance
          .collection('complaints')
          .doc(widget.complaint.id)
          .collection('comments')
          .add({
        'text': text,
        'senderId': user.uid,
        'senderName': user.name,
        'senderRole': user.role,
        'createdAt': Timestamp.now(),
      });
      _commentCtrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isAdmin = user?.role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaint Details', style: TextStyle(fontSize: 16)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: DropdownButton<String>(
                value: widget.complaint.status,
                dropdownColor: AppColors.primary,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                underline: const SizedBox(),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                items: ['open', 'in_progress', 'resolved', 'closed'].map((s) {
                  return DropdownMenuItem(value: s, child: Text(s.toUpperCase()));
                }).toList(),
                onChanged: (newStatus) async {
                  if (newStatus == null) return;
                  try {
                    await FirebaseFirestore.instance.collection('complaints').doc(widget.complaint.id).update({'status': newStatus});
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status updated')));
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
                    }
                  }
                },
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Details Header
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(widget.complaint.title,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    if (!isAdmin) StatusBadge(widget.complaint.status),
                  ],
                ),
                const SizedBox(height: 8),
                Text('By: ${widget.complaint.raisedByName} (Flat ${widget.complaint.flatNo})',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const Divider(height: 24),
                const Text('Description', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(widget.complaint.description),
                if (widget.complaint.photoUrls.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Attachments', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.complaint.photoUrls.length,
                      separatorBuilder: (c, i) => const SizedBox(width: 8),
                      itemBuilder: (c, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: widget.complaint.photoUrls[i],
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          placeholder: (c, url) => Container(color: Colors.grey.shade200),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                const Text('Discussion Thread', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('complaints')
                      .doc(widget.complaint.id)
                      .collection('comments')
                      .orderBy('createdAt', descending: false)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) return const Text('No comments yet.', style: TextStyle(color: AppColors.textHint));
                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: docs.length,
                      separatorBuilder: (c, i) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final d = docs[i].data() as Map<String, dynamic>;
                        final isMe = d['senderId'] == user?.uid;
                        final isManager = d['senderRole'] == 'admin';
                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isMe ? AppColors.primary.withOpacity(0.1) : (isManager ? Colors.orange.shade50 : Colors.grey.shade100),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isMe ? AppColors.primary.withOpacity(0.2) : Colors.transparent),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isMe)
                                  Text(d['senderName'] ?? 'Unknown',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isManager ? Colors.orange.shade800 : AppColors.textSecondary)),
                                const SizedBox(height: 4),
                                Text(d['text'] ?? '', style: const TextStyle(fontSize: 14)),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          // Comment Input
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendComment(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: _isSending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : IconButton(
                          icon: const Icon(Icons.send, color: Colors.white, size: 20),
                          onPressed: _sendComment,
                        ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
