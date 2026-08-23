import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../models/models.dart';
import 'id_gen.dart';

class ObsidianExportResult {
  ObsidianExportResult({
    required this.folderPath,
    required this.markdownPath,
    required this.exportedAnnotations,
    required this.exportedImages,
  });

  final String folderPath;
  final String markdownPath;
  final int exportedAnnotations;
  final int exportedImages;
}

const _accentMap = <String, String>{
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a',
  'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
  'ñ': 'n', 'ç': 'c',
};

String slugify(String input) {
  final lower = input.trim().toLowerCase();
  final buf = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    if (_accentMap.containsKey(ch)) {
      buf.write(_accentMap[ch]);
    } else if (RegExp(r'[a-z0-9]').hasMatch(ch)) {
      buf.write(ch);
    } else {
      buf.write('-');
    }
  }
  var slug = buf.toString();
  slug = slug.replaceAll(RegExp('-+'), '-');
  while (slug.startsWith('-')) {
    slug = slug.substring(1);
  }
  while (slug.endsWith('-')) {
    slug = slug.substring(0, slug.length - 1);
  }
  return slug.isEmpty ? 'libro' : slug.substring(0, slug.length.clamp(0, 60).toInt());
}

String attachmentNameFor(Book book, Annotation ann) {
  final path = ann.imagePath ?? '';
  final dot = path.lastIndexOf('.');
  final ext = dot >= 0 ? path.substring(dot).toLowerCase() : '.png';
  final base = slugify(book.title);
  final pagePart = ann.pageIndex >= 0 ? '_pag${ann.pageIndex + 1}' : '';
  final shortId = ann.id.length >= 6 ? ann.id.substring(0, 6) : ann.id;
  return '$base$pagePart\_$shortId$ext';
}

String _yamlString(String value) =>
    '"${value.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';

String buildObsidianMarkdown({
  required Book book,
  required List<Annotation> annotations,
}) {
  final now = DateTime.now();
  final buf = StringBuffer();
  buf.writeln('---');
  buf.writeln('titulo: ${_yamlString(book.title)}');
  buf.writeln('autor: ${_yamlString(book.author)}');
  buf.writeln('formato: ${bookFormatLabel(book.format)}');
  buf.writeln('fecha_exportacion: ${now.toIso8601String()}');
  buf.writeln('---');
  buf.writeln();
  buf.writeln('# ${book.title}');
  if (annotations.isEmpty) {
    buf.writeln();
    buf.writeln('_Sin anotaciones._');
    return buf.toString();
  }
  final sorted = List<Annotation>.from(annotations)
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  for (final ann in sorted) {
    buf.writeln();
    final kindLabel = ann.isCrop ? 'Recorte' : 'Dibujo';
    final where = ann.pageIndex >= 0 ? 'pág ${ann.pageIndex + 1}' : 'ePub';
    buf.writeln('> [!note] $kindLabel · $where');
    final noteLines =
        ann.note.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty);
    for (final line in noteLines) {
      buf.writeln('> $line');
    }
    if (ann.imagePath != null) {
      if (noteLines.isNotEmpty) buf.writeln('>');
      buf.writeln('> ![[attachments/${attachmentNameFor(book, ann)}]]');
    }
  }
  return buf.toString();
}

Future<ObsidianExportResult> exportBookToVault({
  required Book book,
  required List<Annotation> annotations,
  required String vaultDir,
}) async {
  final slug = slugify(book.title);
  final folder = Directory('$vaultDir/$slug');
  await folder.create(recursive: true);
  final attachments = Directory('${folder.path}/attachments');
  await attachments.create(recursive: true);

  var exportedImages = 0;
  for (final ann in annotations) {
    final path = ann.imagePath;
    if (path == null) continue;
    final src = File(path);
    if (!await src.exists()) continue;
    final name = attachmentNameFor(book, ann);
    await src.copy('${attachments.path}/$name');
    exportedImages++;
  }

  final markdown = buildObsidianMarkdown(
      book: book, annotations: annotations);
  final mdFile = File('${folder.path}/$slug.md');
  await mdFile.writeAsString(markdown, encoding: utf8, flush: true);

  return ObsidianExportResult(
    folderPath: folder.path,
    markdownPath: mdFile.path,
    exportedAnnotations: annotations.length,
    exportedImages: exportedImages,
  );
}

Uint8List encodeUtf8Bytes(String s) => utf8.encode(s);

String newExportId() => generateId();
