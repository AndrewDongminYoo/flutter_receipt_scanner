import 'package:flutter_receipt_scanner_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders idle status and a scan button', (tester) async {
    await tester.pumpWidget(const ReceiptScannerExampleApp());

    expect(find.text('status: idle'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
  });
}
