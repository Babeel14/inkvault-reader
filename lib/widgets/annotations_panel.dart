import 'dart:io';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';

class AnnotationsPanel extends StatelessWidget {
  const AnnotationsPanel({
    super.key,
    required this.annotations,
    required this.onTapItem,
    required this.onDelete,
    required this.onEditNote,
    required this.onClose,
  });

  final List<Annotation> annotations;
  final void Function(Annotation annotation) onTapItem;
  final void Function(Annotation annotation) onDelete;
  final void Function(Annotation annotation) onEditNote;
  final VoidCallback onClose;

  String _label(Annotation a) {
    final kind = a.isCrop ? 'Recorte' : 'Dibujo';
    final where = a.pageIndex >= 0 ? 'pág ${a.pageIndex + 1}' : 'ePub';
    return '$kind · $where';
  }

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: InkTheme.surface,
      elevation: 8,
      child: SafeArea(
        left: false,
        child: Container(
          width: 360,
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: InkTheme.outline)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                child: Row(
                  children: [
                    const Icon(Icons.format_list_bulleted,
                        size: 20, color: InkTheme.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Anotaciones (${annotations.length})',
                        style: const TextStyle(
                          color: InkTheme.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      color: InkTheme.inkDim,
                      onPressed: onClose,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: annotations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.gesture,
                                size: 42, color: Colors.white.withValues(alpha: 0.18)),
                            const SizedBox(height: 10),
                            Text(
                              'Sin anotaciones aún.\nActiva el modo lápiz para empezar.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.35),
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: annotations.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 84),
                        itemBuilder: (context, i) {
                          final a = annotations[i];
                          return _item(context, a);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, Annotation a) {
    final image = a.imagePath;
    return InkWell(
      onTap: () => onTapItem(a),
      onLongPress: () => onEditNote(a),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 58,
              height: 76,
              decoration: BoxDecoration(
                color: InkTheme.surfaceHigh,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: InkTheme.outline),
              ),
              clipBehavior: Clip.antiAlias,
              child: image != null
                  ? Image.file(File(image), fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image_outlined,
                            size: 22, color: InkTheme.inkDim),
                      ))
                  : const Center(
                      child: Icon(Icons.gesture, size: 22, color: InkTheme.accent),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _label(a),
                    style: const TextStyle(
                      color: InkTheme.accent,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    a.note.isEmpty ? '(sin nota)' : a.note,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: a.note.isEmpty
                          ? Colors.white.withValues(alpha: 0.28)
                          : InkTheme.ink.withValues(alpha: 0.92),
                      fontSize: 13,
                      height: 1.35,
                      fontStyle:
                          a.note.isEmpty ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Text(
                        _date(a.createdAt),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.32),
                          fontSize: 11,
                        ),
                      ),
                      if (a.note.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.sticky_note_2_outlined,
                            size: 12, color: Colors.white.withValues(alpha: 0.32)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            _ItemMenu(
              onDelete: () => onDelete(a),
              onEditNote: () => onEditNote(a),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemMenu extends StatelessWidget {
  const _ItemMenu({required this.onDelete, required this.onEditNote});

  final VoidCallback onDelete;
  final VoidCallback onEditNote;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert,
          size: 18, color: Colors.white.withValues(alpha: 0.4)),
      onSelected: (v) {
        if (v == 'note') onEditNote();
        if (v == 'delete') onDelete();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'note', child: Text('Editar nota')),
        PopupMenuItem(value: 'delete', child: Text('Eliminar')),
      ],
    );
  }
}
