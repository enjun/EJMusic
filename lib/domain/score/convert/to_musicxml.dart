import '../../../core/util/rational.dart';
import '../score_document.dart';

/// EJScore → MusicXML (score-partwise 4.0)。
/// divisions=48/四分音符：覆盖 64 分音符与三连音（1/48 最小粒度 → 1 division）。
String scoreToMusicXml(ScoreDocument doc) {
  final b = StringBuffer();
  b.writeln('<?xml version="1.0" encoding="UTF-8"?>');
  b.writeln(
      '<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 4.0 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd">');
  b.writeln('<score-partwise version="4.0">');
  final title = _esc(doc.meta.title);
  if (title.isNotEmpty) {
    b.writeln('  <work><work-title>$title</work-title></work>');
  }
  b.writeln('  <part-list>');
  final partName = doc.kind == 'guitar' ? 'Guitar' : 'Piano';
  b.writeln('    <score-part id="P1"><part-name>$partName</part-name></score-part>');
  b.writeln('  </part-list>');

  for (final part in doc.parts) {
    b.writeln('  <part id="${_esc(part.id)}">');
    _writePart(b, doc, part);
    b.writeln('  </part>');
  }
  b.writeln('</score-partwise>');
  return b.toString();
}

const _divisions = 48;

void _writePart(StringBuffer b, ScoreDocument doc, ScorePart part) {
  final isGuitar = doc.kind == 'guitar';
  var curKey = doc.meta.keyFifths;
  var curMode = doc.meta.keyMode;
  var curBeats = doc.meta.timeBeats;
  var curBeatType = doc.meta.timeBeatType;
  var attrsWritten = false;

  for (final m in part.measures) {
    b.writeln('    <measure number="${m.number}">');

    final a = m.attributes;
    if (a != null) {
      if (a.keyFifths != null) curKey = a.keyFifths!;
      if (a.keyMode != null) curMode = a.keyMode!;
      if (a.timeBeats != null) curBeats = a.timeBeats!;
      if (a.timeBeatType != null) curBeatType = a.timeBeatType!;
    }
    final needAttrs = !attrsWritten || a != null;
    if (needAttrs) {
      b.write('      <attributes>');
      if (!attrsWritten) b.write('<divisions>$_divisions</divisions>');
      b.write('<key><fifths>$curKey</fifths><mode>$curMode</mode></key>');
      b.write('<time><beats>$curBeats</beats><beat-type>$curBeatType</beat-type></time>');
      if (!attrsWritten && !isGuitar) b.write('<staves>2</staves>');
      if (!attrsWritten) {
        if (isGuitar) {
          b.write('<clef number="1"><sign>TAB</sign><line>5</line></clef>');
          b.write(_guitarStaffDetails());
        } else {
          b.write(
              '<clef number="1"><sign>G</sign><line>2</line></clef><clef number="2"><sign>F</sign><line>4</line></clef>');
        }
      }
      b.writeln('</attributes>');
      attrsWritten = true;
      if (a?.bpm != null) {
        b.write('      <direction placement="above"><direction-type>');
        b.write('<metronome><beat-unit>${doc.meta.beatUnit}</beat-unit>');
        b.write('<per-minute>${a!.bpm}</per-minute></metronome>');
        b.writeln('</direction-type><sound tempo="${a.bpm}"/></direction>');
      }
    }

    // 左右 barline（repeat/volta）
    if (a != null && (a.repeatStart || a.voltaNo != null)) {
      b.write('      <barline location="left">');
      if (a.repeatStart) b.write('<bar-style>heavy-light</bar-style>');
      if (a.voltaNo != null) {
        b.write('<ending number="${a.voltaNo}" type="start"/>');
      }
      if (a.repeatStart) b.write('<repeat direction="forward"/>');
      b.writeln('</barline>');
    }

    _writeVoices(b, m, isGuitar);

    if (a != null && (a.repeatEnd || a.voltaNo != null)) {
      b.write('      <barline location="right">');
      if (a.repeatEnd) b.write('<bar-style>light-heavy</bar-style>');
      if (a.voltaNo != null) {
        b.write('<ending number="${a.voltaNo}" type="stop"/>');
      }
      if (a.repeatEnd) {
        b.write('<repeat direction="backward" times="${a.repeatTimes ?? 2}"/>');
      }
      b.writeln('</barline>');
    } else if (m == part.measures.last) {
      b.writeln(
          '      <barline location="right"><bar-style>light-heavy</bar-style></barline>');
    }
    b.writeln('    </measure>');
  }
}

