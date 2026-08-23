import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme.dart';

Future<String?> showNoteDialog(
  BuildContext context, {
  String initial = '',
  String title = 'Nota de la anotación',
  Uint8List? previewPng,
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (previewPng != null)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: InkTheme.outline),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.memory(previewPng, fit: BoxFit.contain),
            ),
          TextField(
            controller: controller,
            autofocus: true,
            maxLines: 4,
            minLines: 1,
            style: const TextStyle(color: InkTheme.ink, fontSize: 15),
            decoration: const InputDecoration(
              hintText: 'Escribe tu nota (opcional)…',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: InkTheme.accent),
          onPressed: () =>
              Navigator.of(dialogContext).pop(controller.text.trim()),
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}
