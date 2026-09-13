class LyricLine {
  final Duration time;
  final String text;

  LyricLine({required this.time, required this.text});

  static List<LyricLine> parseLrc(String lrc) {
    List<LyricLine> lines = [];
    // LRC timestamp looks like [00:12.34] or [01:23.456]
    final RegExp regex = RegExp(r'\[(\d{2}):(\d{2}\.\d{2,3})\](.*)');

    for (var line in lrc.split('\n')) {
      final match = regex.firstMatch(line);
      if (match != null) {
        final int minutes = int.parse(match.group(1)!);
        final double seconds = double.parse(match.group(2)!);
        final String text = match.group(3)?.trim() ?? '';

        final Duration time = Duration(
          milliseconds: (minutes * 60 * 1000 + seconds * 1000).toInt(),
        );

        if (text.isNotEmpty) {
          lines.add(LyricLine(time: time, text: text));
        }
      }
    }
    return lines;
  }
}
