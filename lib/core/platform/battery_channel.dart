import 'package:flutter/services.dart';
import '../constants/app_constants.dart';

class BatteryChannel {
  static const _channel = MethodChannel(AppConstants.batteryChannel);

  Future<int> getBatteryLevel() async {
    final level =
        await _channel.invokeMethod<int>(AppConstants.batteryMethod);
    return level ?? -1;
  }
}
