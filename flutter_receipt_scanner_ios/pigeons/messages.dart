import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    dartPackageName: 'flutter_receipt_scanner',
    swiftOut: 'ios/flutter_receipt_scanner_ios/Sources/flutter_receipt_scanner_ios/Messages.g.swift',
    swiftOptions: SwiftOptions(),
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
}

class ScanResultWire {
  ScanStatusWire status;
  List<ReceiptImageWire> images;
  List<ReceiptImageWire> rejectedImages;
}

@HostApi()
abstract class ReceiptScannerApi {
  @async
  ScanResultWire scan(ScanOptionsWire options);
}
