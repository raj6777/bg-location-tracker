import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/platform/battery_channel.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/constants/app_constants.dart';
import 'battery_state.dart';

class BatteryCubit extends Cubit<BatteryState> {
  final BatteryChannel _channel;
  Timer? _timer;

  BatteryCubit()
      : _channel = getIt<BatteryChannel>(),
        super(const BatteryState(-1)) {
    _fetch();
    _timer = Timer.periodic(AppConstants.batteryRefreshInterval, (_) => _fetch());
  }

  Future<void> _fetch() async {
    try {
      final level = await _channel.getBatteryLevel();
      if (!isClosed) emit(BatteryState(level));
    } catch (_) {
      // Platform channel unavailable (e.g. simulator) — keep last known state
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}