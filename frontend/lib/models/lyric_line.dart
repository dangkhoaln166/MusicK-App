class LyricLine {
  final Duration time;
  final String text;

  LyricLine({required this.time, required this.text});

  static List<LyricLine> parseLrc(String lrc) {
    List<LyricLine> lines = [];
    // LRC timestamp can be [mm:ss.xx], [mm:ss], [m:ss.xx]
    final RegExp timeRegExp = RegExp(r'\[(\d+):(\d+(?:\.\d+)?)\]');
    
    for (var line in lrc.split('\n')) {
      final matches = timeRegExp.allMatches(line);
      if (matches.isNotEmpty) {
        // Find the end of the last match to extract the text
        final lastMatchEnd = matches.last.end;
        final text = line.substring(lastMatchEnd).trim();
        
        if (text.isNotEmpty) {
          for (var match in matches) {
            final int minutes = int.parse(match.group(1)!);
            final double seconds = double.parse(match.group(2)!);
            final Duration time = Duration(
              milliseconds: (minutes * 60 * 1000 + seconds * 1000).toInt(),
            );
            lines.add(LyricLine(time: time, text: text));
          }
        }
      }
    }
    // Sort in case multiple timestamps are out of order
    lines.sort((a, b) => a.time.compareTo(b.time));
    return lines;
  }
}
