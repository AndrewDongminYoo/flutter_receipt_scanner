// Copyright (c) 2026 Dongmin, Yu. MIT License; see LICENSE.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('vendored identity is the accepted immutable ABI v1 snapshot', () {
    final manifest = jsonDecode(
      File('third_party/receipt_core/manifest.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(manifest['abiVersion'], 1);
    expect(
      manifest['sourceCommit'],
      'fb37f24a86014829a31897ca891d45a78208aa6c',
    );
    expect(manifest['sourceDirectory'], 'cpp/receipt_core');
    expect((manifest['files'] as Map).length, 11);
  });
}
