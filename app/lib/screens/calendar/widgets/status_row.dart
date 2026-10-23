import 'package:flutter/material.dart';
import '../../../core/theme.dart';

class StatusRow extends StatelessWidget {
  final bool ok;
  final String label;

  const StatusRow({super.key, required this.ok, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.cancel,
          size: 18,
          color: ok ? AppTheme.mint : AppTheme.errorColor,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
      ],
    );
  }
}
