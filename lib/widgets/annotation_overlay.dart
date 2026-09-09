import 'package:flutter/material.dart';

import '../models/models.dart';
import 'stylus_recognizer.dart';

enum AnnotationTool { pen, crop }

class StrokeLine {
  final List<Offset> points;
  final Color color;
  final double width;
  const StrokeLine(this.points, this.color, this.width);
}

class AnnotationOverlay extends StatefulWidget {
  const AnnotationOverlay({
    super.key,
    this.touchEnabled = false,
    required this.tool,
    required this.penColor,
    required this.penWidth,
    required this.existingStrokes,
    required this.onPenCommit,
    required this.onCropCommit,
  });

  final bool touchEnabled;
  final AnnotationTool tool;
  final Color penColor;
  final double penWidth;
  final List<Stroke> existingStrokes;
  final void Function(List<double> normalizedPoints) onPenCommit;
  final void Function(List<double> normalizedRect) onCropCommit;

  @override
  State<AnnotationOverlay> createState() => AnnotationOverlayState();
}

class AnnotationOverlayState extends State<AnnotationOverlay> {
  bool captureMode = false;
  void setCaptureMode(bool value) => setState(() => captureMode = value);
  int? _corner;
  Offset? _moveStart;
  Rect? _originalRect;
  Size _size = Size.zero;
  final List<Stroke> _drafts = [];
  List<Stroke> get drafts => List.unmodifiable(_drafts);
  bool get hasDraft => _drafts.isNotEmpty || _cropRect != null;
  List<double>? get crop {
    final r = _cropRect;
    if (r == null || r.width < 8 || r.height < 8 || _size.isEmpty) return null;
    return [r.left / _size.width, r.top / _size.height, r.right / _size.width, r.bottom / _size.height];
  }
  void clear() => setState(() { _drafts.clear(); _active.clear(); _cropStart = null; _cropRect = null; });

