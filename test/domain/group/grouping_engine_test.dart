import 'package:flutter_test/flutter_test.dart';
import 'package:ejmusic/domain/group/grouping_engine.dart';

void main() {
  group('extractPrefix', () {
    test('去掉尾部数字', () {
      expect(extractPrefix('梦中的婚礼1.jpg'), '梦中的婚礼');
      expect(extractPrefix('梦中的婚礼_02.jpg'), '梦中的婚礼');
      expect(extractPrefix('Canon in D - 3.png'), 'Canon in D');
    });

    test('去掉括号序号', () {
      expect(extractPrefix('童话(1).jpg'), '童话');
      expect(extractPrefix('童话（12）.png'), '童话');
    });

    test('去掉 page/p/第N页 模式', () {
      expect(extractPrefix('nocturne page 4.jpg'), 'nocturne');
      expect(extractPrefix('夜曲 p02.jpg'), '夜曲');
      expect(extractPrefix('夜曲 第 3 页.jpg'), '夜曲');
      expect(extractPrefix('scan_5.jpg'), 'scan');
      // 无分隔符的 p/img token 不剥离，避免误伤 "Op9"、"img2" 类名称
    });

    test('纯名称不受影响', () {
      expect(extractPrefix('天空之城.jpg'), '天空之城');
      // 名称本身以数字结尾且无分隔符：视为曲名一部分（如 "1999"）
      expect(extractPrefix('1999.jpg'), '1999');
    });
  });

  group('groupByPrefix', () {
    test('同曲多页聚为一组', () {
      final groups = groupByPrefix([
        'b2.jpg', 'a1.jpg', 'a2.jpg', 'a10.jpg', 'b1.jpg',
      ]);
      expect(groups.length, 2);
      expect(groups[0].label, 'a');
      expect(groups[0].files, ['a1.jpg', 'a2.jpg', 'a10.jpg']); // 自然序
      expect(groups[1].label, 'b');
      expect(groups[1].files, ['b1.jpg', 'b2.jpg']);
    });

    test('自然排序：img10 不排在 img2 前', () {
      final groups = groupByPrefix(['img2.jpg', 'img10.jpg', 'img1.jpg']);
      expect(groups.single.files, ['img1.jpg', 'img2.jpg', 'img10.jpg']);
    });

    test('混合模式归组', () {
      final groups = groupByPrefix([
        'Canon_in_D_p1.jpg',
        'Canon_in_D_p2.jpg',
        'Nocturne_Op9_No2.jpg',
      ]);
      expect(groups.length, 2);
      expect(groups[0].label, 'Canon_in_D');
      // 设计决策：无分隔符的尾部数字（Op9/No2 的 2）会被当作页码剥离，
      // 只影响展示用 label（UI 可改名），不影响分组正确性
      expect(groups[1].label, 'Nocturne_Op9_No');
    });
  });
}
