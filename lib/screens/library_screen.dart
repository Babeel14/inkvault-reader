import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/annotation_store.dart';
import '../services/library_service.dart';
import '../theme.dart';
import 'reader_screen.dart';
import '../widgets/export_actions.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final List<Book> _books = <Book>[];
  bool _loading = true;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final books = await LibraryService.instance.load();
    if (!mounted) return;
    setState(() {
      _books
        ..clear()
        ..addAll(books);
      _loading = false;
    });
  }

  Future<void> _import() async {
    if (_importing) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _importing = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'epub', 'cbz', 'cbr'],
      );
      final path = result?.files.single.path;
      if (path == null) return;
      final book = await LibraryService.instance.importFromPath(path);
      if (!mounted) return;
      if (book == null) {
        messenger.showSnackBar(const SnackBar(
            content: Text('Formato no soportado (usa pdf, epub, cbz o cbr)')));
        return;
      }
      setState(() {});
      messenger.showSnackBar(
          SnackBar(content: Text('Añadido a la biblioteca · ${book.title}')));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('No se pudo importar el archivo')));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _open(Book book) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => ReaderScreen(book: book),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  Future<void> _showActions(Book book) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: InkTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.menu_book_outlined,
                  color: InkTheme.accent),
              title: Text(book.title,
                  style: const TextStyle(color: InkTheme.ink)),
              subtitle: book.author.isEmpty
                  ? null
                  : Text(book.author,
                      style: const TextStyle(color: InkTheme.inkDim)),
            ),
            const Divider(indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.play_arrow_rounded, color: InkTheme.ink),
              title: const Text('Leer',
                  style: TextStyle(color: InkTheme.ink)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _open(book);
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined,
                  color: InkTheme.ink),
              title: const Text('Exportar a Obsidian',
                  style: TextStyle(color: InkTheme.ink)),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final annotations =
                    await AnnotationStore.instance.load(book.id);
                if (!mounted) return;
                exportBookToObsidianFlow(context, book, annotations);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: InkTheme.danger),
              title: const Text('Eliminar',
                  style: TextStyle(color: InkTheme.danger)),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final confirmed = await _confirmDelete(book);
                if (confirmed != true) return;
                await LibraryService.instance.delete(book);
                if (mounted) setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(Book book) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar libro'),
        content: Text(
            '"${book.title}" se borrará junto con sus anotaciones. Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: InkTheme.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final columns = width > 1400 ? 6 : (width > 1000 ? 5 : (width > 700 ? 4 : 3));
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('InkVault',
                        style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                            color: InkTheme.ink)),
                    const SizedBox(width: 10),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        _loading ? '' : '${_books.length} libros',
                        style: const TextStyle(
                            color: InkTheme.inkDim, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_books.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_stories_outlined,
                          size: 64, color: Colors.white.withValues(alpha: 0.15)),
                      const SizedBox(height: 16),
                      Text('Tu biblioteca está vacía',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 16)),
                      const SizedBox(height: 6),
                      Text('Importa PDF, ePub, CBZ o CBR',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.32),
                              fontSize: 13)),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: _import,
                        icon: const Icon(Icons.add),
                        label: const Text('Importar archivo'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: InkTheme.accent,
                          side: BorderSide(color: InkTheme.accent.withValues(alpha: 0.5)),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    childAspectRatio: 0.58,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 18,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _BookTile(
                      book: _books[index],
                      onTap: () => _open(_books[index]),
                      onLongPress: () => _showActions(_books[index]),
                    ),
                    childCount: _books.length,
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'inkvault-import',
        onPressed: _importing ? null : _import,
        icon: _importing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.add),
        label: const Text('Importar'),
      ),
    );
  }
}

class _BookTile extends StatelessWidget {
  const _BookTile({
    required this.book,
    required this.onTap,
    required this.onLongPress,
  });

  final Book book;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  Widget _cover() {
    final cover = book.coverPath;
    if (cover != null && File(cover).existsSync()) {
      return Image.file(File(cover), fit: BoxFit.cover);
    }
    return Container(
      color: InkTheme.surfaceHigh,
      alignment: Alignment.center,
      child: Text(
        book.title.isNotEmpty ? book.title.characters.first.toUpperCase() : '?',
        style: TextStyle(
          fontSize: 42,
          fontWeight: FontWeight.w300,
          color: InkTheme.accent.withValues(alpha: 0.55),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progressLabel = book.lastPageNumber != null && book.pageCount > 0
        ? 'pág ${book.lastPageNumber}'
        : (book.format == BookFormat.comic && book.pageCount > 0
            ? '${book.pageCount} págs'
            : book.author);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: InkTheme.outline),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _cover(),
                  ),
                ),
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onTap,
                      onLongPress: onLongPress,
                      borderRadius: BorderRadius.circular(14),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: _FormatChip(format: book.format),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          Text(book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: InkTheme.ink, fontSize: 13.5, height: 1.2)),
          const SizedBox(height: 2),
          Text(progressLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35), fontSize: 11.5)),
        ],
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  const _FormatChip({required this.format});

  final BookFormat format;

  @override
  Widget build(BuildContext context) {
    final text = switch (format) {
      BookFormat.pdf => 'PDF',
      BookFormat.epub => 'EPUB',
      BookFormat.comic => 'CBZ/CBR',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(text,
          style: const TextStyle(
              color: InkTheme.accent, fontSize: 9.5, letterSpacing: 0.8)),
    );
  }
}
