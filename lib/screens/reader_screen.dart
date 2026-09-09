import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

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
import '../widgets/saved_ink.dart';

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
  bool _annotationsReady = false;
  bool _saving = false;
  bool _touchInk = false;
  bool _inputInitialized = false;
  String? _documentError;
  final _overlayKey = GlobalKey<AnnotationOverlayState>();

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_inputInitialized) {
      _inputInitialized = true;
      _touchInk = MediaQuery.sizeOf(context).shortestSide < 600;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadAnnotations();
    _initReader();
  }

  Future<void> _loadAnnotations() async {
    List<Annotation> list;
    try { list = await AnnotationStore.instance.load(book.id); }
    catch (e) { if (mounted) _showError(e.toString()); return; }
    if (!mounted) return;
    setState(() {
      _annotationsReady = true;
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
      setState(() => _comicError = 'No se pudo abrir el cÃ³mic.');
    }
  }

  List<Stroke> strokesForCurrentPage() {
    if (book.format == BookFormat.epub) {
      final anchor = _epubAnchorNow();
      return _annotations.where((a) => !a.isCrop && a.anchor.isNotEmpty && a.anchor == anchor).expand((a) => a.strokes).toList();
    }
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
    book.lastPosition = position;
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
    if (!_docReady || !_annotationsReady || _saving) return;
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
      final longest = boundary.size.longestSide;
      final image = await boundary.toImage(pixelRatio: (2400 / longest).clamp(1.0, 3.0));
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
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

  void _showError(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveDraft() async {
    if (_saving) return;
    final overlay = _overlayKey.currentState;
    if (overlay == null) return;
    final strokes = overlay.drafts;
    final crop = overlay.crop;
    if ((_tool == AnnotationTool.crop && crop == null) || (_tool == AnnotationTool.pen && strokes.isEmpty)) {
      _showError('Dibuja o selecciona una zona antes de guardar.'); return;
    }
    setState(() => _saving = true);
    try {
      final annotation = _buildAnnotation(
        kind: _tool == AnnotationTool.crop ? AnnotationKind.crop : AnnotationKind.draw,
        pageIndex: book.format == BookFormat.epub ? -1 : _page,
        anchor: _epubAnchorNow() ?? '', strokes: strokes, rectNorm: crop ?? const []);
      overlay.setCaptureMode(true);
      await WidgetsBinding.instance.endOfFrame;
      final png = await _captureNormalizedRect(crop ?? [0, 0, 1, 1]);
      if (overlay.mounted) overlay.setCaptureMode(false);
      if (png == null) { _showError('No se pudo capturar la imagen. La selección se conserva; vuelve a intentarlo.'); return; }
      if (!mounted) return;
      final note = await showNoteDialog(context, title: 'Guardar anotación', previewPng: png);
      if (!mounted || note == null) return;
      annotation.note = note;
      annotation.imagePath = await AnnotationStore.instance.saveCropImage(book.id, png);
      final updated = [annotation, ..._annotations];
      await AnnotationStore.instance.save(book.id, updated);
      if (!mounted) return;
      setState(() { _annotations = updated; });
      overlay.clear();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Anotación guardada'),
        action: SnackBarAction(label: 'Obsidian', onPressed: () => exportBookToObsidianFlow(context, book, [annotation]))));
    } catch (e) { _showError('No se pudo guardar: $e'); }
    finally { if (mounted) setState(() => _saving = false); }
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
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _toggleChrome,
            child: RepaintBoundary(
              key: _captureKey,
              child: Stack(fit: StackFit.expand, children: [
                IgnorePointer(ignoring: _annotating, child: ScrollConfiguration(
                  behavior: const ReaderScrollBehavior(), child: _buildReader())),
                SavedInk(strokes: strokesForCurrentPage()),
                if (_annotating) AnnotationOverlay(
                  key: _overlayKey, touchEnabled: _touchInk,
                  tool: _tool, penColor: InkTheme.accent, penWidth: _penWidth,
                  existingStrokes: const [], onPenCommit: (_) {}, onCropCommit: (_) {}),
              ]),
            ),
          ),
          if (!_docReady && _documentError == null && _comicError == null && book.format != BookFormat.pdf)
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          if (_documentError != null)
            Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline, size: 40), const SizedBox(height: 12),
              Text(_documentError!, textAlign: TextAlign.center),
              TextButton(onPressed: _back, child: const Text('Volver a la biblioteca')),
            ]))),
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
            onExport: (a) => exportBookToObsidianFlow(context, book, [a]),
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
            if (!_docReady) setState(() { _docReady = true; _pagesCount = _pdfController?.pagesCount ?? _pagesCount; if (_pagesCount > 0) _progress = (_page + 1) / _pagesCount; });
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
              if (!_docReady) setState(() { _docReady = true; _pagesCount = _pdfController?.pagesCount ?? _pagesCount; if (_pagesCount > 0) _progress = (_page + 1) / _pagesCount; });
            },
            onDocumentError: (message) { if (mounted) setState(() => _documentError = 'No se pudo abrir el EPUB: $message'); },
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
        book.author.isEmpty ? label : '$label Â· ${book.author}';
    final pageText = book.format == BookFormat.epub
        ? '${(_progress * 100).toStringAsFixed(0)} %'
        : _pagesCount > 0
            ? '${_page + 1} / $_pagesCount'
            : 'â€¦';
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
    return Positioned(right: 12, left: _annotating ? 12 : null, bottom: _chromeVisible ? 92 : 24,
      child: SafeArea(top: false, child: _annotating ? Material(
        color: InkTheme.surfaceHigh, borderRadius: BorderRadius.circular(18),
        child: Padding(padding: const EdgeInsets.all(8), child: Wrap(alignment: WrapAlignment.center, children: [
          IconButton(tooltip: 'Cancelar selección y salir', onPressed: _saving ? null : () { _overlayKey.currentState?.clear(); _toggleAnnotating(); }, icon: const Icon(Icons.close)),
          IconButton(tooltip: 'Lápiz', onPressed: _saving ? null : () { _overlayKey.currentState?.clear(); setState(() => _tool = AnnotationTool.pen); }, icon: Icon(Icons.draw, color: _tool == AnnotationTool.pen ? InkTheme.accent : null)),
          IconButton(tooltip: 'Seleccionar recorte (arrastra de nuevo para ajustar)', onPressed: _saving ? null : () { _overlayKey.currentState?.clear(); setState(() => _tool = AnnotationTool.crop); }, icon: Icon(Icons.crop, color: _tool == AnnotationTool.crop ? InkTheme.accent : null)),
          IconButton(tooltip: _touchInk ? 'Dibujar con dedo activado' : 'Activar dibujo con dedo', onPressed: _saving ? null : () => setState(() => _touchInk = !_touchInk), icon: Icon(Icons.touch_app, color: _touchInk ? InkTheme.accent : null)),
          FilledButton.icon(onPressed: _saving ? null : _saveDraft, icon: const Icon(Icons.check), label: Text(_saving ? 'Guardando…' : 'Guardar')),
        ])),
      ) : FloatingActionButton.small(heroTag: 'inkvault-pencil', onPressed: _docReady && _annotationsReady ? _toggleAnnotating : null,
        tooltip: 'Anotar', child: const Icon(Icons.draw_outlined))));
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    unawaited(LibraryService.instance.persist());
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
