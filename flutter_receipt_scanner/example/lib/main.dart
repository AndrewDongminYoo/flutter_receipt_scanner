import 'package:flutter/material.dart';
import 'package:flutter_receipt_scanner/flutter_receipt_scanner.dart';

void main() => runApp(const ReceiptScannerExampleApp());

/// Minimal example exercising the iOS camera scan path.
class ReceiptScannerExampleApp extends StatefulWidget {
  /// Creates the example app.
  const ReceiptScannerExampleApp({super.key});

  @override
  State<ReceiptScannerExampleApp> createState() => _ReceiptScannerExampleAppState();
}

class _ReceiptScannerExampleAppState extends State<ReceiptScannerExampleApp> {
  String _status = 'idle';
  ScanResult? _result;

  Future<void> _scan() async {
    setState(() => _status = 'scanning…');
    try {
      final result = await scan(const ScanReceiptOptions(maxPages: 1));
      setState(() {
        _result = result;
        _status = result.status.name;
      });
    } on Object catch (e) {
      setState(() => _status = 'error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = _result?.images ?? const [];
    final image = images.isNotEmpty ? images.first : null;
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Receipt Scanner')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('status: $_status'),
              if (image != null) ...[
                const SizedBox(height: 8),
                Text('file: ${image.fileName}'),
                Text('ocr chars: ${image.ocrQuality?.textLength ?? 0}'),
              ],
              const SizedBox(height: 16),
              FilledButton(onPressed: _scan, child: const Text('Scan')),
            ],
          ),
        ),
      ),
    );
  }
}
