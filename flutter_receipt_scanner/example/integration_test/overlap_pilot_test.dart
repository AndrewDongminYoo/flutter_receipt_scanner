import 'package:flutter/widgets.dart';
import 'package:flutter_receipt_scanner_example/overlap_pilot.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('source-built FFI preserves all mobile fixture and workload results', (tester) async {
    expect(runPilotParity(pilotContract()), 29);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
