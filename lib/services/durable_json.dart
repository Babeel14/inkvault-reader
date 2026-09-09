import 'dart:io';

/// Serializes writes and keeps the previous valid file as a recovery copy.
class DurableJson {
  static final Map<String, Future<void>> _queues = {};
  static Future<void> write(String path, String contents) {
    final previous = _queues[path] ?? Future<void>.value();
    final next = previous.then((_) async {
      final file = File(path);
      await file.parent.create(recursive: true);
      final temporary = File('$path.tmp');
      await temporary.writeAsString(contents, flush: true);
      if (await file.exists()) await file.copy('$path.bak');
      await temporary.rename(path);
    });
    _queues[path] = next.catchError((Object _) {});
    return next;
  }
  static Future<void> flush(String path) async { await _queues[path]; }
}
