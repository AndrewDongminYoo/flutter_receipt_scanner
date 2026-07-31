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
    final scanButton = find.byKey(const Key('scan_button'));
    await tester.dragUntilVisible(scanButton, find.byType(ListView), const Offset(0, -100));
    expect(scanButton, findsOneWidget);
  });

  testWidgets('multi-page OCR option becomes available for a multi-page camera scan', (tester) async {
    await tester.pumpWidget(const ReceiptScannerExampleApp());

    final maxPagesStepper = find.byKey(const Key('max_pages_stepper'));
    await tester.dragUntilVisible(maxPagesStepper, find.byType(ListView), const Offset(0, -100));
    await tester.tap(find.descendant(of: maxPagesStepper, matching: find.byIcon(Icons.add)));
    await tester.pump();

    final mergeOption = find.widgetWithText(SwitchListTile, '여러 페이지 OCR 이어붙이기 (mergeOcrPages)');
    await tester.dragUntilVisible(mergeOption, find.byType(ListView), const Offset(0, -100));
    expect(tester.widget<SwitchListTile>(mergeOption).onChanged, isNotNull);
    await tester.tap(mergeOption);
    await tester.pump();
    expect(tester.widget<SwitchListTile>(mergeOption).value, isTrue);
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
      mergedOcr: MergedOcrResult(
        text: 'Store Example\nItem A 1000\nTotal 1000',
        isComplete: true,
        pageUris: const ['file:///tmp/receipt.jpg', 'file:///tmp/receipt-2.jpg'],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ResultScreen(result: result, source: ScanSource.camera),
      ),
    );

    expect(find.textContaining('스캔 성공'), findsOneWidget);
    expect(find.text('병합된 OCR'), findsOneWidget);
    expect(find.text('완전한 병합'), findsOneWidget);
    // 폐기된 페이지가 없으면 해당 진단 행은 렌더링되지 않는다.
    expect(find.text('폐기된 페이지'), findsNothing);
    expect(find.textContaining('Store Example'), findsOneWidget);
    expect(find.textContaining('Total 1000'), findsOneWidget);
    expect(find.text('페이지 1'), findsOneWidget);
    expect(find.text('복사'), findsOneWidget);

    // The copy button lives inside the collapsed "OCR 텍스트" tile.
    final ocrTile = find.text('OCR 텍스트').first;
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();
    await tester.tap(ocrTile);
    await tester.pumpAndSettle();
    expect(find.text('복사'), findsNWidgets(2));
  });

  testWidgets('result screen surfaces natively discarded pages', (tester) async {
    final result = ScanReceiptResult(
      status: ScanStatus.success,
      mergedOcr: MergedOcrResult(
        text: 'Store Example\nItem A 1000',
        isComplete: false,
        pageUris: const ['file:///tmp/receipt.jpg'],
      ),
      discardedPageCount: 1,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ResultScreen(result: result, source: ScanSource.camera),
      ),
    );

    expect(find.text('폐기된 페이지'), findsOneWidget);
    expect(find.text('1장 (maxPages 초과로 미처리)'), findsOneWidget);
    expect(find.text('확인 필요'), findsOneWidget);
  });
}
