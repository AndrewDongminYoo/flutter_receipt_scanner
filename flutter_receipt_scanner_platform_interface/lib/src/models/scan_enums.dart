/// Acquisition path for a scan.
enum ScanSource {
  /// Platform document scanner (VisionKit on iOS, ML Kit GMS scanner on Android).
  camera,

  /// System photo picker followed by the in-package crop editor.
  gallery,
}

/// Best-effort classification of where an image came from.
enum ImageOrigin {
  /// Captured by the device camera (strong EXIF signal).
  camera,

  /// System screenshot.
  screenshot,

  /// Saved from a network source; no camera-style EXIF.
  download,

  /// No determinative signal available.
  unknown,
}

/// Primary discriminator on a `ScanReceiptResult`.
enum ScanStatus {
  /// The user completed the scan and at least one image passed the floor.
  success,

  /// The user dismissed the scanner or picker.
  cancelled,

  /// Every captured image fell below the OCR floor.
  rejected,
}
