import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';

class ComicException implements Exception {
  ComicException(this.message);
  final String message;

  @override
  String toString() => message;
}

const _imageExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp'];

bool _isImageEntry(String name) {
  final lower = name.toLowerCase();
  if (!lower.startsWith('.') && !name.contains('__MACOSX')) {
    for (final ext in _imageExtensions) {
      if (lower.endsWith(ext)) return true;
    }
  }
  return false;
}

int _naturalCompare(String a, String b) {
  final ra = RegExp(r'(\d+)|(\D+)');
  final rb = RegExp(r'(\d+)|(\D+)');
  final ma = ra.allMatches(a.toLowerCase()).iterator;
  final mb = rb.allMatches(b.toLowerCase()).iterator;
  while (true) {
    final ca = ma.moveNext();
    final cb = mb.moveNext();
    if (!ca && !cb) return 0;
    if (!ca) return -1;
    if (!cb) return 1;
    final sa = ma.current.group(0)!;
    final sb = mb.current.group(0)!;
    final na = int.tryParse(sa);
    final nb = int.tryParse(sb);
    if (na != null && nb != null) {
      final cmp = na.compareTo(nb);
      if (cmp != 0) return cmp;
    } else {
      final cmp = sa.compareTo(sb);
      if (cmp != 0) return cmp;
    }
  }
}

Uint8List? archiveEntryBytes(ArchiveFile f) {
  final c = f.content;
  if (c is Uint8List) return c;
  if (c is List<int>) return Uint8List.fromList(c);
  if (c is InputStreamBase) {
    return c.readBytes(c.length).toUint8List();
  }
  return null;
}

class ComicService {
  Archive _openArchive(String path) {
    InputFileStream? stream;
    try {
      stream = InputFileStream(path);
      final arch = ZipDecoder().decodeBuffer(stream);
      return arch;
    } catch (_) {
      stream?.closeSync();
      throw ComicException(
          'El cómic usa compresión RAR o está dañado. Conviértelo a CBZ e impórtalo de nuevo.');
    }
  }

  List<ArchiveFile> imageFiles(Archive arch) {
    final files =
        arch.files.where((f) => f.isFile && _isImageEntry(f.name)).toList()
          ..sort((a, b) => _naturalCompare(a.name, b.name));
    return files;
  }

  Future<List<String>> extractAll(String archivePath, String destDir) async {
    final dir = Directory(destDir);
    await dir.create(recursive: true);
    final arch = _openArchive(archivePath);
    final files = imageFiles(arch);
    if (files.isEmpty) {
      arch.clear();
      throw ComicException('No se encontraron imágenes dentro del cómic.');
    }
    final paths = <String>[];
    var index = 0;
    for (final f in files) {
      final bytes = archiveEntryBytes(f);
      if (bytes == null || bytes.isEmpty) continue;
      final dot = f.name.lastIndexOf('.');
      final ext = dot >= 0 ? f.name.substring(dot).toLowerCase() : '.jpg';
      final p = '${dir.path}${Platform.pathSeparator}'
          'page_${index.toString().padLeft(5, '0')}$ext';
      await File(p).writeAsBytes(bytes, flush: true);
      paths.add(p);
      index++;
    }
    arch.clear();
    if (paths.isEmpty) {
      throw ComicException('No se pudieron extraer las imágenes del cómic.');
    }
    return paths;
  }

  Future<Uint8List?> firstImageBytes(String archivePath) async {
    final arch = _openArchive(archivePath);
    final files = imageFiles(arch);
    if (files.isEmpty) return null;
    final bytes = archiveEntryBytes(files.first);
    arch.clear();
    return bytes;
  }
}
