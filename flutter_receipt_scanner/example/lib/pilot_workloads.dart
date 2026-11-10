// Frozen RN pilot/workloads.js v1 port. UTF-16 substring matches JS slice.
const pilotSeed = 0x69c0ffee;

List<({String id, List<String> pages})> pilotWorkloads() {
  final output = <({String id, List<String> pages})>[];
  const sizes = {
    'small': [2, 20, 24],
    'typical': [5, 100, 48],
    'stress': [20, 500, 96],
  };
  const alphabets = {'ascii': 'AbCdEf', 'korean': '가나다라마바', 'supplementary': '😀🚀🧾', 'variants': 'Ab \tCd'};
  for (final size in sizes.entries) {
    final [pageCount, lineCount, width] = size.value;
    for (final alphabet in alphabets.entries) {
      for (final mode in ['none', 'half', 'full', 'near']) {
        var state = pilotSeed;
        String row(int index) {
          state = (state * 1664525 + 1013904223) & 0xffffffff;
          final prefix = '${index.toRadixString(36)}-${state.toRadixString(36)}:';
          return (prefix + alphabet.value * width).substring(0, width);
        }

        final pages = <String>[];
        var previous = <String>[];
        for (var page = 0; page < pageCount; page++) {
          var lines = List.generate(lineCount, (index) => row(page * lineCount + index));
          if (page > 0 && mode == 'half') {
            lines.replaceRange(0, lineCount ~/ 2, previous.skip(lineCount ~/ 2));
          } else if (page > 0 && mode == 'full') {
            lines = [...previous];
          } else if (mode == 'near') {
            lines = List.filled(lineCount, (alphabet.value * width).substring(0, width));
            lines[(page * 17 + 7) % lineCount] = row(page);
          }
          previous = lines;
          pages.add(lines.join('\n'));
        }
        output.add((id: '${size.key}/${alphabet.key}/$mode', pages: pages));
      }
    }
  }
  return output;
}
