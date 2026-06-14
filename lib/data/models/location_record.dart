import 'package:hive/hive.dart';

part 'location_record.g.dart';

@HiveType(typeId: 0)
class LocationRecord extends HiveObject {
  @HiveField(0)
  final double latitude;

  @HiveField(1)
  final double longitude;

  @HiveField(2)
  final DateTime timestamp;

  @HiveField(3)
  final double accuracy;

  LocationRecord({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.accuracy,
  });

  Map<String, dynamic> toMap() => {
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': timestamp.toIso8601String(),
        'accuracy': accuracy,
      };

  factory LocationRecord.fromMap(Map<String, dynamic> map) => LocationRecord(
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        timestamp: DateTime.parse(map['timestamp'] as String),
        accuracy: (map['accuracy'] as num).toDouble(),
      );
}
