// lib/features/admin/presentation/widgets/visitor_list_tile.dart

import 'package:flutter/material.dart';
import '../../../shared/models/visitor.dart';

class VisitorListTile extends StatelessWidget {
  final Visitor visitor;

  const VisitorListTile({
    super.key,
    required this.visitor,
  });

  @override
  Widget build(BuildContext context) {
    // Fallback logic for date label handling if your model uses a DateTime object
    final String dateString =
        "${visitor.entryTime!.hour}:${visitor.entryTime!.minute.toString().padLeft(2, '0')}";

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(visitor.status),
          child: const Icon(Icons.person_outline, color: Colors.white),
        ),
        title: Text(
          visitor.visitorName, // ✅ FIXED: Mapped to core schema 'visitorName'
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text("${visitor.phone} • ${visitor.purpose}"),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              dateString, // ✅ FIXED: Replaced unresolvable 'dateLabel' getter
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Container(
              // ✅ FIXED: Changed invalid 'py' key to 'vertical'
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(visitor.status).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                visitor.status.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _getStatusColor(visitor.status),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'entered': // Aligned with your system constants
      case 'checked_in':
        return Colors.green;
      case 'expected':
      case 'pending':
        return Colors.orange;
      case 'rejected':
      case 'expired':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }
}
