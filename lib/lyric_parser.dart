import 'bridge.dart';

class LyricLine {
  final int time;
  final String text;
  LyricLine(this.time, this.text);
}

class LyricData {
  final List<LyricLine> lines;
  LyricData(this.lines);

  int indexAt(int ms) {
    for (int i = lines.length - 1; i >= 0; i--) {
      if (ms >= lines[i].time) return i;
    }
    return 0;
  }

  static LyricData parse(String raw) {
    final r = Bridge.I.call('parse_lrc', '', raw);
    final out = <LyricLine>[];
    if (r is List) {
      for (final e in r) {
        if (e is Map) {
          out.add(LyricLine(
            int.tryParse('${e['t']}') ?? 0,
            e['text']?.toString() ?? ''));
        }
      }
    }
    if (out.isEmpty && raw.isNotEmpty) {
      for (final line in raw.split('\n')) {
        if (line.trim().isNotEmpty) out.add(LyricLine(0, line.trim()));
      }
    }
    return LyricData(out);
  }
}
