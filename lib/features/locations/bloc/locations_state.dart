import '../../../data/models/location_record.dart';

abstract class LocationsState {}

class LocationsInitial extends LocationsState {}

/// Normal loaded state.
/// [deletingKey] is non-null while a single-record delete is in progress —
/// the UI uses it to disable the delete action on that specific card.
class LocationsLoaded extends LocationsState {
  final List<LocationRecord> records;
  final dynamic deletingKey;

  LocationsLoaded(this.records, {this.deletingKey});
}

/// Emitted when a delete fails.
/// Carries the pre-delete records so the list can be restored without a
/// round-trip to Hive.
class LocationsDeleteError extends LocationsState {
  final List<LocationRecord> records;
  final String message;

  LocationsDeleteError(this.records, this.message);
}
