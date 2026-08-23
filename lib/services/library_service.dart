import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

import '../models/models.dart';
import 'comic_service.dart';
import 'epub_meta.dart';
import 'id_gen.dart';

class LibraryService {
  LibraryService._();
  static final LibraryService instance = LibraryService._();

  final List<Book> books = [];
  String? _rootPath;

  Future<String> _root() async {
    if (_rootPath != null) return _rootPath!;
    final docs = await getApplicationDocumentsDirectory();
    _rootPath = '${docs.path}/inkvault';
    await Directory(_rootPath!).create(recursive: true);
    return _rootPath!;
  }

  Future<String> _booksDir() async {
    final p = '${await _root()}/books';
    await Directory(p).create(recursive: true);
    return p;
  }

  Future<String> _coversDir() async {
    final p = '${await _root()}/covers';
    await Directory(p).create(recursive: true);
    return p;
  }

  Future<File> _libraryFile() async {
    final p = '${await _root()}/library.json';
    return File(p);
  }

  Future<List<Book>> load() async {
    try {
      final f = await _libraryFile();
      if (!await f.exists()) {
        books.clear();
        return books;
      }
      final raw = await f.readAsString();
      final list = jsonDecode(raw) as List<dynamic>;
      books
        ..clear()
        ..addAll(list
            .map((e) => Book.fromJson(e as Map<String, dynamic>))
            .toList());
    } catch (_) {
      books.clear();
    }
    books.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return books;
  }

  Future<void> persist() async {
    final f = await _libraryFile();
    await f.writeAsString(
      jsonEncode(books.map((b) => b.toJson()).toList()),
      flush: true,
    );
  }

  bool isSupported(String path) {
    final ext = path.split('.').last.toLowerCase();
    const allowed = ['pdf', 'epub', 'cbz', 'cbr'];
    return allowed.contains(ext);
  }

  String titleFromFile(String path) {
    var name = path.split(Platform.pathSeparator).last;
    final dot = name.lastIndexOf('.');
    if (dot > 0) name = name.substring(0, dot);
    return name.replaceAll(RegExp(r'[_\.]+'), ' ').trim();
  }

  Future<Book?> importFromPath(String sourcePath) async {
    if (!isSupported(sourcePath)) return null;
    final format = bookFormatFromExtension(sourcePath.split('.').last);
    final id = generateId();
    final booksDir = await _booksDir();
    final dest =
        '$booksDir/$id.${sourcePath.split('.').last.toLowerCase()}';
    final copied = await File(sourcePath).copy(dest);

    var title = titleFromFile(sourcePath);
    var author = '';
    String? coverPath;
    int pageCount = 0;

    switch (format) {
      case BookFormat.pdf:
        try {
          final doc = await PdfDocument.openFile(copied.path);
          pageCount = doc.pagesCount;
          final page = await doc.getPage(1);
          const w = 720.0;
          final h = (w * page.height / page.width).roundToDouble();
          final img = await page.render(
            width: w,
            height: h,
            format: PdfPageImageFormat.png,
          );
          await page.close();
          final renderedBytes = img?.bytes;
          if (renderedBytes != null) {
            final covers = await _coversDir();
            coverPath = '$covers/$id.png';
            await File(coverPath).writeAsBytes(renderedBytes, flush: true);
          }
          await doc.close();
        } catch (_) {}
        break;
      case BookFormat.epub:
        try {
          final bytes = await copied.readAsBytes();
          final meta = parseEpubMeta(bytes);
          if (meta.title.isNotEmpty) title = meta.title;
          if (meta.author.isNotEmpty) author = meta.author;
          if (meta.coverBytes != null && meta.coverExt != null) {
            final covers = await _coversDir();
            coverPath = '$covers/$id.${meta.coverExt}';
            await File(coverPath).writeAsBytes(meta.coverBytes!, flush: true);
          }
        } catch (_) {}
        break;
      case BookFormat.comic:
        try {
          final comic = ComicService();
          final first = await comic.firstImageBytes(copied.path);
          if (first != null) {
            final decoded = img.decodeImage(first);
            if (decoded != null) {
              final thumb =
                  decoded.width > 720 ? img.copyResize(decoded, width: 720) : decoded;
              final covers = await _coversDir();
              coverPath = '$covers/$id.png';
              await File(coverPath)
                  .writeAsBytes(img.encodePng(thumb), flush: true);
            }
          }
        } catch (_) {
          coverPath = null;
        }
        break;
    }

    final book = Book(
      id: id,
      title: title,
      author: author,
      format: format,
      filePath: copied.path,
      addedAt: DateTime.now(),
      coverPath: coverPath,
      pageCount: pageCount,
    );
    books.insert(0, book);
    await persist();
    return book;
  }

  Future<void> updateBook(Book book) => persist();

  Future<void> delete(Book book) async {
    books.removeWhere((b) => b.id == book.id);
    await persist();
    try {
      final f = File(book.filePath);
      if (await f.exists()) await f.delete();
    } catch (_) {}
    final cover = book.coverPath;
    if (cover != null) {
      try {
        final cf = File(cover);
        if (await cf.exists()) await cf.delete();
      } catch (_) {}
    }
    try {
      final root = await _root();
      final crops = Directory('$root/crops/${book.id}');
      if (await crops.exists()) await crops.delete(recursive: true);
      final anns = File('$root/annotations/${book.id}.json');
      if (await anns.exists()) await anns.delete();
    } catch (_) {}
  }

  Future<void> savePosition(Book book, String position) async {
    book.lastPosition = position;
    await persist();
  }
}
