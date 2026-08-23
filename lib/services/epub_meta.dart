import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:collection/collection.dart';
import 'package:xml/xml.dart';

class EpubMeta {
  const EpubMeta({
    required this.title,
    required this.author,
    this.coverBytes,
    this.coverExt,
  });

  final String title;
  final String author;
  final Uint8List? coverBytes;
  final String? coverExt;
}

String? _attrByName(XmlElement el, String localName) {
  for (final a in el.attributes) {
    if (a.name.local.toLowerCase() == localName.toLowerCase()) return a.value;
  }
  return null;
}

Iterable<XmlElement> _elementsByLocal(XmlNode node, String local) sync* {
  for (final e in node.descendantElements) {
    if (e.name.local.toLowerCase() == local.toLowerCase()) yield e;
  }
}

String _zipPathJoin(String baseDir, String href) {
  final decoded = Uri.decodeComponent(href.replaceAll('\\', '/'));
  final parts = <String>[];
  if (!decoded.startsWith('/')) parts.addAll(baseDir.split('/'));
  for (final seg in decoded.split('/')) {
    if (seg.isEmpty || seg == '.') continue;
    if (seg == '..') {
      if (parts.isNotEmpty) parts.removeLast();
      continue;
    }
    parts.add(seg);
  }
  return parts.join('/');
}

ArchiveFile? _findEntry(Archive arch, String path) {
  for (final f in arch.files) {
    if (!f.isFile) continue;
    if (f.name == path || f.name.toLowerCase() == path.toLowerCase()) return f;
  }
  return null;
}

Uint8List? _entryBytes(ArchiveFile f) {
  final c = f.content;
  if (c is Uint8List) return c;
  if (c is List<int>) return Uint8List.fromList(c);
  if (c is InputStreamBase) {
    final stream = c;
    final data = stream.readBytes(stream.length);
    return data.toUint8List();
  }
  return null;
}

String? _sniffImageExt(Uint8List b) {
  if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8) return 'jpg';
  if (b.length >= 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) {
    return 'png';
  }
  if (b.length >= 12 &&
      b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) {
    return 'webp';
  }
  if (b.length >= 6 &&
      b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46) {
    return 'gif';
  }
  return null;
}

EpubMeta parseEpubMeta(Uint8List epubBytes) {
  final arch = ZipDecoder().decodeBytes(epubBytes);

  ArchiveFile? container = _findEntry(arch, 'META-INF/container.xml');
  String opfPath = '';
  if (container != null) {
    final bytes = _entryBytes(container);
    if (bytes != null) {
      try {
        final doc = XmlDocument.parse(utf8.decode(bytes));
        for (final rf in _elementsByLocal(doc, 'rootfile')) {
          final p = _attrByName(rf, 'full-path');
          if (p != null && p.isNotEmpty) {
            opfPath = p;
            break;
          }
        }
      } catch (_) {}
    }
  }

  String title = '';
  String author = '';
  Uint8List? coverBytes;
  String? coverExt;

  final opfEntry = opfPath.isEmpty ? null : _findEntry(arch, opfPath);
  if (opfEntry != null) {
    final opfBytes = _entryBytes(opfEntry);
    if (opfBytes != null) {
      try {
        final opf = XmlDocument.parse(utf8.decode(opfBytes));
        final metadata = _elementsByLocal(opf, 'metadata').firstOrNull;
        if (metadata != null) {
          for (final t in metadata.childElements) {
            if (t.name.local.toLowerCase() == 'title' &&
                (t.name.prefix == null || t.name.prefix == 'dc')) {
              title = t.innerText.trim();
              break;
            }
          }
          for (final c in metadata.childElements) {
            if (c.name.local.toLowerCase() == 'creator' &&
                (c.name.prefix == null || c.name.prefix == 'dc')) {
              author = c.innerText.trim();
              break;
            }
          }
        }

        final manifest =
            _elementsByLocal(opf, 'manifest').firstOrNull;
        final coverMetaId = (() {
          final md = _elementsByLocal(opf, 'metadata').firstOrNull;
          if (md == null) return null;
          for (final m in md.childElements) {
            if (m.name.local.toLowerCase() == 'meta' &&
                (_attrByName(m, 'name')?.toLowerCase() ?? '') == 'cover') {
              return _attrByName(m, 'content');
            }
          }
          return null;
        })();

        String? coverHref;
        if (manifest != null) {
          for (final item in manifest.childElements) {
            if (item.name.local.toLowerCase() != 'item') continue;
            final id = _attrByName(item, 'id');
            final props = _attrByName(item, 'properties') ?? '';
            if ((coverMetaId != null && id == coverMetaId) ||
                props.split(RegExp(r'\s+')).contains('cover-image')) {
              coverHref = _attrByName(item, 'href');
              break;
            }
          }
        }

        if (coverHref != null && coverHref.isNotEmpty) {
          final baseDir =
              opfPath.contains('/') ? opfPath.substring(0, opfPath.lastIndexOf('/')) : '';
          final coverPath = _zipPathJoin(baseDir, coverHref);
          final entry = _findEntry(arch, coverPath);
          if (entry != null) {
            final b = _entryBytes(entry);
            if (b != null) {
              coverBytes = b;
              coverExt = _sniffImageExt(b);
            }
          }
        }
      } catch (_) {}
    }
  }

  return EpubMeta(
    title: title,
    author: author,
    coverBytes: coverBytes,
    coverExt: coverExt,
  );
}
