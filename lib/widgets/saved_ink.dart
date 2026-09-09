import 'package:flutter/material.dart';
import '../models/models.dart';
class SavedInk extends StatelessWidget {
  const SavedInk({super.key, required this.strokes});
  final List<Stroke> strokes;
  @override
  Widget build(BuildContext context) => IgnorePointer(child: CustomPaint(painter: InkPainter(strokes), child: const SizedBox.expand()));
}
class InkPainter extends CustomPainter {
  InkPainter(this.strokes);
  final List<Stroke> strokes;
  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      final path = Path();
      for (var i = 0; i + 1 < s.points.length; i += 2) {
        final x = s.points[i] * size.width, y = s.points[i + 1] * size.height;
        if (i == 0) { path.moveTo(x, y); } else { path.lineTo(x, y); }
      }
      canvas.drawPath(path, Paint()..color = Color(s.color)..strokeWidth = s.width..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    }
  }
  @override
  bool shouldRepaint(covariant InkPainter oldDelegate) => true;
}
