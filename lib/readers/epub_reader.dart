import 'dart:io';
import 'dart:async';

import 'package:epub_view/epub_view.dart' as epub_view;
import 'package:flutter/material.dart';

import '../widgets/stylus_recognizer.dart';

class EpubReaderWidget extends StatefulWidget {
  const EpubReaderWidget({
    super.key,
    required this.filePath,
    required this.initialCfi,
    required this.onProgressRatio,
    required this.onDocumentReady,
    required this.onDocumentError,
  });

  final String filePath;
  final String initialCfi;

  /// Progreso de scroll entre 0 y 1.
  final void Function(double ratio) onProgressRatio;
  final VoidCallback onDocumentReady;
  final void Function(String message) onDocumentError;

  @override
  State<EpubReaderWidget> createState() => EpubReaderWidgetState();
}

class EpubReaderWidgetState extends State<EpubReaderWidget> {
  epub_view.EpubController? _controller;
  double _lastRatio = -1;
  Timer? _ratioDebounce;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      final book = await epub_view.EpubDocument.openFile(File(widget.filePath));
      if (!mounted) return;
      final controller = epub_view.EpubController(
        document: Future.value(book),
        epubCfi: widget.initialCfi.isEmpty ? null : widget.initialCfi,
      );
      setState(() => _controller = controller);
    } catch (e) {
      widget.onDocumentError(e.toString());
    }
  }

  void jumpToAnchor(String cfi) {
    if (cfi.isNotEmpty) {
      _controller?.gotoEpubCfi(cfi);
    }
  }

  String? currentAnchor() => _controller?.generateEpubCfi();

  bool _onScroll(ScrollNotification n) {
    final m = n.metrics;
    final total = m.extentBefore + m.viewportDimension + m.extentAfter;
    if (total <= 0) return false;
    final ratio = m.extentBefore / total;
    if ((ratio - _lastRatio).abs() > 0.004) {
      _lastRatio = ratio;
      widget.onProgressRatio(ratio);
      _ratioDebounce?.cancel();
      _ratioDebounce = Timer(const Duration(milliseconds: 700), () {
        widget.onProgressRatio(ratio);
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: ScrollConfiguration(
        behavior: const ReaderScrollBehavior(),
        child: epub_view.EpubView(
          controller: controller,
          onDocumentLoaded: (_) => widget.onDocumentReady(),
          onDocumentError: (error) =>
              widget.onDocumentError(error.toString()),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ratioDebounce?.cancel();
    try {
      _controller?.dispose();
    } catch (_) {}
    super.dispose();
  }
}
