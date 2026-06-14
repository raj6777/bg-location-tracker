import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';
import 'core/di/service_locator.dart';
import 'core/services/background_service.dart';
import 'core/services/notification_service.dart';
import 'data/models/location_record.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // UI isolate opens Hive for reading location history.
  // The background isolate opens its own instance as the sole writer.
  await Hive.initFlutter();
  Hive.registerAdapter(LocationRecordAdapter());
  await Hive.openBox<LocationRecord>('locations');

  await setupLocator();

  // Create Android notification channel before the background service starts
  await getIt<NotificationService>().init();

  // Register the background service configuration (does NOT start tracking yet)
  await getIt<BackgroundServiceManager>().configure();

  runApp(const App());
}
