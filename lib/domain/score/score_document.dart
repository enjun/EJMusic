/// EJScore v1：曲谱中间格式（钢琴谱/吉他谱共用同一数据模型）。
library;

import '../../core/util/rational.dart';

class ScoreDocument {
  ScoreDocument({
    required this.kind,
    required this.meta,
    required this.parts,
    this.version = 1,
  });

  final int version;
  final String kind; // piano | guitar
  final ScoreMeta meta;
  final List<ScorePart> parts;

  Map<String, dynamic> toJson() => {
        'format': 'ejscore',
        'version': version,
        'kind': kind,
        'meta': meta.toJson(),
        'parts': [for (final p in parts) p.toJson()],
      };

  static ScoreDocument fromJson(Map<String, dynamic> json) => ScoreDocument(
        version: (json['version'] as num?)?.toInt() ?? 1,
        kind: (json['kind'] as String?) ?? 'piano',
        meta: ScoreMeta.fromJson(json['meta'] as Map<String, dynamic>),
        parts: [
          for (final p in (json['parts'] as List? ?? []))
            ScorePart.fromJson(p as Map<String, dynamic>)
        ],
      );

  Map<String, dynamic> toFullJson() => toJson();
}

class ScoreMeta {
  ScoreMeta({
    this.title = '',
    this.composer,
    this.keyFifths = 0,
    this.keyMode = 'major',
    this.timeBeats = 4,
    this.timeBeatType = 4,
    this.bpm = 88,
    this.beatUnit = 4,
    this.pickup = false,
    this.pageCount = 0,
    List<String>? imageNames,
  }) : imageNames = imageNames ?? const [];

  String title;
  String? composer;
  int keyFifths; // 五度圈 -7..7
  String keyMode; // major | minor
  int timeBeats;
  int timeBeatType;
  int bpm;
  int beatUnit;
  bool pickup; // 弱起小节
  int pageCount;
  List<String> imageNames;

  Map<String, dynamic> toJson() => {
        'title': title,
        'composer': composer,
        'keyFifths': keyFifths,
        'keyMode': keyMode,
        'time': {'beats': timeBeats, 'beatType': timeBeatType},
        'tempo': {'bpm': bpm, 'beatUnit': beatUnit},
        'pickup': pickup,
        'source': {'pageCount': pageCount, 'imageNames': imageNames},
      };

  static ScoreMeta fromJson(Map<String, dynamic> json) {
    final time = json['time'] as Map<String, dynamic>?;
    final tempo = json['tempo'] as Map<String, dynamic>?;
    final source = json['source'] as Map<String, dynamic>?;
    return ScoreMeta(
      title: (json['title'] as String?) ?? '',
      composer: json['composer'] as String?,
      keyFifths: (json['keyFifths'] as num?)?.toInt() ?? 0,
      keyMode: (json['keyMode'] as String?) ?? 'major',
      timeBeats: (time?['beats'] as num?)?.toInt() ?? 4,
      timeBeatType: (time?['beatType'] as num?)?.toInt() ?? 4,
      bpm: (tempo?['bpm'] as num?)?.toInt() ?? 88,
      beatUnit: (tempo?['beatUnit'] as num?)?.toInt() ?? 4,
      pickup: (json['pickup'] as bool?) ?? false,
      pageCount: (source?['pageCount'] as num?)?.toInt() ?? 0,
      imageNames: [
        for (final n in (source?['imageNames'] as List? ?? [])) n as String
      ],
    );
  }
}

class ScorePart {
  ScorePart({
    this.id = 'P1',
    this.name,
    this.instrument = 'piano',
    this.staffCount = 2,
    required this.measures,
  });

  final String id;
  final String? name;
  final String instrument;
  final int staffCount;
  final List<ScoreMeasure> measures;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'instrument': instrument,
        'staffCount': staffCount,
        'measures': [for (final m in measures) m.toJson()],
      };

  static ScorePart fromJson(Map<String, dynamic> json) => ScorePart(
        id: (json['id'] as String?) ?? 'P1',
        name: json['name'] as String?,
        instrument: (json['instrument'] as String?) ?? 'piano',
        staffCount: (json['staffCount'] as num?)?.toInt() ?? 2,
        measures: [
          for (final m in (json['measures'] as List? ?? []))
            ScoreMeasure.fromJson(m as Map<String, dynamic>)
        ],
      );
}

