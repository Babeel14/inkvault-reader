import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/obsidian_export.dart';
import '../services/obsidian_link.dart';
import '../screens/settings_screen.dart';

Future<void> exportBookToObsidianFlow(BuildContext context, Book book, List<Annotation> annotations) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    var settings = await ObsidianLink.settings();
    if (settings['uri'] == null) {
      if (!context.mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
      settings = await ObsidianLink.settings();
      if (settings['uri'] == null) return;
    }
    final base = '${slugify(book.title)}-${book.id}';
    final files = <Map<String, Object>>[];
    for (final a in annotations) {
      if (a.imagePath != null) {
        final image = File(a.imagePath!);
        if (!await image.exists()) throw StateError('Falta la imagen de una anotación. No se ha exportado la nota.');
        files.add({'path': '$base/attachments/${attachmentNameFor(book, a)}', 'mime': 'image/png', 'bytes': await image.readAsBytes()});
      }
      final markdown = buildObsidianMarkdown(book: book, annotations: [a]);
      files.add({'path': '$base/nota-${a.id}.md', 'mime': 'text/markdown', 'bytes': utf8.encode(markdown)});
    }
    if (files.isEmpty) { messenger.showSnackBar(const SnackBar(content: Text('No hay anotaciones para exportar.'))); return; }
    await ObsidianLink.export(files);
    messenger.showSnackBar(SnackBar(content: Text('${annotations.length} notas enviadas a Obsidian'),
      action: SnackBarAction(label: 'Abrir', onPressed: () async {
        try { await ObsidianLink.open(); } catch (_) { messenger.showSnackBar(const SnackBar(content: Text('No se pudo abrir Obsidian. Comprueba que está instalado.'))); }
      })));
  } catch (e) { messenger.showSnackBar(SnackBar(content: Text('No se pudo exportar. Revisa la carpeta en Ajustes. $e'))); }
}
