import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_receipt_scanner_platform_interface/flutter_receipt_scanner_platform_interface.dart';

/// The Android implementation of [FlutterReceiptScannerPlatform].
///
/// Talks to the native layer through the package-private Pigeon
/// [ReceiptScannerApi] and converts the generated wire types to and from the
/// public models exported by the platform interface.
class FlutterReceiptScannerAndroid extends FlutterReceiptScannerPlatform {
  /// Creates the Android platform, optionally with an injected [api] for tests.
  FlutterReceiptScannerAndroid({@visibleForTesting ReceiptScannerApi? api}) : _api = api ?? ReceiptScannerApi();

  final ReceiptScannerApi _api;

  /// Registers this class as the default platform instance.
  static void registerWith() {
    FlutterReceiptScannerPlatform.instance = FlutterReceiptScannerAndroid();
  }

  @override
  Future<ScanReceiptResult> scan(ScanReceiptOptions options) async {
    final wire = await _api.scan(_optionsToWire(options));
    return _resultFromWire(wire);
  }
}

ScanOptionsWire _optionsToWire(ScanReceiptOptions o) => ScanOptionsWire(
  source: _sourceToWire(o.source),
  maxPages: o.maxPages,
  quality: o.quality,
  includeExif: o.includeExif,
  includeGpsExif: o.includeGpsExif,
  ocr: o.ocr,
  cropAutoConfirm: o.cropAutoConfirm,
  autoRotate: o.autoRotate,
  includeRawExif: o.includeRawExif,
  minimumTextHeight: o.minimumTextHeight,
  ocrGeometry: o.ocrGeometry,
);

ScanSourceWire _sourceToWire(ScanSource s) => switch (s) {
  ScanSource.camera => ScanSourceWire.camera,
  ScanSource.gallery => ScanSourceWire.gallery,
};

ScanReceiptResult _resultFromWire(ScanResultWire w) => ScanReceiptResult(
  status: _statusFromWire(w.status),
  images: w.images.map(_imageFromWire).toList(growable: false),
  rejectedImages: w.rejectedImages.map(_imageFromWire).toList(growable: false),
  discardedPageCount: w.discardedPageCount ?? 0,
);

ScanStatus _statusFromWire(ScanStatusWire s) => switch (s) {
  ScanStatusWire.success => ScanStatus.success,
  ScanStatusWire.cancelled => ScanStatus.cancelled,
  ScanStatusWire.rejected => ScanStatus.rejected,
};

ImageOrigin _originFromWire(ImageOriginWire o) => switch (o) {
  ImageOriginWire.camera => ImageOrigin.camera,
  ImageOriginWire.screenshot => ImageOrigin.screenshot,
  ImageOriginWire.download => ImageOrigin.download,
  ImageOriginWire.unknown => ImageOrigin.unknown,
};

ReceiptImage _imageFromWire(ReceiptImageWire w) => ReceiptImage(
  uri: w.uri,
  width: w.width,
  height: w.height,
  fileName: w.fileName,
  fileSize: w.fileSize,
  imageOrigin: _originFromWire(w.imageOrigin),
  mimeType: w.mimeType,
  ocrText: w.ocrText,
  ocrQuality: _ocrQualityFromWire(w.ocrQuality),
  exif: _exifFromWire(w.exif),
  ocrLines: w.ocrLines?.map(_ocrLineFromWire).toList(growable: false),
);

OcrQuality? _ocrQualityFromWire(OcrQualityWire? w) => w == null
    ? null
    : OcrQuality(
        textLength: w.textLength ?? 0,
        lineCount: w.lineCount ?? 0,
        confidence: w.confidence,
      );

OcrLine _ocrLineFromWire(OcrLineWire w) => OcrLine(
  text: w.text,
  x: w.x,
  y: w.y,
  width: w.width,
  height: w.height,
  confidence: w.confidence,
);

GpsData? _gpsFromWire(GpsDataWire? w) => w == null || w.latitude == null || w.longitude == null
    ? null
    : GpsData(
        latitude: w.latitude!,
        longitude: w.longitude!,
        altitude: w.altitude,
        timestamp: w.timestamp,
        speed: w.speed,
        heading: w.heading,
      );

ReceiptExif? _exifFromWire(ReceiptExifWire? w) => w == null
    ? null
    : ReceiptExif(
        orientation: w.orientation,
        colorSpace: w.colorSpace,
        lightSource: w.lightSource,
        exifVersion: w.exifVersion,
        make: w.make,
        model: w.model,
        software: w.software,
        dateTime: w.dateTime,
        dateTimeOriginal: w.dateTimeOriginal,
        dateTimeDigitized: w.dateTimeDigitized,
        exposureTime: w.exposureTime,
        fNumber: w.fNumber,
        iso: w.iso,
        focalLength: w.focalLength,
        flash: w.flash,
        whiteBalance: w.whiteBalance,
        exposureMode: w.exposureMode,
        exposureProgram: w.exposureProgram,
        meteringMode: w.meteringMode,
        gps: _gpsFromWire(w.gps),
        raw: w.raw,
      );
