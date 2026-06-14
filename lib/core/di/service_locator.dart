import 'package:get_it/get_it.dart';
import '../platform/battery_channel.dart';
import '../services/location_service.dart';
import '../services/background_service.dart';
import '../services/notification_service.dart';
import '../../data/repositories/location_repository.dart';

final getIt = GetIt.instance;

Future<void> setupLocator() async {
  getIt.registerLazySingleton<BatteryChannel>(() => BatteryChannel());
  getIt.registerLazySingleton<LocationService>(() => LocationService());
  getIt.registerLazySingleton<BackgroundServiceManager>(
      () => BackgroundServiceManager());
  getIt.registerLazySingleton<LocationRepository>(() => LocationRepository());
  getIt.registerLazySingleton<NotificationService>(() => NotificationService());
}
