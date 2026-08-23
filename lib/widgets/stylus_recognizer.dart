import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class StylusGestureRecognizer extends OneSequenceGestureRecognizer {
  StylusGestureRecognizer({required Object debugOwner})
      : super(debugOwner: debugOwner);

  void Function(PointerDownEvent event)? onStylusDown;
  void Function(PointerMoveEvent event)? onStylusMove;
  void Function(PointerUpEvent event)? onStylusUp;
  void Function()? onStylusCancel;

  int? _primary;

  @override
  bool isPointerAllowed(PointerEvent event) {
    if (event is! PointerDownEvent) return false;
    if (event.kind != PointerDeviceKind.stylus) return false;
    return super.isPointerAllowed(event);
  }

  @override
  void addPointer(PointerDownEvent event) {
    _primary = event.pointer;
    startTrackingPointer(event.pointer, event.transform);
    resolve(GestureDisposition.accepted);
    onStylusDown?.call(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _primary) return;
    if (event is PointerMoveEvent) {
      onStylusMove?.call(event);
    } else if (event is PointerUpEvent) {
      onStylusUp?.call(event);
      _finish();
    } else if (event is PointerCancelEvent) {
      onStylusCancel?.call();
      _finish();
    }
  }

  void _finish() {
    final p = _primary;
    if (p != null) stopTrackingPointer(p);
    _primary = null;
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  void dispose() {
    _primary = null;
    super.dispose();
  }

  @override
  String get debugDescription => 'stylus';
}

class ReaderScrollBehavior extends MaterialScrollBehavior {
  const ReaderScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const <PointerDeviceKind>{
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}
