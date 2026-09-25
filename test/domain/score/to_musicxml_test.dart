import 'package:ejmusic/core/util/rational.dart';
import 'package:ejmusic/domain/score/convert/to_musicxml.dart';
import 'package:ejmusic/domain/score/score_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('钢琴谱：结构、divisions、双谱表、voice/backup', () {
    final doc = ScoreDocument(
      kind: 'piano',
      meta: ScoreMeta(title: '童话', timeBeats: 4, timeBeatType: 4, bpm: 88),
      parts: [
        ScorePart(measures: [
          ScoreMeasure(number: 1, voices: [
            ScoreVoice(staff: 1, events: [
              ScoreEvent(type: 'note', dur: const Rational(2, 1), pitches: [
                ScorePitch(step: 'C', octave: 4),
                ScorePitch(step: 'E', octave: 4),
              ]),
              ScoreEvent(type: 'rest', dur: const Rational(2, 1)),
            ]),
            ScoreVoice(staff: 2, events: [
              ScoreEvent(type: 'note', dur: const Rational(4, 1), pitches: [
                ScorePitch(step: 'C', octave: 3),
              ]),
            ]),
          ]),
        ]),
      ],
    );
    final xml = scoreToMusicXml(doc);
    expect(xml, contains('<score-partwise version="4.0">'));
    expect(xml, contains('<work-title>童话</work-title>'));
    expect(xml, contains('<divisions>48</divisions>'));
    expect(xml, contains('<staves>2</staves>'));
    expect(xml, contains('<clef number="1"><sign>G</sign><line>2</line></clef>'));
    expect(xml, contains('<clef number="2"><sign>F</sign><line>4</line></clef>'));
    // 二分音符 = 96 divisions
    expect(xml, contains('<duration>96</duration>'));
    expect(xml, contains('<type>half</type>'));
    expect(xml, contains('<rest/>'));
    // 和弦第二个音带 <chord/>
    expect(xml, contains('<chord/>'));
    // staff 切换时 backup 整个 staff1 块时长（96+96=192）
    expect(xml, contains('<backup><duration>192</duration></backup>'));
    expect(xml, contains('<staff>2</staff>'));
    expect(xml, contains('<voice>5</voice>'));
  });

  test('升降号、tie、附点、三连音输出', () {
    final doc = ScoreDocument(
      kind: 'piano',
      meta: ScoreMeta(title: 'T', keyFifths: 2, timeBeats: 4, timeBeatType: 4),
      parts: [
        ScorePart(measures: [
          ScoreMeasure(number: 1, voices: [
            ScoreVoice(staff: 1, events: [
              ScoreEvent(
                type: 'note',
                dur: const Rational(3, 2), // 附点二分? 3/2=附点二分（half）
                dots: 1,
                tie: 'start',
                pitches: [ScorePitch(step: 'F', alter: 1, octave: 4)],
              ),
              ScoreEvent(
                type: 'note',
                dur: const Rational(1, 3), // 三连音
                tupletActual: 3,
                tupletNormal: 2,
                tie: 'stop',
                pitches: [ScorePitch(step: 'F', alter: 1, octave: 4)],
              ),
              // 剩余 4 - 1.5 - 1/3 = 13/6 quarters
              ScoreEvent(
                type: 'note',
                dur: const Rational(13, 6),
                pitches: [ScorePitch(step: 'G', octave: 4)],
              ),
            ]),
          ]),
        ]),
      ],
    );
    final xml = scoreToMusicXml(doc);
    expect(xml, contains('<alter>1</alter>'));
    expect(xml, contains('<key><fifths>2</fifths><mode>major</mode></key>'));
    expect(xml, contains('<tie type="start"/>'));
    expect(xml, contains('<tied type="start"/>'));
    expect(xml, contains('<tie type="stop"/>'));
    expect(xml, contains('<dot/>'));
    expect(xml, contains('<type>quarter</type>'));
    // 三连音 1/3 quarter = 16 divisions
    expect(xml, contains('<time-modification><actual-notes>3</actual-notes><normal-notes>2</normal-notes></time-modification>'));
    expect(xml, contains('<tuplet type="start" number="1"/>'));
  });

  test('反复记号 barline 输出', () {
    final doc = ScoreDocument(
      kind: 'piano',
      meta: ScoreMeta(title: 'T', timeBeats: 4, timeBeatType: 4),
      parts: [
        ScorePart(measures: [
          ScoreMeasure(
            number: 1,
            attributes: MeasureAttributes(repeatStart: true),
            voices: [
              ScoreVoice(staff: 1, events: [
                ScoreEvent(type: 'rest', dur: const Rational(4, 1)),
              ]),
            ],
          ),
          ScoreMeasure(
            number: 2,
            attributes: MeasureAttributes(repeatEnd: true, repeatTimes: 2),
            voices: [
              ScoreVoice(staff: 1, events: [
                ScoreEvent(type: 'rest', dur: const Rational(4, 1)),
              ]),
            ],
          ),
          ScoreMeasure(
            number: 3,
            attributes: MeasureAttributes(voltaNo: 1, voltaOf: 2, repeatEnd: true),
            voices: [
              ScoreVoice(staff: 1, events: [
                ScoreEvent(type: 'rest', dur: const Rational(4, 1)),
              ]),
            ],
          ),
        ]),
      ],
    );
    final xml = scoreToMusicXml(doc);
    expect(xml, contains('<repeat direction="forward"/>'));
    expect(xml, contains('<bar-style>heavy-light</bar-style>'));
    expect(xml, contains('<repeat direction="backward" times="2"/>'));
    expect(xml, contains('<ending number="1" type="start"/>'));
    expect(xml, contains('<ending number="1" type="stop"/>'));
  });

  test('吉他谱：unpitched + tab + staff-details + TAB 谱号', () {
    final doc = ScoreDocument(
      kind: 'guitar',
      meta: ScoreMeta(title: 'G', timeBeats: 4, timeBeatType: 4),
      parts: [
        ScorePart(instrument: 'guitar', staffCount: 1, measures: [
          ScoreMeasure(number: 1, voices: [
            ScoreVoice(staff: 1, events: [
              ScoreEvent(type: 'note', dur: const Rational(4, 1), pitches: [
                ScorePitch(step: 'G', octave: 4, tab: TabPosition(string: 1, fret: 3)),
              ]),
            ]),
          ]),
        ]),
      ],
    );
    final xml = scoreToMusicXml(doc);
    expect(xml, contains('<sign>TAB</sign>'));
    expect(xml, contains('<staff-lines>6</staff-lines>'));
    expect(xml, contains('<staff-tuning line="1"><tuning-step>E</tuning-step><tuning-octave>2</tuning-octave></staff-tuning>'));
    expect(xml, contains('<unpitched><display-step>G</display-step><display-octave>4</display-octave></unpitched>'));
    expect(xml, contains('<technical><string>1</string><fret>3</fret></technical>'));
    expect(xml.contains('<staves>'), isFalse);
  });

  test('末小节终止线 light-heavy', () {
    final doc = ScoreDocument(
      kind: 'piano',
      meta: ScoreMeta(title: 'T', timeBeats: 4, timeBeatType: 4),
      parts: [
        ScorePart(measures: [
          ScoreMeasure(number: 1, voices: [
            ScoreVoice(staff: 1, events: [
              ScoreEvent(type: 'rest', dur: const Rational(4, 1)),
            ]),
          ]),
        ]),
      ],
    );
    final xml = scoreToMusicXml(doc);
    expect(xml, contains('<barline location="right"><bar-style>light-heavy</bar-style></barline>'));
  });

  test('XML 转义', () {
    final doc = ScoreDocument(
      kind: 'piano',
      meta: ScoreMeta(title: 'A&B<C>', timeBeats: 4, timeBeatType: 4),
      parts: [
        ScorePart(measures: [
          ScoreMeasure(number: 1, voices: [
            ScoreVoice(staff: 1, events: [
              ScoreEvent(type: 'rest', dur: const Rational(4, 1)),
            ]),
          ]),
        ]),
      ],
    );
    final xml = scoreToMusicXml(doc);
    expect(xml, contains('A&amp;B&lt;C&gt;'));
  });

  test('节拍器 beat-unit 输出 note-type 名而非数字（OSMD 渲染要求）', () {
    final doc = ScoreDocument(
      kind: 'piano',
      meta: ScoreMeta(
          title: 'T',
          timeBeats: 4,
          timeBeatType: 4,
          bpm: 96,
          beatUnit: 4),
      parts: [
        ScorePart(measures: [
          ScoreMeasure(
            number: 1,
            attributes: MeasureAttributes(bpm: 96),
            voices: [
              ScoreVoice(staff: 1, events: [
                ScoreEvent(type: 'rest', dur: const Rational(4, 1)),
              ]),
            ],
          ),
        ]),
      ],
    );
    final xml = scoreToMusicXml(doc);
    expect(xml, contains('<beat-unit>quarter</beat-unit>'));
    expect(RegExp(r'<beat-unit>\d+</beat-unit>').hasMatch(xml), isFalse);
  });
}
