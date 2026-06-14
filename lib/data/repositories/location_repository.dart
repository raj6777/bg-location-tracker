import 'package:hive_flutter/hive_flutter.dart';
import '../models/location_record.dart';
import '../../core/constants/app_constants.dart';

class LocationRepository {
  String get _name => AppConstants.locationBoxName;

  // Close and reopen so Hive re-parses the file from disk, picking up any
  // records written by the background isolate's own Hive instance.
  Future<List<LocationRecord>> getAll() async {
    if (Hive.isBoxOpen(_name)) {
      await Hive.box<LocationRecord>(_name).close();
    }
    final box = await Hive.openBox<LocationRecord>(_name);
    return box.values.toList();
  }

  // Delete a single record by its Hive key.
  // Only called when the background service is NOT running (no concurrent writer).
  Future<void> deleteByKey(dynamic key) async {
    final box = Hive.isBoxOpen(_name)
        ? Hive.box<LocationRecord>(_name)
        : await Hive.openBox<LocationRecord>(_name);
    await box.delete(key);
  }

  Future<void> add(LocationRecord record) async {
    if (Hive.isBoxOpen(_name)) {
      await Hive.box<LocationRecord>(_name).add(record);
    }
  }

  Future<void> clear() async {
    if (Hive.isBoxOpen(_name)) {
      await Hive.box<LocationRecord>(_name).close();
    }
    final box = await Hive.openBox<LocationRecord>(_name);
    await box.clear();
  }
}
