# Architecture Summary

## Data flow across the isolate boundary

```
[Background isolate — flutter_background_service foreground service]
  Timer.periodic(60 s)
    → Geolocator.getCurrentPosition()
    → box.add(LocationRecord)           ← sole writer to Hive
    → service.invoke('onLocation', map) ← emits live event to UI isolate

[UI isolate]
  TrackingBloc
    ← service.on('onLocation')          ← receives live event, increments count
  LocationsBloc
    ← LocationRepository.getAll()       ← reads Hive box for full history
```

### Why the background isolate is the only writer
Dart isolates share no heap. `flutter_background_service` runs the capture
loop in a **separate Dart isolate** from the UI. Because Hive is not
multi-isolate safe for concurrent writes, the background isolate is
designated as the sole writer. The UI isolate opens the same box but only
calls `getAll()` / `watch()` (reads). A concurrent write from both isolates
would corrupt the binary file.

---

## Key design decisions

### Foreground service (Android)
A foreground service with a persistent notification keeps the process alive
when the app is backgrounded, minimised, or the screen is locked. Without
it, Android's battery optimiser will kill the process within minutes.

`android:foregroundServiceType="location"` is required from API 29, and the
`FOREGROUND_SERVICE_LOCATION` permission is required from API 34. Both are
declared in `AndroidManifest.xml`.

### Battery via Platform Channel
Battery level is read natively to satisfy the "no third-party battery
package" requirement:

| Platform | API used |
|----------|----------|
| Android  | `BatteryManager.BATTERY_PROPERTY_CAPACITY` in `MainActivity.kt` |
| iOS      | `UIDevice.current.batteryLevel × 100` in `SceneDelegate.swift` |

The Dart `BatteryCubit` polls `BatteryChannel` every 15 s and emits state
changes to the `BatteryIndicator` widget.

### iOS limitation (honest documentation)
iOS does **not** allow an arbitrary 60-second timer to run indefinitely after
the user force-quits the app, and it does **not** relaunch the app after
force-kill the way Android does. The `UIBackgroundModes` of `location`,
`fetch`, and `processing` enable best-effort background execution while the
app is in the background task queue, but make no guarantee of a strict 60 s
interval after a force-kill.

The reliable iOS fallback is `allowsBackgroundLocationUpdates` combined with
significant-change monitoring or region monitoring, which wakes the app on
meaningful movement rather than on a fixed clock. This is the correct
engineering trade-off to state in a technical interview — claiming parity
with Android on iOS would be inaccurate.

### Hive over SQLite
Hive was chosen for its zero-SQL-boilerplate typed storage. The multi-isolate
write constraint is the one caveat (handled above). `sqflite` is a valid
alternative with slightly more resilient concurrent file access but adds SQL
overhead; either satisfies the task.

### State management (BLoC)
All business logic lives in `TrackingBloc`, `BatteryCubit`, and
`LocationsBloc`. Widgets hold no state and are purely reactive — this makes
the data flow easy to reason about and defend in a technical discussion.
