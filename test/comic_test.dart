import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkvault_reader/services/comic_service.dart';

void main() {
  test('CBZ extracts images in natural page order and skips metadata', () async {
    final dir = await Directory.systemTemp.createTemp('baker-cbz-');
    try {
      final archive = Archive()
        ..addFile(ArchiveFile('page10.png', 1, [10]))
        ..addFile(ArchiveFile('page2.png', 1, [2]))
        ..addFile(ArchiveFile('__MACOSX/._page.png', 1, [3]));
      final file = File('${dir.path}/comic.cbz');
      await file.writeAsBytes(ZipEncoder().encode(archive)!);
      final pages = await ComicService().extractAll(file.path, '${dir.path}/pages');
      expect(pages.length, 2);
      expect(await File(pages[0]).readAsBytes(), [2]);
      expect(await File(pages[1]).readAsBytes(), [10]);
    } finally { await dir.delete(recursive: true); }
  });
}
