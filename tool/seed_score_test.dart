import 'package:flutter_test/flutter_test.dart';

import 'seed_score.dart';

void main() {
  test('种入小星星到真实 App 数据库', () async {
    final msg = await seed();
    // ignore: avoid_print
    print(msg);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
