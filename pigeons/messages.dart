import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut:
        'flutter_receipt_scanner_platform_interface/lib/src/messages.g.dart',
    dartOptions: DartOptions(),
    swiftOut:
        'flutter_receipt_scanner_ios/ios/flutter_receipt_scanner_ios/Sources/flutter_receipt_scanner_ios/Messages.g.swift',
    swiftOptions: SwiftOptions(),
    kotlinOut:
        'flutter_receipt_scanner_android/android/src/main/kotlin/com/example/flutter_receipt_scanner_android/Messages.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'com.example.flutter_receipt_scanner_android',
    ),
    dartPackageName: 'flutter_receipt_scanner_platform_interface',
  ),
)
// Acquisition path. Camera opens the platform document scanner; gallery opens
// a system picker followed by the in-package crop editor.
enum ScanSource { camera, gallery }

// Best-effort classification of where the image came from.
enum ImageOrigin { camera, screenshot, download, unknown }

// Primary discriminator on the scan result.
enum ScanStatus { success, cancelled, rejected }

// Acceptance thresholds for OCR output (reporting shape; the gate runs in Dart).
class OcrFloorMessage {
  int? minTextLength;
  int? minLines;
  double? minConfidence;
}

// Caller options forwarded to the native scanner. Nullable so the native side
// can coerce defaults; the app-facing Dart layer fills them before sending.
class ScanOptions {
  ScanSource? source;
  int? maxPages;
  double? quality;
  bool? includeExif;
  bool? includeGpsExif;
  bool? ocr;
  bool? cropAutoConfirm;
  bool? autoRotate;
  bool? includeRawExif;
  double? minimumTextHeight;
}

// GPS coordinates copied from the source image (only when includeGpsExif).
class GpsData {
  double? latitude;
  double? longitude;
  double? altitude;
  String? timestamp;
  double? speed;
  double? heading;
}

// Per-image EXIF white-list plus optional raw passthrough.
class ReceiptExif {
  int? orientation;
  int? colorSpace;
  int? lightSource;
  String? exifVersion;
  String? make;
  String? model;
  String? software;
  String? dateTime;
  String? dateTimeOriginal;
  String? dateTimeDigitized;
  double? exposureTime;
  double? fNumber;
  double? iso;
  double? focalLength;
  int? flash;
  int? whiteBalance;
  int? exposureMode;
  int? exposureProgram;
  int? meteringMode;
  GpsData? gps;
  Map<String, Object?>? raw;
}

// Derived OCR quality metrics. textLength/lineCount are filled in Dart;
// confidence passes through from the native recognizer when OCR runs.
class OcrQuality {
  int? textLength;
  int? lineCount;
  double? confidence;
}

// One output image. Non-null fields are always populated by the native layer,
// so Dart consumers never null-check them (generated constructor marks them
// `required`). Optional fields depend on the enabled options.
class ReceiptImage {
  String uri;
  int width;
  int height;
  String fileName;
  String mimeType;
  int fileSize;
  ImageOrigin imageOrigin;
  String? ocrText;
  OcrQuality? ocrQuality;
  ReceiptExif? exif;
}

// Scan result. status/images/rejectedImages are always present.
class ScanResult {
  ScanStatus status;
  List<ReceiptImage> images;
  List<ReceiptImage> rejectedImages;
}

@HostApi()
abstract class ReceiptScannerApi {
  @async
  ScanResult scan(ScanOptions options);
}
