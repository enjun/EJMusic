import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:ejmusic/core/util/phash.dart';

img.Image _solid(int w, int h, [int r = 255, int g = 255, int b = 255]) =>
    img.Image(width: w, height: h)..clear(img.ColorRgb8(r, g, b));

void main() {
  group('computePHash', () {
    test('输出为 16 位十六进制', () {
      final hash = computePHash(_solid(100, 100));
      expect(hash.length, 16);
      expect(int.parse(hash, radix: 16), isNonNegative);
    });

    test('相同图像哈希一致', () {
      final a = computePHash(_solid(120, 90, 10, 20, 30));
      final b = computePHash(_solid(120, 90, 10, 20, 30));
      expect(a, b);
    });

    test('纯色图缩放后哈希稳定（对尺寸不敏感）', () {
      final a = computePHash(_solid(200, 200, 200, 200, 200));
      final b = computePHash(_solid(400, 400, 200, 200, 200));
      expect(hammingDistance(a, b), lessThanOrEqualTo(4));
    });
  });

  group('hammingDistance', () {
    test('相同哈希距离为 0', () {
      expect(hammingDistance('0123456789abcdef', '0123456789abcdef'), 0);
    });

    test('已知距离计算正确', () {
      expect(hammingDistance('0000000000000000', 'ffffffffffffffff'), 64);
      expect(hammingDistance('0000000000000000', '0000000000000001'), 1);
      expect(hammingDistance('0000000000000003', '0000000000000001'), 1);
      expect(hammingDistance('00000000000000ff', '0000000000000000'), 8);
    });
  });
}
