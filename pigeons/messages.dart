import 'package:pigeon/pigeon.dart';

// ignore_for_file: not_initialized_non_nullable_instance_field
// Single source of truth for the host<->native wire contract. Emits the Dart
// client into the platform-interface package (shared by both platform packages)
// and the Swift/Kotlin hosts into their respective native packages. Run from the
// repo root via `melos run generate`.
@ConfigurePigeon(
  PigeonOptions(
    dartOut:
        'flutter_receipt_scanner_platform_interface/lib/src/messages.g.dart',
    dartPackageName: 'flutter_receipt_scanner',
    swiftOut:
        'flutter_receipt_scanner_ios/ios/flutter_receipt_scanner_ios/Sources/flutter_receipt_scanner_ios/Messages.g.swift',
    swiftOptions: SwiftOptions(),
    kotlinOut:
        'flutter_receipt_scanner_android/android/src/main/kotlin/com/example/flutter_receipt_scanner_android/Messages.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'com.example.flutter_receipt_scanner_android',
    ),
  ),
)
enum ScanSourceWire { camera, gallery }

enum ImageOriginWire { camera, screenshot, download, unknown }

enum ScanStatusWire { success, cancelled, rejected }

class ScanOptionsWire {
  ScanSourceWire? source;
  int? maxPages;
  double? quality;
  bool? includeExif;
  bool? includeGpsExif;
  bool? ocr;
  bool? cropAutoConfirm;
  bool? autoRotate;
  bool? includeRawExif;
  double? minimumTextHeight;
  bool? ocrGeometry;
}

class GpsDataWire {
  double? latitude;
  double? longitude;
  double? altitude;
  String? timestamp;
  double? speed;
  double? heading;
}

class ReceiptExifWire {
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
  GpsDataWire? gps;
  Map<String, Object?>? raw;
}

class OcrQualityWire {
  int? textLength;
  int? lineCount;
  double? confidence;
}

class ReceiptImageWire {
  String uri;
  int width;
  int height;
  String fileName;
  String mimeType;
  int fileSize;
  ImageOriginWire imageOrigin;
  String? ocrText;
  OcrQualityWire? ocrQuality;
  ReceiptExifWire? exif;
  List<OcrLineWire>? ocrLines;
}

class ScanResultWire {
  ScanStatusWire status;
  List<ReceiptImageWire> images;
  List<ReceiptImageWire> rejectedImages;
}

/// One recognized text line's box, in top-left-origin pixels of the output image.
///
/// Declared after [ScanResultWire] on purpose: Pigeon assigns codec bytes in
/// declaration order, so new wire classes are appended at the end to keep the
/// byte assignments of already-shipped types stable.
class OcrLineWire {
  String text;
  int x;
  int y;
  int width;
  int height;
  double? confidence;
}

@HostApi()
abstract class ReceiptScannerApi {
  @async
  ScanResultWire scan(ScanOptionsWire options);
}
