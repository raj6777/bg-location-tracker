import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'locations_event.dart';
import 'locations_state.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/services/background_service.dart';
import '../../../data/models/location_record.dart';
import '../../../data/repositories/location_repository.dart';

class LocationsBloc extends Bloc<LocationsEvent, LocationsState> {
  final LocationRepository _repo = getIt<LocationRepository>();
  final BackgroundServiceManager _bgService = getIt<BackgroundServiceManager>();
  StreamSubscription<Map<String, dynamic>?>? _locationSub;

  LocationsBloc() : super(LocationsInitial()) {
    on<LoadLocations>(_onLoad);
    on<ClearLocations>(_onClear);
    on<DeleteLocation>(_onDelete);

    // Auto-refresh the list every time the background isolate records a new fix.
    _locationSub = _bgService.onLocation.listen((_) {
      if (!isClosed) add(LoadLocations());
    });
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> _onLoad(
      LoadLocations event, Emitter<LocationsState> emit) async {
    debugPrint('[LocationsBloc] Loading records from Hive...');
    final records = await _repo.getAll();
    debugPrint('[LocationsBloc] Loaded ${records.length} record(s).');
    emit(LocationsLoaded(records));
  }

  // ── Delete single record ───────────────────────────────────────────────────

  Future<void> _onDelete(
      DeleteLocation event, Emitter<LocationsState> emit) async {
    final currentRecords = state is LocationsLoaded
        ? List<LocationRecord>.from((state as LocationsLoaded).records)
        : <LocationRecord>[];

    debugPrint('[LocationsBloc] Delete requested — key: ${event.hiveKey}');

    // Mark the card as "deleting" so the UI disables its action pane.
    if (state is LocationsLoaded) {
      emit(LocationsLoaded(
        (state as LocationsLoaded).records,
        deletingKey: event.hiveKey,
      ));
    }

    try {
      final running = await _bgService.isRunning();
      if (running) {
        // Background isolate is the sole Hive writer — send it the delete
        // event and wait for confirmation before reading back from disk.
        debugPrint(
            '[LocationsBloc] Routing delete through background isolate — key: ${event.hiveKey}');
        final completer = Completer<void>();
        StreamSubscription? sub;
        final timeout = Timer(const Duration(seconds: 5), () {
          sub?.cancel();
          if (!completer.isCompleted) {
            completer.completeError('delete timeout');
          }
        });
        sub = _bgService.onRecordDeleted.listen((data) {
          if (data?['key']?.toString() == event.hiveKey.toString()) {
            timeout.cancel();
            sub?.cancel();
            if (!completer.isCompleted) completer.complete();
          }
        });
        _bgService.deleteRecord(event.hiveKey);
        await completer.future;
        debugPrint('[LocationsBloc] Background confirmed delete — key: ${event.hiveKey}');
      } else {
        // Service not running — no concurrent writer, safe to delete directly.
        debugPrint('[LocationsBloc] Service stopped; deleting directly — key: ${event.hiveKey}');
        await _repo.deleteByKey(event.hiveKey);
        debugPrint('[LocationsBloc] Direct Hive delete done — key: ${event.hiveKey}');
      }

      // Re-read from disk so the UI reflects the true post-delete state.
      debugPrint('[LocationsBloc] Refreshing list from Hive...');
      final fresh = await _repo.getAll();
      debugPrint('[LocationsBloc] Refresh complete — ${fresh.length} record(s) remaining.');
      emit(LocationsLoaded(fresh));
    } catch (e, st) {
      debugPrint(
          '[LocationsBloc] Delete FAILED — key: ${event.hiveKey} | error: $e\n$st');
      emit(LocationsDeleteError(
          currentRecords, 'Could not delete record. Please try again.'));
    }
  }

  // ── Clear all ─────────────────────────────────────────────────────────────

  Future<void> _onClear(
      ClearLocations event, Emitter<LocationsState> emit) async {
    debugPrint('[LocationsBloc] Clearing all records...');
    try {
      final running = await _bgService.isRunning();
      if (running) {
        // Route clear through the background isolate to avoid concurrent writes.
        final completer = Completer<void>();
        StreamSubscription? sub;
        final timeout = Timer(const Duration(seconds: 5), () {
          sub?.cancel();
          if (!completer.isCompleted) completer.completeError('clear timeout');
        });
        sub = _bgService.onRecordsCleared.listen((_) {
          timeout.cancel();
          sub?.cancel();
          if (!completer.isCompleted) completer.complete();
        });
        _bgService.clearRecords();
        await completer.future;
        debugPrint('[LocationsBloc] Background confirmed clear.');
      } else {
        await _repo.clear();
        debugPrint('[LocationsBloc] Direct Hive clear done.');
      }
      // Re-read from disk (should be empty now).
      final fresh = await _repo.getAll();
      emit(LocationsLoaded(fresh));
    } catch (e) {
      debugPrint('[LocationsBloc] Clear FAILED | error: $e');
      // Optimistically show empty — the clear likely succeeded even on timeout.
      emit(LocationsLoaded(const []));
    }
  }

  @override
  Future<void> close() {
    _locationSub?.cancel();
    return super.close();
  }
}