/// 小节属性（仅在变化时输出）。
class MeasureAttributes {
  MeasureAttributes({
    this.keyFifths,
    this.keyMode,
    this.timeBeats,
    this.timeBeatType,
    this.bpm,
    this.repeatStart = false,
    this.repeatEnd = false,
    this.repeatTimes,
    this.voltaNo,
    this.voltaOf,
    this.segno = false,
    this.coda = false,
  });

  final int? keyFifths;
  final String? keyMode;
  final int? timeBeats;
  final int? timeBeatType;
  final int? bpm;
  final bool repeatStart;
  final bool repeatEnd;
  final int? repeatTimes;
  final int? voltaNo;
  final int? voltaOf;
  final bool segno;
  final bool coda;

  bool get isEmpty =>
      keyFifths == null &&
      keyMode == null &&
      timeBeats == null &&
      timeBeatType == null &&
      bpm == null &&
      !repeatStart &&
      !repeatEnd &&
      repeatTimes == null &&
      voltaNo == null &&
      voltaOf == null &&
      !segno &&
      !coda;

  Map<String, dynamic> toJson() => {
        if (keyFifths != null) 'keyFifths': keyFifths,
        if (keyMode != null) 'keyMode': keyMode,
        if (timeBeats != null || timeBeatType != null)
          'time': {
            'beats': timeBeats,
            'beatType': timeBeatType,
          },
        if (bpm != null) 'tempo': {'bpm': bpm},
        if (repeatStart || repeatEnd || repeatTimes != null)
          'repeat': {
            'start': repeatStart,
            'end': repeatEnd,
            if (repeatTimes != null) 'times': repeatTimes,
          },
        if (voltaNo != null)
          'volta': {'no': voltaNo, 'of': voltaOf},
        if (segno) 'segno': true,
        if (coda) 'coda': true,
      };

  static MeasureAttributes? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final time = json['time'] as Map<String, dynamic>?;
    final tempo = json['tempo'] as Map<String, dynamic>?;
    final repeat = json['repeat'] as Map<String, dynamic>?;
    final volta = json['volta'] as Map<String, dynamic>?;
    return MeasureAttributes(
      keyFifths: (json['keyFifths'] as num?)?.toInt(),
      keyMode: json['keyMode'] as String?,
      timeBeats: (time?['beats'] as num?)?.toInt(),
      timeBeatType: (time?['beatType'] as num?)?.toInt(),
      bpm: (tempo?['bpm'] as num?)?.toInt(),
      repeatStart: (repeat?['start'] as bool?) ?? false,
      repeatEnd: (repeat?['end'] as bool?) ?? false,
      repeatTimes: (repeat?['times'] as num?)?.toInt(),
      voltaNo: (volta?['no'] as num?)?.toInt(),
      voltaOf: (volta?['of'] as num?)?.toInt(),
      segno: (json['segno'] as bool?) ?? false,
      coda: (json['coda'] as bool?) ?? false,
    );
  }
}

class ScoreMeasure {
  ScoreMeasure({
    required this.number,
    this.cont = false,
    this.attributes,
    required this.voices,
  });

  int number;
  bool cont; // 承接上一页末尾未完小节
  MeasureAttributes? attributes;
  List<ScoreVoice> voices;

  Map<String, dynamic> toJson() => {
        'number': number,
        if (cont) 'cont': true,
        if (attributes != null && attributes!.isEmpty == false)
          'attributes': attributes!.toJson(),
        'voices': [for (final v in voices) v.toJson()],
      };

  static ScoreMeasure fromJson(Map<String, dynamic> json) => ScoreMeasure(
        number: (json['number'] as num?)?.toInt() ?? 0,
        cont: (json['cont'] as bool?) ?? false,
        attributes:
            MeasureAttributes.fromJson(json['attributes'] as Map<String, dynamic>?),
        voices: [
          for (final v in (json['voices'] as List? ?? []))
            ScoreVoice.fromJson(v as Map<String, dynamic>)
        ],
      );
}

