import 'dart:io';
import 'dart:isolate';

import 'package:image/image.dart' as img;

import '../../../core/util/phash.dart';

const _imageExtensions = {'.jpg', '.jpeg', '.png', '.webp', '.bmp', '.tif', '.tiff'};

/// 扫描目录下的图片文件（顶层，自然排序）。
Future<List<FileMeta>> scanImageDirectory(String dirPath) async {
  final dir = Directory(dirPath);
  if (!await dir.exists()) return [];
  final files = <FileMeta>[];
  await for (final entity in dir.list()) {
    if (entity is! File) continue;
    final ext = entity.path.toLowerCase().split('.').last;
    if (!_imageExtensions.contains('.$ext')) continue;
    final stat = await entity.stat();
    files.add(FileMeta(
      fileName: entity.path.split(Platform.pathSeparator).last,
      absPath: entity.path,
      bytes: stat.size,
      mtimeMs: stat.modified.millisecondsSinceEpoch,
    ));
  }
  return files;
}

/// 在 isolate 中计算单张图片的 pHash（解码失败返回 null）。
Future<String?> computeImagePHash(String absPath) {
  return Isolate.run(() async {
    try {
      final bytes = await File(absPath).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      return computePHash(decoded);
    } catch (_) {
      return null;
    }
  });
}

class FileMeta {
  FileMeta({
    required this.fileName,
    required this.absPath,
    required this.bytes,
    required this.mtimeMs,
    this.phash,
  });

  final String fileName;
  final String absPath;
  final int bytes;
  final int mtimeMs;
  String? phash;
}
