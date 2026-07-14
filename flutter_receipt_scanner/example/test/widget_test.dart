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
}