class ScoreVoice {
  ScoreVoice({required this.staff, this.voiceNo = 1, required this.events});

  final int staff; // 1=右手/高音谱表 2=左手/低音谱表
  final int voiceNo;
  final List<ScoreEvent> events;

  Map<String, dynamic> toJson() => {
        'staff': staff,
        if (voiceNo != 1) 'voiceNo': voiceNo,
        'events': [for (final e in events) e.toJson()],
      };

  static ScoreVoice fromJson(Map<String, dynamic> json) => ScoreVoice(
        staff: (json['staff'] as num?)?.toInt() ?? 1,
        voiceNo: (json['voiceNo'] as num?)?.toInt() ?? 1,
        events: [
          for (final e in (json['events'] as List? ?? []))
            ScoreEvent.fromJson(e as Map<String, dynamic>)
        ],
      );
}

/// 事件：音符或休止。
class ScoreEvent {
  ScoreEvent({
    required this.type,
    required this.dur,
    this.dots = 0,
    this.pitches = const [],
    this.tie,
    this.slur,
    this.tupletActual,
    this.tupletNormal,
    this.articulations = const [],
  });

  String type; // note | rest
  Rational dur; // 单位=四分音符的精确时值
  int dots;
  List<ScorePitch> pitches;
  String? tie; // start | stop | continue
  String? slur; // start | stop
  int? tupletActual; // 三连音 actual=3
  int? tupletNormal; // normal=2
  List<String> articulations;

  bool get isNote => type == 'note';
  bool get isRest => type == 'rest';

  Map<String, dynamic> toJson() => {
        'type': type,
        'dur': dur.toJson(),
        'dots': dots,
        if (isNote)
          'pitches': [for (final p in pitches) p.toJson()],
        if (tie != null) 'tie': tie,
        if (slur != null) 'slur': slur,
        if (tupletActual != null) 'tuplet': {'actual': tupletActual, 'normal': tupletNormal},
        if (articulations.isNotEmpty) 'articulations': articulations,
      };

  static ScoreEvent fromJson(Map<String, dynamic> json) {
    final durJson = json['dur'];
    final Rational dur;
    if (durJson is Map<String, dynamic>) {
      dur = Rational.fromJson(durJson);
    } else if (durJson is num) {
      dur = Rational(_decimalToN(durJson), 1024).reduced();
    } else {
      dur = const Rational(1, 1);
    }
    final tuplet = json['tuplet'] as Map<String, dynamic>?;
    final t = json['type'] as String?;
    final hasPitches = (json['pitches'] as List?)?.isNotEmpty ?? false;
    return ScoreEvent(
      type: t == 'note' || (t == null && hasPitches) ? 'note' : 'rest',
      dur: dur,
      dots: (json['dots'] as num?)?.toInt() ?? 0,
      pitches: [
        for (final p in (json['pitches'] as List? ?? []))
          ScorePitch.fromJson(p as Map<String, dynamic>)
      ],
      tie: json['tie'] as String?,
      slur: json['slur'] as String?,
      tupletActual: (tuplet?['actual'] as num?)?.toInt(),
      tupletNormal: (tuplet?['normal'] as num?)?.toInt(),
      articulations: [
        for (final a in (json['articulations'] as List? ?? [])) a as String
      ],
    );
  }
}

/// 宽容解析 LLM 可能给出的十进制时值（如 0.5）→ n/1024 再约分。
int _decimalToN(num v) => (v * 1024).round().clamp(1, 1 << 30);

class ScorePitch {
  ScorePitch({
    required this.step,
    this.alter = 0,
    required this.octave,
    this.tab,
    this.finger,
  });

  String step;
  int alter;
  int octave;
  TabPosition? tab; // 仅吉他谱
  int? finger;

  Map<String, dynamic> toJson() => {
        'step': step,
        'alter': alter,
        'octave': octave,
        if (tab != null) 'tab': tab!.toJson(),
        if (finger != null) 'finger': finger,
      };

