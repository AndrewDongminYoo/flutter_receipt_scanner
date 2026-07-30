// Computes character error rates for a physical long-receipt acceptance run.
//
// Compares a captured merged OCR text against the canonical fixture text in
// test/fixtures/long_receipt/fixture_manifest.json and reports the aggregate,
// Hangul-only, and Latin-only character error rates required by Work Item 5.
//
// Usage (from the flutter_receipt_scanner package directory):
//
//   dart run tool/receipt_benchmark/compute_cer.dart <merged_text_file>
//   dart run tool/receipt_benchmark/compute_cer.dart --self-test
//
// Both texts are normalized the same way before comparison: lines are
// trimmed, empty lines are dropped, and internal whitespace runs collapse to
// one space. Comparison is case-sensitive; a wrong letter case is a real OCR
// error. CER = levenshtein(reference, hypothesis) / reference length.

import 'dart:convert';
import 'dart:io';

const _manifestPath = 'test/fixtures/long_receipt/fixture_manifest.json';

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('Usage: dart run tool/receipt_benchmark/compute_cer.dart <merged_text_file>|--self-test');
    exitCode = 64;
    return;
  }
  if (args.single == '--self-test') {
    _selfTest();
    stdout.writeln('self-test OK');
    return;
  }

  final manifest = jsonDecode(File(_manifestPath).readAsStringSync()) as Map<String, dynamic>;
  final reference = _normalize(manifest['canonicalText'] as String);
  final hypothesis = _normalize(File(args.single).readAsStringSync());

  final report = StringBuffer()
    ..writeln('reference chars: ${reference.length}')
    ..writeln('hypothesis chars: ${hypothesis.length}')
    ..writeln('aggregate CER: ${_formatCer(reference, hypothesis)} (gate: <= 0.20)')
    ..writeln('hangul CER: ${_formatCer(_only(reference, _isHangul), _only(hypothesis, _isHangul))} (gate: <= 0.25)')
    ..writeln('latin CER: ${_formatCer(_only(reference, _isLatin), _only(hypothesis, _isLatin))} (gate: <= 0.25)');
  stdout.write(report);
}

String _normalize(String text) => text
    .split('\n')
    .map((line) => line.trim().replaceAll(RegExp(r'\s+'), ' '))
    .where((line) => line.isNotEmpty)
    .join('\n');

String _only(String text, bool Function(int) keep) => String.fromCharCodes(text.runes.where(keep));

bool _isHangul(int rune) => rune >= 0xAC00 && rune <= 0xD7A3;

bool _isLatin(int rune) => (rune >= 0x41 && rune <= 0x5A) || (rune >= 0x61 && rune <= 0x7A);

String _formatCer(String reference, String hypothesis) {
  if (reference.isEmpty) return 'n/a (empty reference)';
  final cer = _levenshtein(reference, hypothesis) / reference.length;
  return cer.toStringAsFixed(4);
}

int _levenshtein(String a, String b) {
  final aRunes = a.runes.toList();
  final bRunes = b.runes.toList();
  var previous = List<int>.generate(bRunes.length + 1, (i) => i);
  final current = List<int>.filled(bRunes.length + 1, 0);
  for (var i = 1; i <= aRunes.length; i++) {
    current[0] = i;
    for (var j = 1; j <= bRunes.length; j++) {
      final substitution = previous[j - 1] + (aRunes[i - 1] == bRunes[j - 1] ? 0 : 1);
      current[j] = [previous[j] + 1, current[j - 1] + 1, substitution].reduce((x, y) => x < y ? x : y);
    }
    previous = List<int>.of(current);
  }
  return previous[bRunes.length];
}

void _selfTest() {
  if (_levenshtein('kitten', 'sitting') != 3) throw StateError('levenshtein kitten/sitting != 3');
  if (_levenshtein('', 'abc') != 3) throw StateError('levenshtein empty/abc != 3');
  if (_levenshtein('같다', '같다') != 0) throw StateError('levenshtein identical hangul != 0');
  if (_normalize(' a  b \n\n c ') != 'a b\nc') throw StateError('normalize failed');
  if (_only('한a1글b', _isHangul) != '한글') throw StateError('hangul filter failed');
  if (_only('한a1글b', _isLatin) != 'ab') throw StateError('latin filter failed');
}
