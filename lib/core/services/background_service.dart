import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../../dart_plugin_registrant.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../data/models/location_record.dart';
import '../constants/app_constants.dart';

class BackgroundServiceManager {
  final _service = FlutterBackgroundService();

  Future<void> configure() async {
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: AppConstants.notificationChannelId,
        initialNotificationTitle: 'Location Tracker',
        initialNotificationContent: 'Tracking your location...',
        foregroundServiceNotificationId: 1,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: _onIosBackground,
      ),
    );
  }

  Future<bool> start() async {
    // Ensure a wake lock is acquired from the UI isolate before asking the
    // background isolate to start. Acquiring the wake lock from the UI side
    // is more reliable on Android than trying to do it inside the background
    // isolate (platform channels may not behave the same from there) and
    // prevents the CPU from sleeping when the screen locks while the app is
    // open.
    try {
      await WakelockPlus.enable();
    } catch (e) {
      // Non-fatal: if we cannot acquire the wake lock from the UI isolate,
      // the background isolate will still attempt to enable it. Continue.
    }

    if (await _service.isRunning()) {
      _service.invoke('startTracking');
      return true;
    }
    final started = await _service.startService();
    if (!started) return false;

    // Wait for the background isolate to signal it is fully initialized before
    // sending 'startTracking'. The fixed 500 ms delay was not enough on cold
    // start — Hive init + box open can take longer, causing the message to
    // arrive before the listener is registered and be silently dropped.
    final completer = Completer<void>();
    StreamSubscription? sub;
    final timeout = Timer(const Duration(seconds: 8), () {
      sub?.cancel();
      if (!completer.isCompleted) completer.complete();
    });
    sub = _service.on('ready').listen((_) {
      timeout.cancel();
      sub?.cancel();
      if (!completer.isCompleted) completer.complete();
    });
    await completer.future;

    _service.invoke('startTracking');
    return true;
  }

  Future<void> stop() async {
    // Ask the background isolate to stop its timer and service.
    _service.invoke('stopService');

    // Also release any wake lock we acquired from the UI isolate to avoid
    // keeping the CPU/screen awake after tracking has stopped.
    try {
      await WakelockPlus.disable();
    } catch (e) {
      // Ignore — not critical.
    }
  }

  Future<bool> isRunning() => _service.isRunning();

  Stream<Map<String, dynamic>?> get onLocation => _service.on('onLocation');

  // Ask the background isolate (sole Hive writer) to delete a record.
  void deleteRecord(dynamic key) {
    _service.invoke('deleteRecord', {'key': key.toString()});
  }

  // Fires once per delete; carries the key that was deleted.
  Stream<Map<String, dynamic>?> get onRecordDeleted =>
      _service.on('recordDeleted');

  // Ask the background isolate to wipe the whole box.
  void clearRecords() {
    _service.invoke('clearRecords');
  }

  Stream<Map<String, dynamic>?> get onRecordsCleared =>
      _service.on('recordsCleared');
}

// Called on iOS when the app moves to background — return true to keep alive
@pragma('vm:entry-point')
bool _onIosBackground(ServiceInstance service) {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

// Background isolate entry point — must be top-level and annotated.
// This isolate is the SOLE WRITER to the Hive box; the UI isolate only reads.
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapter(LocationRecordAdapter());
  final box = await Hive.openBox<LocationRecord>(AppConstants.locationBoxName);

  // Hive init + box open are complete — tell the UI isolate we're ready.
  service.invoke('ready');

  Timer? timer;

  Future<void> capture() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 60), // Increased from 15s to accommodate screen-locked GPS delays
        ),
      );
      final record = LocationRecord(
        latitude: pos.latitude,
        longitude: pos.longitude,
        timestamp: DateTime.now(),
        accuracy: pos.accuracy,
      );
      await box.add(record);
      // Emit live event across the isolate boundary to the UI
      service.invoke('onLocation', record.toMap());
      // Diagnostic log visible in adb logcat to help investigate missing captures
      // from the background isolate when the screen locks.
      print('[BG] Captured location: ${record.latitude}, ${record.longitude} @ ${record.timestamp.toIso8601String()}');
    } catch (_) {
      // GPS unavailable this tick — skip silently, but log for diagnostics
      print('[BG] capture() failed or timed out');
    }
  }

    service.on('startTracking').listen((_) async {
    timer?.cancel();

    // CRITICAL: Acquire wake lock to keep CPU awake when screen locks.
    // Without this, Android suspends the CPU and the Timer stops executing,
    // preventing location capture every 60 seconds while screen is locked.
    try {
      await WakelockPlus.enable();
      print('[BG] Wakelock enabled in background isolate');
    } catch (e) {
      // Wake lock enable failed — continue anyway, but GPS may be unreliable
      print('[BG] Wakelock enable failed in background isolate: $e');
    }

    await capture(); // immediate first fix
    print('[BG] Scheduled periodic capture every ${AppConstants.trackingInterval.inSeconds}s');
    timer = Timer.periodic(AppConstants.trackingInterval, (_) => capture());
  });

  // UI asks the background (sole Hive writer) to delete a single record.
  service.on('deleteRecord').listen((data) async {
    if (data == null) return;
    final keyStr = data['key'] as String?;
    if (keyStr != null) {
      final key = int.tryParse(keyStr);
      if (key != null) await box.delete(key);
      service.invoke('recordDeleted', {'key': keyStr});
    }
  });

  // UI asks the background to clear all records.
  service.on('clearRecords').listen((_) async {
    await box.clear();
    service.invoke('recordsCleared');
  });

  // stopService stops the timer AND the foreground service itself.
  service.on('stopService').listen((_) async {
    timer?.cancel();
    
    // CRITICAL: Release the wake lock to allow the CPU to sleep normally
    // and save battery when tracking is stopped.
    try {
      await WakelockPlus.disable();
      print('[BG] Wakelock disabled in background isolate');
    } catch (e) {
      // Wake lock disable failed — continue anyway
      print('[BG] Wakelock disable failed in background isolate: $e');
    }
    
    if (service is AndroidServiceInstance) {
      service.stopSelf();
    }
  });
}