  static ScorePitch fromJson(Map<String, dynamic> json) {
    final tabJson = json['tab'] as Map<String, dynamic>?;
    return ScorePitch(
      step: ((json['step'] as String?) ?? 'C').toUpperCase(),
      alter: (json['alter'] as num?)?.toInt() ?? 0,
      octave: (json['octave'] as num?)?.toInt() ?? 4,
      tab: tabJson == null ? null : TabPosition.fromJson(tabJson),
      finger: (json['finger'] as num?)?.toInt(),
    );
  }
}

class TabPosition {
  TabPosition({required this.string, required this.fret});

  final int string; // 1=最细弦(高音E)
  final int fret; // 0..14

  Map<String, dynamic> toJson() => {'string': string, 'fret': fret};

  static TabPosition fromJson(Map<String, dynamic> json) => TabPosition(
        string: (json['string'] as num?)?.toInt() ?? 1,
        fret: (json['fret'] as num?)?.toInt() ?? 0,
      );
}

/// LLM 单页识别片段。
class PageFragment {
  PageFragment({
    required this.page,
    this.title,
    this.composer,
    this.keyFifths,
    this.keyMode,
    this.timeBeats,
    this.timeBeatType,
    this.bpm,
    this.pickup,
    required this.measures,
    this.warnings = const [],
  });

  final int page;
  final String? title;
  final String? composer;
  final int? keyFifths;
  final String? keyMode;
  final int? timeBeats;
  final int? timeBeatType;
  final int? bpm;
  final bool? pickup;
  List<ScoreMeasure> measures;
  List<String> warnings;

  Map<String, dynamic> toJson() => {
        'page': page,
        if (title != null) 'title': title,
        if (composer != null) 'composer': composer,
        if (keyFifths != null) 'keyFifths': keyFifths,
        if (keyMode != null) 'keyMode': keyMode,
        if (timeBeats != null) 'timeBeats': timeBeats,
        if (timeBeatType != null) 'timeBeatType': timeBeatType,
        if (bpm != null) 'bpm': bpm,
        if (pickup != null) 'pickup': pickup,
        'measures': [for (final m in measures) m.toJson()],
        if (warnings.isNotEmpty) 'warnings': warnings,
      };

  static PageFragment fromJson(Map<String, dynamic> json) => PageFragment(
        page: (json['page'] as num?)?.toInt() ?? 0,
        title: json['title'] as String?,
        composer: json['composer'] as String?,
        keyFifths: (json['keyFifths'] as num?)?.toInt(),
        keyMode: json['keyMode'] as String?,
        timeBeats: (json['timeBeats'] as num?)?.toInt(),
        timeBeatType: (json['timeBeatType'] as num?)?.toInt(),
        bpm: (json['bpm'] as num?)?.toInt(),
        pickup: json['pickup'] as bool?,
        measures: [
          for (final m in (json['measures'] as List? ?? []))
            ScoreMeasure.fromJson(m as Map<String, dynamic>)
        ],
        warnings: [
          for (final w in (json['warnings'] as List? ?? [])) w.toString()
        ],
      );
}

/// 音符时值的绘制类型名（MusicXML type）。
/// base = dur / 附点系数 必须是 2^k 时值，否则返回 null（时值保持权威，type 省略）。
String? noteTypeName(Rational dur, int dots) {
  if (dots < 0 || dots > 3) return null;
  // 附点系数 = (2^(dots+1)-1) / 2^dots
  final factor = Rational((1 << (dots + 1)) - 1, 1 << dots);
  final base = (dur * Rational(factor.denominator, factor.numerator)).reduced();
  var n = base.numerator, d = base.denominator, k = 0;
  while (n % 2 == 0 && n > 1) {
    n ~/= 2;
    k++;
  }
  while (d % 2 == 0 && d > 1) {
    d ~/= 2;
    k--;
  }
  if (n != 1 || d != 1) return null;
  // k=3 breve, 2 whole, 1 half, 0 quarter, -1 eighth, -2 16th, -3 32nd, -4 64th
  const names = ['64th', '32nd', '16th', 'eighth', 'quarter', 'half', 'whole', 'breve'];
  final idx = k + 4;
  if (idx < 0 || idx >= names.length) return null;
  return names[idx];
}
