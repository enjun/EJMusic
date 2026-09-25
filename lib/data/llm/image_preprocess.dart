import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 图片预处理：长边 ≤2000px、JPEG q80（控制 token 与上传体积）。
class ImagePreprocess {
  static const maxSide = 2000;
  static const jpegQuality = 80;

  /// 返回压缩后的 JPEG 字节。解码失败抛异常。
  static Uint8List compress(Uint8List raw) {
    final decoded = img.decodeImage(raw);
    if (decoded == null) {
      throw FormatException('无法解码图片');
    }
    var image = decoded;
    final longSide = image.width > image.height ? image.width : image.height;
    if (longSide > maxSide) {
      final ratio = maxSide / longSide;
      image = img.copyResize(
        image,
        width: (image.width * ratio).round(),
        height: (image.height * ratio).round(),
        interpolation: img.Interpolation.average,
      );
    }
    return Uint8List.fromList(img.encodeJpg(image, quality: jpegQuality));
  }

  /// data URL 形式（OpenAI vision 协议）。
  static String toDataUrl(Uint8List jpeg) =>
      'data:image/jpeg;base64,${base64Encode(jpeg)}';
}
