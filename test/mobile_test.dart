import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkvault_reader/app.dart';

void main() {
  testWidgets('phone library and Obsidian settings fit a 360px screen', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dir = (await tester.runAsync(() => Directory.systemTemp.createTemp('baker-mobile-')))!;
    addTearDown(() => dir.deleteSync(recursive: true));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'), (_) async => dir.path);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('baker_reader/obsidian'), (call) async => call.method == 'settings' ? {'folder':'Lecturas','vault':'Mis notas'} : null);
    final key = GlobalKey();
    await tester.runAsync(() async {
      await tester.pumpWidget(RepaintBoundary(key: key, child: const InkVaultApp()));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(find.text('Baker Reader'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final output = Platform.environment['BAKER_SCREENSHOTS'];
    if (output != null) {
      await tester.runAsync(() async {
        final image = await (key.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$output/library.png').writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.tap(find.byTooltip('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.text('Vincular carpeta de Obsidian'), findsOneWidget);
    expect(find.text('Lecturas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
