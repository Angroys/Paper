import 'dart:io';

import 'package:path/path.dart' as p;

/// Where downloaded PDFs and figure crops live on disk:
/// `<app support>/pdfs/<paperId>.pdf`, `<app support>/figures/<id>.png`.
class FileStore {
  FileStore(this._baseDir);

  /// Resolves the root dir (app support dir in the app, a temp dir in tests).
  final Future<Directory> Function() _baseDir;

  Future<Directory> _dir(String name) async {
    final dir = Directory(p.join((await _baseDir()).path, name));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  Future<String> pdfPath(String paperId) async =>
      p.join((await _dir('pdfs')).path, '$paperId.pdf');

  Future<String> figurePath(String figureId) async =>
      p.join((await _dir('figures')).path, '$figureId.png');

  /// Whether a file exists at [path].
  Future<bool> exists(String path) => File(path).exists();

  /// Deletes [path] if it exists; never throws.
  Future<void> deleteQuietly(String? path) async {
    if (path == null) return;
    try {
      final f = File(path);
      if (f.existsSync()) await f.delete();
    } on FileSystemException {
      // Best effort.
    }
  }

  /// Removes every cached file (sign-out / account switch).
  Future<void> clear() async {
    for (final name in ['pdfs', 'figures']) {
      final dir = Directory(p.join((await _baseDir()).path, name));
      if (dir.existsSync()) await dir.delete(recursive: true);
    }
  }
}
