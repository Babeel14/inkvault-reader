import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:epub_view/epub_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkvault_reader/services/epub_meta.dart';

void main() {
  test('a standard EPUB opens and retains accented metadata', () async {
    final dir = await Directory.systemTemp.createTemp('baker-epub-');
    try {
      final entries = {
        'mimetype': 'application/epub+zip',
        'META-INF/container.xml': '<?xml version="1.0"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>',
        'OEBPS/content.opf': '<?xml version="1.0"?><package version="2.0" xmlns="http://www.idpf.org/2007/opf" unique-identifier="id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>El pan recién hecho</dc:title><dc:creator>Baker</dc:creator><dc:language>es</dc:language><dc:identifier id="id">baker-test</dc:identifier></metadata><manifest><item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/><item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/></manifest><spine toc="ncx"><itemref idref="chapter"/></spine></package>',
        'OEBPS/toc.ncx': '<?xml version="1.0"?><ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1"><head/><docTitle><text>Pan</text></docTitle><navMap><navPoint id="chapter" playOrder="1"><navLabel><text>Capítulo 1</text></navLabel><content src="chapter.xhtml"/></navPoint></navMap></ncx>',
        'OEBPS/chapter.xhtml': '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Capítulo 1</title></head><body><h1>El pan</h1><p>Lectura de prueba.</p></body></html>',
      };
      final archive = Archive();
      entries.forEach((name, text) { final bytes = utf8.encode(text); archive.addFile(ArchiveFile(name, bytes.length, bytes)); });
      final bytes = Uint8List.fromList(ZipEncoder().encode(archive)!);
      final file = await File('${dir.path}/book.epub').writeAsBytes(bytes);
      expect(parseEpubMeta(bytes).title, 'El pan recién hecho');
      final book = await EpubDocument.openFile(file);
      expect(book.Title, 'El pan recién hecho');
      expect(book.Chapters, isNotEmpty);
    } finally { await dir.delete(recursive: true); }
  });
  test('invalid EPUB reports failure rather than an empty document', () async {
    final dir = await Directory.systemTemp.createTemp('baker-epub-bad-');
    try {
      final file = await File('${dir.path}/bad.epub').writeAsString('not a book');
      await expectLater(EpubDocument.openFile(file), throwsA(anything));
    } finally { await dir.delete(recursive: true); }
  });
}
