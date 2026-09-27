import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

Future<String?> showRenameDialog(
  BuildContext context, {
  required String title,
  required String currentName,
  String hint = 'Nieuwe naam',
  int maxLength = 24,
}) {
  final controller = TextEditingController(text: currentName);
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: AppColors.charcoalElevated,
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: maxLength,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: AppColors.charcoal,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            counterStyle: const TextStyle(color: AppColors.muted),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuleren', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Opslaan', style: TextStyle(color: AppColors.amber, fontWeight: FontWeight.w700)),
          ),
        ],
      );
    },
  );
}
