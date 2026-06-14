abstract class LocationsEvent {}

class LoadLocations extends LocationsEvent {}

class ClearLocations extends LocationsEvent {}

class DeleteLocation extends LocationsEvent {
  /// Hive key of the record to delete (not the display index).
  final dynamic hiveKey;
  DeleteLocation(this.hiveKey);
}
