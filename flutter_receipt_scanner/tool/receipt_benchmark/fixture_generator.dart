import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import 'fixture_variants.dart';

Future<Map<String, Object?>> generateLongReceiptFixtures({
  required Directory packageDirectory,
  required Directory outputDirectory,
}) async {
  final benchmarkDirectory = Directory.fromUri(
    packageDirectory.uri.resolve('tool/receipt_benchmark/'),
  );
  final sourceFile = File.fromUri(
    benchmarkDirectory.uri.resolve('fixture_source.json'),
  );
  final source = jsonDecode(await sourceFile.readAsString()) as Map<String, Object?>;
  final geometry = source['geometry']! as Map<String, Object?>;
  final font = source['font']! as Map<String, Object?>;
  final lines = (source['lines']! as List<Object?>).cast<String>();
  final fontFile = File.fromUri(
    benchmarkDirectory.uri.resolve(font['file']! as String),
  );
  final licenseFile = File.fromUri(
    benchmarkDirectory.uri.resolve(font['licenseFile']! as String),
  );
  final fontBytes = await fontFile.readAsBytes();

  _requireChecksum(fontBytes, font['sha256']! as String, fontFile.path);
  _requireChecksum(
    await licenseFile.readAsBytes(),
    font['licenseSha256']! as String,
    licenseFile.path,
  );
  await (FontLoader(
    font['localFamily']! as String,
  )..addFont(Future.value(ByteData.sublistView(fontBytes)))).load();

  await outputDirectory.create(recursive: true);
  final width = geometry['width']! as int;
  final height = geometry['height']! as int;
  final pageWidth = geometry['pageWidth']! as int;
  final pageHeight = geometry['pageHeight']! as int;
  final pageCount = geometry['pageCount']! as int;
  final overlap = geometry['overlap']! as int;
  final pageStep = pageHeight - overlap;
  final contentTop = geometry['contentTop']! as int;
  final lineAdvance = geometry['lineAdvance']! as int;
  final lineBoxHeight = geometry['lineBoxHeight']! as int;
  final localFamily = font['localFamily']! as String;

  final logicalBytes = await _renderReceipt(
    lines: lines,
    width: width,
    height: height,
    top: 0,
    contentTop: contentTop,
    lineAdvance: lineAdvance,
    fontFamily: localFamily,
  );
  final logicalFile = File.fromUri(
    outputDirectory.uri.resolve('logical_receipt.png'),
  );
  await logicalFile.writeAsBytes(logicalBytes, flush: true);

  final pageEntries = <Map<String, Object?>>[];
  final pageOcrTexts = <String>[];
  for (var pageIndex = 0; pageIndex < pageCount; pageIndex++) {
    final top = pageIndex * pageStep;
    final pageLines = <String>[];
    final lineIndexes = <int>[];
    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final lineTop = contentTop + lineIndex * lineAdvance;
      if (lineTop >= top && lineTop + lineBoxHeight <= top + pageHeight) {
        pageLines.add(lines[lineIndex]);
        lineIndexes.add(lineIndex);
      }
    }
    final pageBytes = await _renderReceipt(
      lines: lines,
      width: pageWidth,
      height: pageHeight,
      top: top,
      contentTop: contentTop,
      lineAdvance: lineAdvance,
      fontFamily: localFamily,
    );
    final fileName = 'page_${(pageIndex + 1).toString().padLeft(2, '0')}.png';
    await File.fromUri(
      outputDirectory.uri.resolve(fileName),
    ).writeAsBytes(pageBytes, flush: true);
    final ocrText = pageLines.join('\n');
    pageOcrTexts.add(ocrText);
    pageEntries.add({
      'index': pageIndex,
      'file': fileName,
      'width': pageWidth,
      'height': pageHeight,
      'top': top,
      'overlapWithPrevious': pageIndex == 0 ? 0 : overlap,
      'lineIndexes': lineIndexes,
      'ocrText': ocrText,
      'sha256': _checksum(pageBytes),
    });
  }

  final canonicalText = lines.join('\n');
  final manifest = <String, Object?>{
    'schemaVersion': 1,
    'source': 'tool/receipt_benchmark/fixture_source.json',
    'font': font,
    'logicalImage': {
      'file': logicalFile.uri.pathSegments.last,
      'width': width,
      'height': height,
      'sha256': _checksum(logicalBytes),
    },
    'pageStep': pageStep,
    'overlap': overlap,
    'canonicalText': canonicalText,
    'pages': pageEntries,
    'variants': buildReceiptFixtureVariants(pageOcrTexts, lines),
  };
  const encoder = JsonEncoder.withIndent('  ');
  await File.fromUri(
    outputDirectory.uri.resolve('fixture_manifest.json'),
  ).writeAsString(
    '${encoder.convert(manifest)}\n',
    flush: true,
  );
  return manifest;
}

Future<Uint8List> _renderReceipt({
  required List<String> lines,
  required int width,
  required int height,
  required int top,
  required int contentTop,
  required int lineAdvance,
  required String fontFamily,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)
    ..drawRect(
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    )
    ..clipRect(ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));
  for (var index = 0; index < lines.length; index++) {
    final y = contentTop + index * lineAdvance - top;
    if (y < -48 || y >= height) continue;
    final painter = TextPainter(
      text: TextSpan(
        text: lines[index],
        style: TextStyle(
          color: const ui.Color(0xFF111111),
          fontFamily: fontFamily,
          fontSize: 32,
          height: 1,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: width - 160);
    painter
      ..paint(canvas, ui.Offset(80, y.toDouble()))
      ..dispose();
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (data == null) {
    throw StateError('Flutter could not encode the receipt fixture as PNG.');
  }
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

void _requireChecksum(List<int> bytes, String expected, String path) {
  final actual = _checksum(bytes);
  if (actual != expected) {
    throw StateError(
      'Checksum mismatch for $path: expected $expected, got $actual.',
    );
  }
}

String _checksum(List<int> bytes) => sha256.convert(bytes).toString();
