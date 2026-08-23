import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/obsidian_export.dart';

Future<void> exportBookToObsidianFlow(
  BuildContext context,
  Book book,
  List<Annotation> annotations,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final vaultDir = await FilePicker.getDirectoryPath(dialogTitle: 'Elige la carpeta de tu vault de Obsidian');
  if (vaultDir == null) return;
  try {
    final result = await exportBookToVault(
      book: book,
      annotations: annotations,
      vaultDir: vaultDir,
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Exportado a Obsidian · ${result.exportedAnnotations} anotaciones, '
          '${result.exportedImages} imágenes',
        ),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('No se pudo exportar a esa carpeta')),
    );
  }
}
