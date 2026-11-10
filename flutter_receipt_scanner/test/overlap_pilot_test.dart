import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

// Consumer harness shares code with the explicit example without a dependency cycle.
// ignore: avoid_relative_lib_imports
import '../example/lib/overlap_pilot.dart';
// Consumer harness shares code with the explicit example without a dependency cycle.
// ignore: avoid_relative_lib_imports
import '../example/lib/pilot_workloads.dart';

void main() {
  test('frozen 48 workloads match RN v1 UTF-16 snapshot', () {
    final workloads = pilotWorkloads();
    expect(workloads, hasLength(48));
    final json = jsonEncode([
      for (final workload in workloads) {'id': workload.id, 'pages': workload.pages},
    ]);
    expect(
      sha256.convert(utf8.encode(json)).toString(),
      'be17e753bd70cf21e358ceb3221adf66283ed52a2b32549877c9a52ad4ab86ce',
    );
  });
  test('headless consumer validates literal fixtures and complete workload parity', () {
    final corpus =
        jsonDecode(File('test/fixtures/ocr-contracts/v1/contract.json').readAsStringSync()) as Map<String, dynamic>;
    expect(pilotContract(), corpus);
    if (const bool.fromEnvironment('OVERLAP_PILOT_CORRUPT_EXPECTATION')) {
      final fixtures = (corpus['mergeCases'] as List).cast<Map<String, dynamic>>();
      (fixtures.first['expected'] as Map<String, dynamic>)['text'] = 'deliberately corrupted expectation';
    }
    expect(runPilotParity(corpus), 29);
  });
}
