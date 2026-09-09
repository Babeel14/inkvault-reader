import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkvault_reader/models/models.dart';
import 'package:inkvault_reader/services/annotation_store.dart';
import 'package:inkvault_reader/services/durable_json.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  setUpAll(() async {
    temporary = await Directory.systemTemp.createTemp('baker-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'), (_) async => temporary.path);
  });
  tearDownAll(() async => temporary.delete(recursive: true));
  test('saved annotations survive reload and corrupted primary recovers backup', () async {
    final annotation = Annotation(id: 'note1', kind: AnnotationKind.draw,
      createdAt: DateTime(2026), strokes: [Stroke(points: [.1,.2,.3,.4], width: 2, color: 0xffffaa00)],
      pageIndex: 2, note: 'Persistente');
    await AnnotationStore.instance.save('book1', [annotation]);
    final loaded = await AnnotationStore.instance.load('book1');
    expect(loaded.single.note, 'Persistente');
    expect(loaded.single.strokes.single.points, [.1,.2,.3,.4]);
    await AnnotationStore.instance.save('book1', [annotation]);
    await File('${temporary.path}/inkvault/annotations/book1.json').writeAsString('{broken');
    expect((await AnnotationStore.instance.load('book1')).single.note, 'Persistente');
  });
  test('concurrent writes finish with complete latest content', () async {
    final path = '${temporary.path}/ordered.json';
    await Future.wait(List.generate(20, (i) => DurableJson.write(path, jsonEncode({'revision':i}))));
    expect(jsonDecode(await File(path).readAsString())['revision'], 19);
  });
}
