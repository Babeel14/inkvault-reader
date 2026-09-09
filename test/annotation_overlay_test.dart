import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkvault_reader/widgets/annotation_overlay.dart';

void main() {
  testWidgets('crop remains editable after lifting finger and cancel clears it', (tester) async {
    final key = GlobalKey<AnnotationOverlayState>();
    var committed = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 400, height: 600,
      child: AnnotationOverlay(key: key, touchEnabled: true, tool: AnnotationTool.crop,
        penColor: Colors.amber, penWidth: 3, existingStrokes: const [],
        onPenCommit: (_) => committed = true, onCropCommit: (_) => committed = true)))));
    await tester.dragFrom(const Offset(60, 80), const Offset(160, 180));
    await tester.pump();
    expect(committed, isFalse);
    final first = key.currentState!.crop!;
    expect(first[0], closeTo(.15, .01));
    await tester.dragFrom(const Offset(220, 260), const Offset(40, 40));
    await tester.pump();
    expect(key.currentState!.crop![2], greaterThan(first[2]));
    key.currentState!.clear();
    await tester.pump();
    expect(key.currentState!.hasDraft, isFalse);
  });
  testWidgets('multiple pen strokes form one draft without opening a note', (tester) async {
    final key = GlobalKey<AnnotationOverlayState>();
    var callbacks = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AnnotationOverlay(
      key: key, touchEnabled: true, tool: AnnotationTool.pen, penColor: Colors.amber,
      penWidth: 3, existingStrokes: const [], onPenCommit: (_) => callbacks++, onCropCommit: (_) => callbacks++))));
    await tester.dragFrom(const Offset(40, 50), const Offset(100, 50));
    await tester.dragFrom(const Offset(40, 150), const Offset(100, 50));
    expect(key.currentState!.drafts.length, 2);
    expect(callbacks, 0);
  });
}
