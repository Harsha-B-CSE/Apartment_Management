import 'package:flutter/material.dart';

class AppDropdown<T> extends StatelessWidget {
  final String? labelText;   // ✅ for "Status", "Category"
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;

  const AppDropdown({
    super.key,
    this.labelText,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelText != null) ...[
          Text(labelText!,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
        ],
        DropdownButtonFormField<T>(
          value: value,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool> showConfirmDialog(
    BuildContext context, {
      required String title,
      required String message,
      bool isDanger = false,
      String confirmLabel = "Confirm",
    }) async {
  final result = await showDialog<bool>(
    context: context,
    // ✅ FIXED: Changed the builder context parameter token from '_' to 'dialogContext'
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          // ✅ FIXED: Safely pops the 'dialogContext' layout overlay, not the parent view!
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          style: isDanger
              ? ElevatedButton.styleFrom(backgroundColor: Colors.red)
              : null,
          // ✅ FIXED: Safely pops the 'dialogContext' layout overlay, returning 'true'
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );

  return result ?? false;
}