  final List<Offset> _active = <Offset>[];
  Offset? _cropStart;
  Rect? _cropRect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _size = size;
        return RawGestureDetector(
          behavior: HitTestBehavior.translucent,
          gestures: <Type, GestureRecognizerFactory>{
            StylusGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<StylusGestureRecognizer>(
              () => StylusGestureRecognizer(debugOwner: this),
              (instance) {
                instance.allowTouch = widget.touchEnabled;
                instance.onStylusDown = (e) {
                  _onDown(e.localPosition);
                };
                instance.onStylusMove = (e) {
                  _onMove(e.localPosition);
                };
                instance.onStylusUp = (e) {
                  _onUp(size);
                };
                instance.onStylusCancel = _onCancel;
              },
            ),
          },
          child: CustomPaint(
            painter: _OverlayPainter(
              existing: [...widget.existingStrokes, ..._drafts],
              active: _active.isEmpty
                  ? null
                  : StrokeLine(_active, widget.penColor, widget.penWidth),
              cropRect: captureMode ? null : _cropRect,
              penColor: widget.penColor,
              showExisting: true,
              size: size,
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }

  void _onDown(Offset local) {
    if (widget.tool == AnnotationTool.pen) {
      _active.add(local);
    } else {
      final rect = _cropRect;
      if (rect != null) {
        final corners = [rect.topLeft, rect.topRight, rect.bottomRight, rect.bottomLeft];
        for (var i = 0; i < corners.length; i++) {
          if ((corners[i] - local).distance < 32) {
            _corner = i;
            _originalRect = rect;
            return;
          }
        }
        if (rect.contains(local)) {
          _moveStart = local;
          _originalRect = rect;
          return;
        }
      }
      _cropStart = local;
      _cropRect = Rect.fromPoints(local, local);
    }
    setState(() {});
  }

  void _onMove(Offset local) {
    if (widget.tool == AnnotationTool.pen) {
      _active.add(local);
    } else if (_corner != null && _originalRect != null) {
      final r = _originalRect!;
      final opposite = [r.bottomRight, r.bottomLeft, r.topLeft, r.topRight][_corner!];
      final clamped = Offset(local.dx.clamp(0.0, _size.width), local.dy.clamp(0.0, _size.height));
      _cropRect = Rect.fromPoints(opposite, clamped);
    } else if (_moveStart != null && _originalRect != null) {
      final r = _originalRect!;
      final delta = local - _moveStart!;
      _cropRect = r.shift(Offset(delta.dx.clamp(-r.left, _size.width-r.right), delta.dy.clamp(-r.top, _size.height-r.bottom)));
    } else if (_cropStart != null) {
      _cropRect = Rect.fromPoints(_cropStart!, local);
    }
    setState(() {});
  }

  void _onUp(Size size) {
    _corner = null;
    _moveStart = null;
    _originalRect = null;
    if (widget.tool == AnnotationTool.pen) {
      if (_active.length >= 2 && size.width > 0 && size.height > 0) {
        final norm = <double>[];
        for (final p in _active) {
          norm
            ..add(((p.dx / size.width).clamp(0.0, 1.0)).toDouble())
            ..add(((p.dy / size.height).clamp(0.0, 1.0)).toDouble());
        }
        _drafts.add(Stroke(points: norm, width: widget.penWidth, color: widget.penColor.toARGB32()));
      }
      _active.clear();
    } else {
      final rect = _cropRect;
      if (rect != null &&
          rect.width >= 8 &&
          rect.height >= 8 &&
          size.width > 0 &&
          size.height > 0) {
        final l = ((rect.left / size.width).clamp(0.0, 1.0)).toDouble();
        final t = ((rect.top / size.height).clamp(0.0, 1.0)).toDouble();
        final r = ((rect.right / size.width).clamp(0.0, 1.0)).toDouble();
        final b = ((rect.bottom / size.height).clamp(0.0, 1.0)).toDouble();
        _cropRect = Rect.fromLTRB(l * size.width, t * size.height, r * size.width, b * size.height);
      }
      _cropStart = null;
    }
    setState(() {});
  }

  void _onCancel() {
    _corner = null;
    _moveStart = null;
    _originalRect = null;
    _active.clear();
    _cropStart = null;
    _cropRect = null;
    setState(() {});
  }
}

class _OverlayPainter extends CustomPainter {
  _OverlayPainter({
    required this.existing,
    required this.active,
    required this.cropRect,
    required this.penColor,
    required this.showExisting,
    required this.size,
  });

  final List<Stroke> existing;
  final StrokeLine? active;
  final Rect? cropRect;
  final Color penColor;
  final bool showExisting;
  final Size size;

  Path _pathFrom(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final cur = points[i];
      final mid = Offset((prev.dx + cur.dx) / 2, (prev.dy + cur.dy) / 2);
      path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size canvasSize) {
    if (showExisting && size.width > 0 && size.height > 0) {
      for (final stroke in existing) {
        final pts = <Offset>[];
        for (var i = 0; i + 1 < stroke.points.length; i += 2) {
          pts.add(Offset(
            stroke.points[i] * size.width,
            stroke.points[i + 1] * size.height,
          ));
        }
        final paint = Paint()
          ..color = Color(stroke.color).withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = stroke.width;
        canvas.drawPath(_pathFrom(pts), paint);
      }
    }

    final act = active;
    if (act != null && act.points.length >= 2) {
      final paint = Paint()
        ..color = act.color.withValues(alpha: 0.92)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = act.width;
      canvas.drawPath(_pathFrom(act.points), paint);
    }

    final rect = cropRect;
    if (rect != null) {
      final dim = Paint()..color = Colors.black.withValues(alpha: 0.45);
      canvas.drawRect(
        Rect.fromLTRB(
            0,
            0,
            canvasSize.width,
            (rect.top.clamp(0.0, canvasSize.height)).toDouble()),
        dim,
      );
      canvas.drawRect(
        Rect.fromLTRB(0, rect.bottom, canvasSize.width, canvasSize.height),
        dim,
      );
      canvas.drawRect(Rect.fromLTRB(0, rect.top, rect.left, rect.bottom), dim);
      canvas.drawRect(Rect.fromLTRB(rect.right, rect.top, canvasSize.width, rect.bottom), dim);

      final border = Paint()
        ..color = penColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRect(rect, border);
      final corner = Paint()
        ..color = penColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      const len = 14.0;
      canvas.drawPath(
        Path()
          ..moveTo(rect.left, rect.top + len)
          ..lineTo(rect.left, rect.top)
          ..lineTo(rect.left + len, rect.top)
          ..moveTo(rect.right - len, rect.top)
          ..lineTo(rect.right, rect.top)
          ..lineTo(rect.right, rect.top + len)
          ..moveTo(rect.right, rect.bottom - len)
          ..lineTo(rect.right, rect.bottom)
          ..lineTo(rect.right - len, rect.bottom)
          ..moveTo(rect.left + len, rect.bottom)
          ..lineTo(rect.left, rect.bottom)
          ..lineTo(rect.left, rect.bottom - len),
        corner,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) =>
      oldDelegate.active != active ||
      oldDelegate.cropRect != cropRect ||
      oldDelegate.existing != existing ||
      oldDelegate.size != size ||
      oldDelegate.showExisting != showExisting;
}
