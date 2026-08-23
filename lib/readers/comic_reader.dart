import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class ComicReaderWidget extends StatelessWidget {
  const ComicReaderWidget({
    super.key,
    required this.pages,
    required this.controller,
    this.onPageChanged,
  });

  final List<String> pages;
  final PageController controller;

  /// Índice actual, base 0.
  final void Function(int index)? onPageChanged;

  @override
  Widget build(BuildContext context) {
    return PhotoViewGallery.builder(
      itemCount: pages.length,
      pageController: controller,
      onPageChanged: (index) => onPageChanged?.call(index),
      backgroundDecoration: const BoxDecoration(color: Colors.black),
      builder: (context, index) {
        return PhotoViewGalleryPageOptions(
          imageProvider: FileImage(File(pages[index])),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.contained * 4,
          initialScale: PhotoViewComputedScale.contained,
          filterQuality: FilterQuality.medium,
        );
      },
    );
  }
}
