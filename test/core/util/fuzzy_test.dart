import 'package:flutter_test/flutter_test.dart';
import 'package:ejmusic/core/util/fuzzy.dart';

void main() {
  group('normalizeTitle', () {
    test('小写化并去除空白与标点', () {
      expect(normalizeTitle('Canon in D Major'), 'canonindmajor');
      expect(normalizeTitle('童话 - 光良'), '童话光良');
    });

    test('全角转半角', () {
      expect(normalizeTitle('ＡＢＣ　ｄｅｆ'), 'abcdef');
      expect(normalizeTitle('梦中的婚礼（完整版）'), '梦中的婚礼完整版');
    });

    test('CJK 标点与破折号', () {
      expect(normalizeTitle('夜的钢琴曲五——石进'), '夜的钢琴曲五石进');
      expect(normalizeTitle('《卡农》·帕赫贝尔'), '卡农帕赫贝尔');
    });
  });

  group('levenshtein / similarityRatio', () {
    test('基础编辑距离', () {
      expect(levenshtein('', ''), 0);
      expect(levenshtein('abc', 'abc'), 0);
      expect(levenshtein('abc', 'abd'), 1);
      expect(levenshtein('kitten', 'sitting'), 3);
    });

    test('相似度比率边界', () {
      expect(similarityRatio('', ''), 1.0);
      expect(similarityRatio('abc', 'abc'), 1.0);
      expect(similarityRatio('abc', 'xyz'), 0.0);
    });

    test('曲名近似判断', () {
      expect(similarityRatio(normalizeTitle('童话'), normalizeTitle('童话')), 1.0);
      // 同一首曲子（去掉标点差异后）应完全一致
      expect(
        similarityRatio(normalizeTitle('Canon in D'), normalizeTitle('canon-in-d')),
        1.0,
      );
      // 同曲不同版本后缀仍有较高相似度
      expect(
        similarityRatio(normalizeTitle('天空之城'), normalizeTitle('天空之城 钢琴谱')),
        greaterThan(0.5),
      );
      // 完全不同的曲子应低于阈值
      expect(
        similarityRatio(normalizeTitle('童话'), normalizeTitle('天空之城')),
        lessThan(0.5),
      );
    });
  });
}
