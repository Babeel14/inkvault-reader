enum BookFormat { pdf, epub, comic }

BookFormat bookFormatFromExtension(String ext) {
  switch (ext.toLowerCase()) {
    case 'pdf':
      return BookFormat.pdf;
    case 'epub':
      return BookFormat.epub;
    case 'cbz':
    case 'cbr':
      return BookFormat.comic;
    default:
      throw ArgumentError('Extensión no soportada: $ext');
  }
}

String bookFormatLabel(BookFormat f) {
  switch (f) {
    case BookFormat.pdf:
      return 'pdf';
    case BookFormat.epub:
      return 'epub';
    case BookFormat.comic:
      return 'cómic';
  }
}

class Book {
  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.format,
    required this.filePath,
    required this.addedAt,
    this.coverPath,
    this.pageCount = 0,
    this.lastPosition = '',
  });

  String id;
  String title;
  String author;
  BookFormat format;
  String filePath;
  String? coverPath;
  DateTime addedAt;
  int pageCount;
  String lastPosition;

  int? get lastPageNumber {
    if (lastPosition.startsWith('n:')) {
      return int.tryParse(lastPosition.substring(2));
    }
    return null;
  }

  String get lastCfi =>
      lastPosition.startsWith('c:') ? lastPosition.substring(2) : '';

  double get lastRatio {
    if (lastPosition.startsWith('r:')) {
      return double.tryParse(lastPosition.substring(2)) ?? 0;
    }
    return 0;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'author': author,
        'format': format.name,
        'filePath': filePath,
        'coverPath': coverPath,
        'addedAt': addedAt.toIso8601String(),
        'pageCount': pageCount,
        'lastPosition': lastPosition,
      };

  factory Book.fromJson(Map<String, dynamic> json) => Book(
        id: json['id'] as String,
        title: json['title'] as String? ?? 'Sin título',
        author: json['author'] as String? ?? '',
        format: BookFormat.values.firstWhere(
          (f) => f.name == (json['format'] as String?),
          orElse: () => BookFormat.pdf,
        ),
        filePath: json['filePath'] as String,
        addedAt:
            DateTime.tryParse(json['addedAt'] as String? ?? '') ??
                DateTime.now(),
        coverPath: json['coverPath'] as String?,
        pageCount: json['pageCount'] as int? ?? 0,
        lastPosition: json['lastPosition'] as String? ?? '',
      );
}

enum AnnotationKind { draw, crop }

AnnotationKind annotationKindFromString(String s) => s == 'crop'
    ? AnnotationKind.crop
    : AnnotationKind.draw;

class Stroke {
  Stroke({required this.points, required this.width, required this.color});

  final List<double> points;
  final double width;
  final int color;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'points': points,
        'width': width,
        'color': color,
      };

  factory Stroke.fromJson(Map<String, dynamic> json) => Stroke(
        points: (json['points'] as List<dynamic>)
            .map((e) => (e as num).toDouble())
            .toList(),
        width: (json['width'] as num).toDouble(),
        color: json['color'] as int,
      );
}

class Annotation {
  Annotation({
    required this.id,
    required this.kind,
    required this.createdAt,
    required this.strokes,
    this.pageIndex = -1,
    this.positionRatio = -1,
    this.anchor = '',
    this.rectLeft = 0,
    this.rectTop = 0,
    this.rectRight = 0,
    this.rectBottom = 0,
    this.imagePath,
    this.note = '',
  });

  String id;
  AnnotationKind kind;
  int pageIndex;
  double positionRatio;
  String anchor;
  List<Stroke> strokes;
  double rectLeft, rectTop, rectRight, rectBottom;
  String? imagePath;
  String note;
  DateTime createdAt;

  bool get isCrop => kind == AnnotationKind.crop;

  String get normalizedRectLabel =>
      '(${rectLeft.toStringAsFixed(2)}, ${rectTop.toStringAsFixed(2)})';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'kind': kind.name,
        'pageIndex': pageIndex,
        'positionRatio': positionRatio,
        'anchor': anchor,
        'strokes': strokes.map((s) => s.toJson()).toList(),
        'rect': [rectLeft, rectTop, rectRight, rectBottom],
        'imagePath': imagePath,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Annotation.fromJson(Map<String, dynamic> json) {
    final rect =
        (json['rect'] as List<dynamic>? ?? const []).map((e) => (e as num).toDouble()).toList();
    return Annotation(
      id: json['id'] as String,
      kind: annotationKindFromString(json['kind'] as String? ?? 'draw'),
      pageIndex: json['pageIndex'] as int? ?? -1,
      positionRatio: (json['positionRatio'] as num?)?.toDouble() ?? -1,
      anchor: json['anchor'] as String? ?? '',
      strokes: (json['strokes'] as List<dynamic>? ?? const [])
          .map((s) => Stroke.fromJson(s as Map<String, dynamic>))
          .toList(),
      rectLeft: rect.isNotEmpty ? rect[0] : 0,
      rectTop: rect.length > 1 ? rect[1] : 0,
      rectRight: rect.length > 2 ? rect[2] : 0,
      rectBottom: rect.length > 3 ? rect[3] : 0,
      imagePath: json['imagePath'] as String?,
      note: json['note'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
              DateTime.now(),
    );
  }
}
