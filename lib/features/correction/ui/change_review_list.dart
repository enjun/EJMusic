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
                  itemCount: changes.length,
                  itemBuilder: (context, i) {
                    final c = changes[i];
                    return CheckboxListTile(
                      value: c.selected,
                      onChanged:
                          onToggle == null ? null : (_) => onToggle!(i),
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                      title: Text(c.description,
                          style: const TextStyle(fontSize: 13)),
                      subtitle: c.before.isEmpty
                          ? null
                          : Text(
                              '${c.before}${c.after.isEmpty ? '' : '  →  ${c.after}'}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).hintColor),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                      secondary: Text(changeKindLabel(c.kind),
                          style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).hintColor)),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
