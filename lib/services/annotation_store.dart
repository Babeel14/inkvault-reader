import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/models.dart';
import 'id_gen.dart';

class AnnotationStore {
  AnnotationStore._();
  static final AnnotationStore instance = AnnotationStore._();

  String? _rootPath;

  Future<String> _annotationsDir() async {
    if (_rootPath == null) {
      final docs = await getApplicationDocumentsDirectory();
      _rootPath = '${docs.path}/inkvault';
    }
    final p = '${_rootPath!}/annotations';
    await Directory(p).create(recursive: true);
    return p;
  }

  Future<String> saveCropImage(String bookId, List<int> pngBytes) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/inkvault/crops/$bookId');
    await dir.create(recursive: true);
    final path = '${dir.path}/${generateId()}.png';
    await File(path).writeAsBytes(pngBytes, flush: true);
    return path;
  }

  Future<List<Annotation>> load(String bookId) async {
    try {
      final dir = await _annotationsDir();
      final f = File('$dir/$bookId.json');
      if (!await f.exists()) return [];
      final raw = await f.readAsString();
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Annotation.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(String bookId, List<Annotation> annotations) async {
    final dir = await _annotationsDir();
    final f = File('$dir/$bookId.json');
    await f.writeAsString(
      jsonEncode(annotations.map((a) => a.toJson()).toList()),
      flush: true,
    );
  }

  Future<void> deleteImageOf(Annotation annotation) async {
    final path = annotation.imagePath;
    if (path == null) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
