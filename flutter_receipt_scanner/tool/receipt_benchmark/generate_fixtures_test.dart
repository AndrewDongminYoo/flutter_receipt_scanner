import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'fixture_generator.dart';

void main() {
  test('generate checked-in long receipt fixtures', () async {
    final packageDirectory = Directory.current;
    final outputDirectory = Directory.fromUri(
      packageDirectory.uri.resolve('test/fixtures/long_receipt/'),
    );

    await generateLongReceiptFixtures(
      packageDirectory: packageDirectory,
      outputDirectory: outputDirectory,
    );
  });
}
