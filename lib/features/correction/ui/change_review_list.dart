import 'package:flutter/material.dart';

import '../../../domain/score/correct/score_diff.dart';

/// 改动类型中文标签。
String changeKindLabel(ScoreChangeKind kind) => switch (kind) {
      ScoreChangeKind.modifyAttributes => '属性修改',
      ScoreChangeKind.modifyEvent => '修改',
      ScoreChangeKind.rewriteVoice => '声部重写',
      ScoreChangeKind.addVoice => '新增声部',
      ScoreChangeKind.removeVoice => '删除声部',
    };

/// 改动确认清单：详情页纠错页与编辑器 bottom sheet 共用。
/// 按小节聚合展示（盲识别差异量大，事件级平铺无法人工把关）：
/// 每个小节一个可展开分组，组勾选框一键采纳/跳过整小节改动。
/// [onToggle] 为 null 时只读展示。
class ChangeReviewList extends StatelessWidget {
  const ChangeReviewList({
    super.key,
    required this.changes,
    this.warnings = const [],
    this.onToggle,
    this.onSetAll,
  });

  final List<ScoreChange> changes;
  final List<String> warnings;
  final ValueChanged<int>? onToggle;
  final ValueChanged<bool>? onSetAll;

  @override
  Widget build(BuildContext context) {
    final selectedCount = changes.where((c) => c.selected).length;
    // 按小节聚合（保持出现顺序）
    final groups = <int, List<int>>{};
    for (var i = 0; i < changes.length; i++) {
      groups.putIfAbsent(changes[i].measureIndex, () => []).add(i);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (warnings.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              '注意：${warnings.length} 条告警',
              style: TextStyle(
                  fontSize: 12, color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (warnings.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              warnings.join('\n'),
              style: TextStyle(
                  fontSize: 12, color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (onSetAll != null && changes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => onSetAll!(true),
                  child: const Text('全选'),
                ),
                TextButton(
                  onPressed: () => onSetAll!(false),
                  child: const Text('全不选'),
                ),
                const Spacer(),
                Text('已选 $selectedCount / ${changes.length} 处',
                    style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        Expanded(
          child: changes.isEmpty
              ? const Center(child: Text('没有发现需要修改的地方'))
              : ListView.builder(
                  itemCount: groups.length,
                  itemBuilder: (context, gi) {
                    final measureIndex = groups.keys.elementAt(gi);
                    final indices = groups[measureIndex]!;
                    final first = changes[indices.first];
                    final allSelected = indices.every(
                        (i) => changes[i].selected);
                    final summary = indices
                        .map((i) => changes[i])
                        .map((c) =>
                            '${c.before.isEmpty ? '' : '${c.before} → '}${c.after.isEmpty ? c.before : c.after}')
                        .join('；');
                    return ExpansionTile(
                      initiallyExpanded: indices.length <= 3,
                      childrenPadding:
                          const EdgeInsets.symmetric(horizontal: 8),
                      title: Text('第 ${first.measureNumber} 小节'
                          '（${indices.length} 处）',
                          style: const TextStyle(fontSize: 14)),
                      subtitle: Text(summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).hintColor)),
                      leading: onToggle == null
                          ? null
                          : Checkbox(
                              value: allSelected,
                              onChanged: (_) {
                                // 全选中 → 整组取消；否则整组勾选
                                for (final i in indices) {
                                  if (changes[i].selected == allSelected) {
                                    onToggle!(i);
                                  }
                                }
                              },
                            ),
                      children: [
                        for (final i in indices)
                          CheckboxListTile(
                            value: changes[i].selected,
                            onChanged:
                                onToggle == null ? null : (_) => onToggle!(i),
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                            title: Text(changeKindLabel(changes[i].kind),
                                style: const TextStyle(fontSize: 12)),
                            subtitle: Text(
                              '${changes[i].before.isEmpty ? '' : '${changes[i].before}  →  '}${changes[i].after}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).hintColor),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}
