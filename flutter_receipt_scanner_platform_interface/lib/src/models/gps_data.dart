/// GPS coordinates copied from the source image. Populated only when
/// `includeGpsExif` is true and the source carried GPS metadata.
final class GpsData {
  /// Creates GPS data.
  const GpsData({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.timestamp,
    this.speed,
    this.heading,
  });

  /// Signed decimal degrees (negative = south).
  final double latitude;

  /// Signed decimal degrees (negative = west).
  final double longitude;

  /// Meters above sea level; negative = below.
  final double? altitude;

  /// UTC GPS timestamp string.
  final String? timestamp;

  /// Speed over ground (units come from the source — usually km/h).
  final double? speed;

  /// Image direction or destination bearing in degrees.
  final double? heading;
}
