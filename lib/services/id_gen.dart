import 'dart:math';

String generateId() {
  final ms = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final rnd = Random().nextInt(0xFFFFF).toRadixString(36).padLeft(4, '0');
  return '$ms$rnd';
}

const _hexDigits = '0123456789abcdef';

String shortHash(String seed) {
  var h = 0x811c9dc5;
  for (final code in seed.codeUnits) {
    h ^= code;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h.toRadixString(16).padLeft(8, _hexDigits[0]).substring(0, 6);
}