String _guitarStaffDetails() {
  // MusicXML staff-tuning line 从下往上数：line 1 = 六线谱最下线 = 6 弦（低音 E2）
  final tunings = [
    (line: 1, step: 'E', octave: 2),
    (line: 2, step: 'A', octave: 2),
    (line: 3, step: 'D', octave: 3),
    (line: 4, step: 'G', octave: 3),
    (line: 5, step: 'B', octave: 3),
    (line: 6, step: 'E', octave: 4),
  ];
  final sb = StringBuffer('<staff-details number="1"><staff-lines>6</staff-lines>');
  for (final t in tunings) {
    sb.write('<staff-tuning line="${t.line}">'
        '<tuning-step>${t.step}</tuning-step><tuning-octave>${t.octave}</tuning-octave>'
        '</staff-tuning>');
  }
  sb.write('</staff-details>');
  return sb.toString();
}

void _writeVoices(StringBuffer b, ScoreMeasure m, bool isGuitar) {
  final voices = [...m.voices]..sort((x, y) {
      final byStaff = x.staff.compareTo(y.staff);
      return byStaff != 0 ? byStaff : x.voiceNo.compareTo(y.voiceNo);
    });
  // voice 编号：staff1 → 1.., staff2 → 5..
  var nextVoiceTop = 1;
  var nextVoiceBottom = 5;
  final voiceIds = <ScoreVoice, int>{};
  for (final v in voices) {
    if (v.staff == 1) {
      voiceIds[v] = nextVoiceTop++;
    } else {
      voiceIds[v] = nextVoiceBottom++;
    }
  }

  var currentStaff = 0;
  var blockDuration = 0;
  for (final v in voices) {
    if (currentStaff != 0 && v.staff != currentStaff) {
      // 换谱表：backup 前一谱表块时长
      b.writeln('      <backup><duration>$blockDuration</duration></backup>');
      blockDuration = 0;
    }
    currentStaff = v.staff;
    for (final e in v.events) {
      blockDuration += _writeEvent(b, e, voiceIds[v]!, v.staff, isGuitar);
    }
  }
}

int _writeEvent(StringBuffer b, ScoreEvent e, int voiceId, int staff, bool isGuitar) {
  final dur = (e.dur * Rational(_divisions, 1)).reduced();
  final duration = dur.toDouble().round().clamp(1, 1 << 24);
  final type = noteTypeName(e.dur, e.dots);
  final pitchCount = e.pitches.isEmpty ? 1 : e.pitches.length;
  for (var i = 0; i < pitchCount; i++) {
    final p = e.isRest || e.pitches.isEmpty ? null : e.pitches[i];
    final chordTag = i > 0 ? '<chord/>' : '';
    if (p == null) {
      b.write('      <note>$chordTag<rest/>');
    } else if (isGuitar && p.tab != null) {
      b.write('      <note>$chordTag<unpitched>'
          '<display-step>${_esc(p.step)}</display-step>'
          '<display-octave>${p.octave}</display-octave></unpitched>');
    } else {
      b.write('      <note>$chordTag<pitch><step>${_esc(p.step)}</step>');
      if (p.alter != 0) b.write('<alter>${p.alter}</alter>');
      b.write('<octave>${p.octave}</octave></pitch>');
    }
    b.write('<duration>$duration</duration>');
    if (i == 0 && (e.tie == 'start' || e.tie == 'continue')) {
      b.write('<tie type="start"/>');
    }
    if (e.tie == 'stop' || e.tie == 'continue') {
      b.write('<tie type="stop"/>');
    }
    b.write('<voice>$voiceId</voice>');
    if (type != null) {
      b.write('<type>$type</type>');
      for (var d = 0; d < e.dots; d++) {
        b.write('<dot/>');
      }
    }
    if (e.tupletActual != null) {
      final normal = e.tupletNormal ?? 2;
      b.write('<time-modification>'
          '<actual-notes>${e.tupletActual}</actual-notes>'
          '<normal-notes>$normal</normal-notes></time-modification>');
    }
    b.write('<staff>$staff</staff>');
    // notations
    final notations = StringBuffer();
    if (e.tie == 'start' || e.tie == 'continue') notations.write('<tied type="start"/>');
    if (e.tie == 'stop' || e.tie == 'continue') notations.write('<tied type="stop"/>');
    if (e.tupletActual != null) {
      notations.write('<tuplet type="start" number="1"/>');
    }
    if (e.slur == 'start' || e.slur == 'stop') {
      notations.write('<slur type="${e.slur}" number="1"/>');
    }
    if (p != null && isGuitar && p.tab != null) {
      notations.write('<technical><string>${p.tab!.string}</string>'
          '<fret>${p.tab!.fret}</fret>');
      if (p.finger != null) notations.write('<fingering>${p.finger}</fingering>');
      notations.write('</technical>');
    } else if (p?.finger != null) {
      notations.write('<technical><fingering>${p!.finger}</fingering></technical>');
    }
    if (notations.isNotEmpty) {
      b.write('<notations>$notations</notations>');
    }
    b.writeln('</note>');
  }
  return duration;
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
