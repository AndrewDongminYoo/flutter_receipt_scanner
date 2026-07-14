import 'package:flutter/material.dart';
import 'package:flutter_receipt_scanner/flutter_receipt_scanner.dart';
import 'package:flutter_receipt_scanner_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the scan-option form and scan button', (tester) async {
    await tester.pumpWidget(const ReceiptScannerExampleApp());

    // Source selector renders at the top of the form.
    expect(find.text('스캔 방식'), findsOneWidget);
    expect(find.text('카메라'), findsOneWidget);
    expect(find.text('갤러리'), findsOneWidget);

    // The scan button lives below the fold in the scrollable form.
    final scanButton = find.text('카메라로 스캔');
    await tester.scrollUntilVisible(scanButton, 300);
    expect(scanButton, findsOneWidget);
  });

  testWidgets('result screen shows status, image card, and reveals the copy button', (tester) async {
    final result = ScanReceiptResult(
      status: ScanStatus.success,
      images: [
        ReceiptImage(
          uri: 'file:///tmp/receipt.jpg',
          width: 800,
          height: 1200,
          fileName: 'receipt.jpg',
          fileSize: 4096,
          mimeType: 'image/jpeg',
          imageOrigin: ImageOrigin.camera,
          ocrText: 'line one\nline two',
          ocrQuality: const OcrQuality(textLength: 16, lineCount: 2, confidence: 0.9),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ResultScreen(result: result, source: ScanSource.camera),
      ),
    );

    expect(find.textContaining('스캔 성공'), findsOneWidget);
    expect(find.text('페이지 1'), findsOneWidget);

    // The copy button lives inside the collapsed "OCR 텍스트" tile.
    final ocrTile = find.text('OCR 텍스트');
    await tester.scrollUntilVisible(ocrTile, 200);
    await tester.tap(ocrTile);
    await tester.pumpAndSettle();
    expect(find.text('복사'), findsOneWidget);
  });
}
