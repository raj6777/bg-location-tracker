import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/utils/permission_helper.dart';
import '../../../core/services/background_service.dart';
import 'tracking_event.dart';
import 'tracking_state.dart';

class TrackingBloc extends Bloc<TrackingEvent, TrackingState> {
  final BackgroundServiceManager _bgService = getIt<BackgroundServiceManager>();
  final PermissionHelper _permissions = PermissionHelper();
  StreamSubscription<Map<String, dynamic>?>? _locationSub;

  TrackingBloc() : super(TrackingInitial()) {
    on<CheckTrackingStatus>(_onCheckStatus);
    on<StartTracking>(_onStart);
    on<StopTracking>(_onStop);
    on<LocationReceived>(_onLocation);
    on<RecheckPermissions>(_onRecheck);

    // On every cold open, check whether the background service survived an
    // app kill so we can restore the correct START / STOP button state.
    add(CheckTrackingStatus());
  }

  Future<void> _onCheckStatus(
      CheckTrackingStatus event, Emitter<TrackingState> emit) async {
    final running = await _bgService.isRunning();
    if (running) {
      // Re-attach to live location events from the still-running service.
      _locationSub?.cancel();
      _locationSub = _bgService.onLocation.listen((data) {
        if (data != null && !isClosed) add(LocationReceived(data));
      });
      emit(TrackingRunning(0));
    }
    // Not running → stay in TrackingInitial (START enabled, STOP disabled).
  }

  Future<void> _onStart(
      StartTracking event, Emitter<TrackingState> emit) async {
    final result = await _permissions.requestAll();
    final blocked = _toBlockedState(result);
    if (blocked != null) {
      emit(blocked);
      return;
    }
    await _launchService(emit);
  }

  Future<void> _onRecheck(
      RecheckPermissions event, Emitter<TrackingState> emit) async {
    final result = await _permissions.recheck();
    final blocked = _toBlockedState(result);
    if (blocked != null) {
      emit(blocked);
      return;
    }
    await _launchService(emit);
  }

  Future<void> _onStop(
      StopTracking event, Emitter<TrackingState> emit) async {
    await _locationSub?.cancel();
    _locationSub = null;
    await _bgService.stop();
    emit(TrackingStopped());
  }

  void _onLocation(LocationReceived event, Emitter<TrackingState> emit) {
    if (state is TrackingRunning) {
      emit(TrackingRunning((state as TrackingRunning).count + 1));
    }
  }

  TrackingState? _toBlockedState(LocationPermissionStatus status) {
    switch (status) {
      case LocationPermissionStatus.gpsDisabled:
        return TrackingGpsDisabled();
      case LocationPermissionStatus.foregroundDenied:
        return TrackingForegroundPermissionDenied();
      case LocationPermissionStatus.foregroundPermanentlyDenied:
        return TrackingPermissionPermanentlyDenied(isBackground: false);
      case LocationPermissionStatus.backgroundDenied:
        return TrackingBackgroundPermissionDenied();
      case LocationPermissionStatus.backgroundPermanentlyDenied:
        return TrackingPermissionPermanentlyDenied(isBackground: true);
      case LocationPermissionStatus.granted:
        return null;
    }
  }

  Future<void> _launchService(Emitter<TrackingState> emit) async {
    _locationSub?.cancel();
    _locationSub = _bgService.onLocation.listen((data) {
      if (data != null && !isClosed) add(LocationReceived(data));
    });
    final started = await _bgService.start();
    if (!started) {
      await _locationSub?.cancel();
      _locationSub = null;
      emit(TrackingError('Failed to start background service.'));
      return;
    }
    emit(TrackingRunning(0));
  }

  @override
  Future<void> close() {
    _locationSub?.cancel();
    return super.close();
  }
}
