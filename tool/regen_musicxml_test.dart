import 'package:flutter_test/flutter_test.dart';

import 'regen_musicxml.dart';

void main() {
  test('重新生成 musicxml 缓存', () async {
    final msg = await regenAll();
    // ignore: avoid_print
    print(msg);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
