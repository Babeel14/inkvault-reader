import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../theme.dart';

class PdfReaderWidget extends StatelessWidget {
  const PdfReaderWidget({
    super.key,
    required this.controller,
    required this.onDocumentReady,
    this.onPageChanged,
  });

  final PdfController controller;
  final VoidCallback onDocumentReady;

  /// Página actual, base 0.
  final void Function(int page)? onPageChanged;

  @override
  Widget build(BuildContext context) {
    return PdfViewPinch(
      controller: controller,
      onPageChanged: (page) => onPageChanged?.call(page - 1),
      onDocumentLoaded: (_) => onDocumentReady(),
      onDocumentError: (error) => _ErrorView(error: error.toString()),
      builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        documentLoaderBuilder: (_) =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        pageLoaderBuilder: (_) =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorBuilder: (_, error) => _ErrorView(error: error.toString()),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: InkTheme.danger, size: 36),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}
