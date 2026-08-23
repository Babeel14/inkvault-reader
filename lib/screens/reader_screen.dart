import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

import '../models/models.dart';
import '../readers/comic_reader.dart';
import '../readers/epub_reader.dart';
import '../readers/pdf_reader.dart';
import '../services/annotation_store.dart';
import '../services/comic_service.dart';
import '../services/id_gen.dart';
import '../services/library_service.dart';
import '../theme.dart';
import '../widgets/annotation_overlay.dart';
import '../widgets/annotations_panel.dart';
import '../widgets/export_actions.dart';
import '../widgets/note_dialog.dart';
import '../widgets/stylus_recognizer.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.book});

  final Book book;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  static const double _penWidth = 2.6;

  final GlobalKey _captureKey = GlobalKey();

  List<Annotation> _annotations = <Annotation>[];
  bool _chromeVisible = true;
  bool _annotating = false;
  AnnotationTool _tool = AnnotationTool.pen;
  bool _panelOpen = false;
  bool _docReady = false;

  int _page = 0;
  int _pagesCount = 0;
  double _progress = 0;

  PdfControllerPinch? _pdfController;
  PageController? _comicController;
  List<String>? _comicPages;
  String? _comicError;

  final GlobalKey<EpubReaderWidgetState> _readerEpubKey =
      GlobalKey<EpubReaderWidgetState>();

  Timer? _saveDebounce;

  Book get book => widget.book;

  @override
  void initState() {
    super.initState();
    _loadAnnotations();
    _initReader();
  }

  Future<void> _loadAnnotations() async {
    final list = await AnnotationStore.instance.load(book.id);
    if (!mounted) return;
    setState(() {
      _annotations = list
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  Future<void> _persistAnnotations() =>
      AnnotationStore.instance.save(book.id, _annotations);

  Future<void> _initReader() async {
    switch (book.format) {
      case BookFormat.pdf:
        _page = (book.lastPageNumber ?? 1) - 1;
        _pdfController = PdfControllerPinch(
          document: PdfDocument.openFile(book.filePath),
          initialPage: book.lastPageNumber ?? 1,
        );
        break;
      case BookFormat.comic:
        _extractComic();
        break;
      case BookFormat.epub:
        _progress = book.lastRatio;
        break;
    }
  }

  Future<void> _extractComic() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dest = '${docs.path}/inkvault/comics/${book.id}';
      final pages =
          await ComicService().extractAll(book.filePath, dest);
      if (!mounted) return;
      setState(() {
        _comicPages = pages;
        _pagesCount = pages.length;
        _page = ((book.lastPageNumber ?? 1).clamp(1, pages.length)).toInt() - 1;
        _comicController = PageController(initialPage: _page);
        _progress = pages.isEmpty ? 0 : (_page + 1) / pages.length;
        _docReady = true;
      });
      await LibraryService.instance.savePosition(
          book, 'n:${_page + 1}');
    } on ComicException catch (e) {
      if (!mounted) return;
      setState(() => _comicError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _comicError = 'No se pudo abrir el cómic.');
    }
  }

  List<Stroke> strokesForCurrentPage() {
    if (book.format == BookFormat.epub) return const [];
    return _annotations
        .where((a) => !a.isCrop && a.pageIndex == _page)
        .expand((a) => a.strokes)
        .toList();
  }

  String? _epubAnchorNow() {
    if (book.format != BookFormat.epub) return null;
    return _readerEpubKey.currentState?.currentAnchor();
  }

  void _onPdfPage(int page) {
    if (page < 0 || page == _page) return;
    setState(() {
      _page = page;
      _pagesCount = _pdfController?.pagesCount ?? _pagesCount;
      _progress =
          _pagesCount > 0 ? (page + 1) / _pagesCount : _progress;
    });
    _debouncedSavePosition('n:${page + 1}');
  }

  void _onComicPage(int index) {
    if (index == _page) return;
    setState(() {
      _page = index;
      _progress = _pagesCount > 0 ? (index + 1) / _pagesCount : _progress;
    });
    _debouncedSavePosition('n:${index + 1}');
  }

  void _onEpubRatio(double ratio) {
    setState(() => _progress = (ratio.clamp(0.0, 1.0)).toDouble());
    final cfi = _readerEpubKey.currentState?.currentAnchor();
    _debouncedSavePosition(cfi != null && cfi.isNotEmpty ? 'c:$cfi' : 'r:$ratio');
  }

  void _debouncedSavePosition(String position) {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 600), () {
      LibraryService.instance.savePosition(book, position);
    });
  }

  void _toggleChrome() {
    if (_annotating || _panelOpen) return;
    setState(() => _chromeVisible = !_chromeVisible);
  }

  void _toggleAnnotating() {
    setState(() {
      _annotating = !_annotating;
      _tool = AnnotationTool.pen;
      if (_annotating) {
        _panelOpen = false;
        _chromeVisible = false;
      }
    });
  }

  Future<void> _jumpTo(Annotation a) async {
    if (a.pageIndex >= 0) {
      if (book.format == BookFormat.pdf &&
          _pdfController != null &&
          a.pageIndex + 1 <= (_pdfController!.pagesCount ?? 1)) {
        _pdfController!.jumpToPage(a.pageIndex + 1);
      } else if (book.format == BookFormat.comic &&
          _comicController != null) {
        _comicController!.jumpToPage(a.pageIndex);
      }
    } else if (a.anchor.isNotEmpty) {
      _readerEpubKey.currentState?.jumpToAnchor(a.anchor);
    }
  }

  Future<Uint8List?> _captureNormalizedRect(List<double> rectNorm) async {
    try {
      final boundary =
          _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      if (byteData == null) return null;
      final rgba = byteData.buffer.asUint8List();
      final full = img.decodeImage(rgba);
      if (full == null) return null;
      final x = ((rectNorm[0] * full.width).floor()).clamp(0, full.width - 1).toInt();
      final y = ((rectNorm[1] * full.height).floor()).clamp(0, full.height - 1).toInt();
      final w = (((rectNorm[2] - rectNorm[0]).abs() * full.width).round())
          .clamp(1, full.width - x)
          .toInt();
      final h = (((rectNorm[3] - rectNorm[1]).abs() * full.height).round())
          .clamp(1, full.height - y)
          .toInt();
      final cropped = img.copyCrop(full, x, y, w, h);
      return Uint8List.fromList(img.encodePng(cropped));
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _captureStrokesRegion(List<double> pointsNorm) async {
    if (pointsNorm.isEmpty) return null;
    var minX = 1.0, minY = 1.0, maxX = 0.0, maxY = 0.0;
    for (var i = 0; i + 1 < pointsNorm.length; i += 2) {
      final x = pointsNorm[i];
      final y = pointsNorm[i + 1];
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }
    const pad = 0.02;
    return _captureNormalizedRect([
      ((minX - pad).clamp(0.0, 1.0)).toDouble(),
      ((minY - pad).clamp(0.0, 1.0)).toDouble(),
      ((maxX + pad).clamp(0.0, 1.0)).toDouble(),
      ((maxY + pad).clamp(0.0, 1.0)).toDouble(),
    ]);
  }

  Annotation _buildAnnotation({
    required AnnotationKind kind,
    required int pageIndex,
    required String anchor,
    required List<Stroke> strokes,
    required List<double> rectNorm,
  }) {
    return Annotation(
      id: generateId(),
      kind: kind,
      pageIndex: pageIndex,
      anchor: anchor,
      strokes: strokes,
      rectLeft: rectNorm.isNotEmpty ? rectNorm[0] : 0,
      rectTop: rectNorm.length > 1 ? rectNorm[1] : 0,
      rectRight: rectNorm.length > 2 ? rectNorm[2] : 0,
      rectBottom: rectNorm.length > 3 ? rectNorm[3] : 0,
      createdAt: DateTime.now(),
    );
  }

  Future<void> _onPenCommit(List<double> normalizedPoints) async {
    final anchor = _epubAnchorNow() ?? '';
    final stroke = Stroke(
      points: normalizedPoints,
      width: _penWidth,
      color: InkTheme.accent.toARGB32(),
    );
    final annotation = _buildAnnotation(
      kind: AnnotationKind.draw,
      pageIndex: book.format == BookFormat.epub ? -1 : _page,
      anchor: anchor,
      strokes: [stroke],
      rectNorm: const [],
    );

    final note = await showNoteDialog(context, title: 'Nota del dibujo');
    if (!mounted) return;
    annotation.note = note ?? '';

    setState(() {
      _annotations.insert(0, annotation);
    });
    await _persistAnnotations();

    unawaited(() async {
      final png = await _captureStrokesRegion(normalizedPoints);
      if (png == null) return;
      final path = await AnnotationStore.instance.saveCropImage(book.id, png);
      annotation.imagePath = path;
      await _persistAnnotations();
      if (mounted) setState(() {});
    }());
  }

  Future<void> _onCropCommit(List<double> rectNorm) async {
    final messenger = ScaffoldMessenger.of(context);
    final anchor = _epubAnchorNow() ?? '';
    final png = await _captureNormalizedRect(rectNorm);
    if (!mounted) return;

    final note = await showNoteDialog(
      context,
      title: 'Nota del recorte',
      previewPng: png,
    );
    if (!mounted) return;

    final annotation = _buildAnnotation(
      kind: AnnotationKind.crop,
      pageIndex: book.format == BookFormat.epub ? -1 : _page,
      anchor: anchor,
      strokes: const [],
      rectNorm: rectNorm,
    )..note = note ?? '';

    if (png != null) {
      annotation.imagePath =
          await AnnotationStore.instance.saveCropImage(book.id, png);
    }

    setState(() {
      _annotations.insert(0, annotation);
    });
    await _persistAnnotations();
    messenger.showSnackBar(
      SnackBar(content: Text(png != null
          ? 'Recorte guardado${annotation.note.isNotEmpty ? ' con nota' : ''}'
          : 'Recorte guardado sin imagen'),
      ),
    );
  }

  Future<void> _deleteAnnotation(Annotation a) async {
    setState(() => _annotations.remove(a));
    await AnnotationStore.instance.deleteImageOf(a);
    await _persistAnnotations();
  }

  Future<void> _editNote(Annotation a) async {
    final note = await showNoteDialog(context, initial: a.note);
    if (!mounted || note == null) return;
    a.note = note;
    await _persistAnnotations();
    setState(() {});
  }

  void _openPanel() => setState(() => _panelOpen = true);

  void _closePanel() => setState(() => _panelOpen = false);

  Future<void> _back() async {
    _saveDebounce?.cancel();
    await LibraryService.instance.persist();
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          RepaintBoundary(
            key: _captureKey,
            child: ScrollConfiguration(
              behavior: const ReaderScrollBehavior(),
              child: _buildReader(),
            ),
          ),
          if (!_docReady && book.format != BookFormat.pdf)
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          Positioned.fill(
            child: RawGestureDetector(
              behavior: HitTestBehavior.translucent,
              gestures: <Type, GestureRecognizerFactory>{
                TapGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                  () => TapGestureRecognizer(debugOwner: this),
                  (instance) => instance.onTap = _toggleChrome,
                ),
              },
              child: const SizedBox.expand(),
            ),
          ),
          if (_annotating)
            AnnotationOverlay(
              tool: _tool,
              penColor: InkTheme.accent,
              penWidth: _penWidth,
              existingStrokes: strokesForCurrentPage(),
              onPenCommit: _onPenCommit,
              onCropCommit: _onCropCommit,
            ),
          _buildBackdrop(),
          _buildChrome(),
          _buildFabColumn(),
          _buildPanel(),
        ],
      ),
    );
  }

  Widget _buildPanel() {
    return Positioned(
      top: 0,
      bottom: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !_panelOpen,
        child: AnimatedSlide(
          offset: _panelOpen ? Offset.zero : const Offset(1, 0),
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          child: AnnotationsPanel(
            annotations: _annotations,
            onTapItem: (a) {
              _closePanel();
              _jumpTo(a);
            },
            onDelete: _deleteAnnotation,
            onEditNote: _editNote,
            onClose: _closePanel,
          ),
        ),
      ),
    );
  }

  Widget _buildReader() {
    switch (book.format) {
      case BookFormat.pdf:
        final controller = _pdfController;
        if (controller == null) return const SizedBox.expand();
        return PdfReaderWidget(
          controller: controller,
          onPageChanged: _onPdfPage,
          onDocumentReady: () {
            if (!_docReady) setState(() => _docReady = true);
          },
        );
      case BookFormat.comic:
        if (_comicError != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                _comicError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
            ),
          );
        }
        final pages = _comicPages;
        final controller = _comicController;
        if (pages == null || controller == null) {
          return const SizedBox.expand();
        }
        return ComicReaderWidget(
          pages: pages,
          controller: controller,
          onPageChanged: _onComicPage,
        );
      case BookFormat.epub:
        return KeyedSubtree(
          key: ValueKey('epub-${book.id}'),
          child: EpubReaderWidget(
            key: _readerEpubKey,
            filePath: book.filePath,
            initialCfi: book.lastCfi,
            onProgressRatio: _onEpubRatio,
            onDocumentReady: () {
              if (!_docReady) setState(() => _docReady = true);
            },
            onDocumentError: (_) {},
          ),
        );
    }
  }

  Widget _buildBackdrop() {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !_panelOpen,
        child: GestureDetector(
          onTap: _closePanel,
          child: AnimatedOpacity(
            opacity: _panelOpen ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: Container(color: Colors.black.withValues(alpha: 0.35)),
          ),
        ),
      ),
    );
  }

  Widget _buildChrome() {
    final label = bookFormatLabel(book.format);
    final subtitle =
        book.author.isEmpty ? label : '$label · ${book.author}';
    final pageText = book.format == BookFormat.epub
        ? '${(_progress * 100).toStringAsFixed(0)} %'
        : _pagesCount > 0
            ? '${_page + 1} / $_pagesCount'
            : '…';
    return IgnorePointer(
      ignoring: !_chromeVisible,
      child: Column(
        children: [
          _TopBar(
            visible: _chromeVisible,
            title: book.title,
            subtitle: subtitle,
            annotationCount: _annotations.length,
            onBack: _back,
            onExport: () => exportBookToObsidianFlow(
                context, book, _annotations),
            onOpenPanel: _openPanel,
          ),
          const Spacer(),
          _BottomBar(
            visible: _chromeVisible,
            progress: _progress,
            interactive: book.format != BookFormat.epub,
            pageLabel: pageText,
            onSeek: (v) {
              if (book.format == BookFormat.pdf && _pagesCount > 0) {
                _pdfController?.jumpToPage(
                    ((v * _pagesCount).ceil()).clamp(1, _pagesCount).toInt());
              } else if (book.format == BookFormat.comic && _pagesCount > 0) {
                _comicController?.jumpToPage(
                    ((v * _pagesCount).floor()).clamp(0, _pagesCount - 1).toInt());
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFabColumn() {
    return AnimatedPositioned(
      right: 18,
      bottom: _chromeVisible ? 92 : 26,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: _annotating
            ? _AnnotateTools(
                tool: _tool,
                canUndo: strokesForCurrentPage().isNotEmpty,
                onSelectTool: (t) => setState(() => _tool = t),
                onUndo: () async {
                  for (final a in List<Annotation>.from(_annotations)) {
                    if (!a.isCrop && a.pageIndex == _page) {
                      await _deleteAnnotation(a);
                      break;
                    }
                  }
                },
                onExit: _toggleAnnotating,
              )
            : FloatingActionButton.small(
                heroTag: 'inkvault-pencil',
                onPressed: _toggleAnnotating,
                tooltip: 'Modo anotación',
                child: const Icon(Icons.draw_outlined),
              ),
      ),
    );
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _pdfController?.dispose();
    _comicController?.dispose();
    super.dispose();
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.visible,
    required this.title,
    required this.subtitle,
    required this.annotationCount,
    required this.onBack,
    required this.onExport,
    required this.onOpenPanel,
  });

  final bool visible;
  final String title;
  final String subtitle;
  final int annotationCount;
  final VoidCallback onBack;
  final VoidCallback onExport;
  final VoidCallback onOpenPanel;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, -1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: InkTheme.ink,
                              fontWeight: FontWeight.w600)),
                      if (subtitle.isNotEmpty)
                        Text(subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: InkTheme.inkDim, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.upload_file_outlined),
                  tooltip: 'Exportar a Obsidian',
                  onPressed: onExport,
                ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.format_list_bulleted),
                      tooltip: 'Anotaciones',
                      onPressed: onOpenPanel,
                    ),
                    if (annotationCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: InkTheme.accent,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          constraints:
                              const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            '$annotationCount',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 10,
                              height: 1.15,
                              color: Color(0xFF241A08),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.visible,
    required this.progress,
    required this.interactive,
    required this.pageLabel,
    required this.onSeek,
  });

  final bool visible;
  final double progress;
  final bool interactive;
  final String pageLabel;
  final void Function(double value) onSeek;

  @override
  Widget build(BuildContext context) {
    final slider = SliderTheme(
      data: Theme.of(context).sliderTheme,
      child: Slider(
        value: (progress.clamp(0.0, 1.0)).toDouble(),
        onChanged: onSeek,
      ),
    );
    return AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: interactive
                      ? slider
                      : IgnorePointer(
                          ignoring: true,
                          child: slider,
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 18),
                  child: Text(
                    pageLabel,
                    style: const TextStyle(
                      color: InkTheme.inkDim,
                      fontSize: 13,
                      fontFeatures: [ui.FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnnotateTools extends StatelessWidget {
  const _AnnotateTools({
    required this.tool,
    required this.canUndo,
    required this.onSelectTool,
    required this.onUndo,
    required this.onExit,
  });

  final AnnotationTool tool;
  final bool canUndo;
  final void Function(AnnotationTool tool) onSelectTool;
  final VoidCallback onUndo;
  final VoidCallback onExit;

  Widget _btn({
    required IconData icon,
    required String tooltip,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return FloatingActionButton.small(
      heroTag: tooltip,
      onPressed: onTap,
      backgroundColor: selected ? InkTheme.accent : InkTheme.surfaceHigh,
      foregroundColor: selected ? const Color(0xFF241A08) : InkTheme.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Icon(icon, size: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn(
          icon: Icons.close,
          tooltip: 'Salir de anotaciones',
          selected: false,
          onTap: onExit,
        ),
        const SizedBox(height: 10),
        _btn(
          icon: Icons.draw_outlined,
          tooltip: 'Lápiz',
          selected: tool == AnnotationTool.pen,
          onTap: () => onSelectTool(AnnotationTool.pen),
        ),
        const SizedBox(height: 10),
        _btn(
          icon: Icons.crop_free_rounded,
          tooltip: 'Recorte',
          selected: tool == AnnotationTool.crop,
          onTap: () => onSelectTool(AnnotationTool.crop),
        ),
        const SizedBox(height: 10),
        _btn(
          icon: Icons.undo,
          tooltip: 'Deshacer',
          selected: false,
          onTap: canUndo ? onUndo : () {},
        ),
      ],
    );
  }
}
