import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

class LocationResult {
  final double? lat;
  final double? lng;
  final LocationDenialReason? denialReason;

  const LocationResult({this.lat, this.lng, this.denialReason});

  bool get hasLocation => lat != null && lng != null;
}

enum LocationDenialReason {
  serviceDisabled, // 系统定位服务关了
  permissionDenied, // 用户拒绝
  permissionDeniedForever, // 系统设置里拒绝、需要去设置
  unknown,
}

class LocationService {
  /// 请求一次性当前位置。
  /// 拒绝时返回带 denialReason 的结果，便于上层 UI 展示降级文案。
  Future<LocationResult> requestCurrent({
    LocationAccuracy accuracy = LocationAccuracy.medium,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const LocationResult(
          denialReason: LocationDenialReason.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return const LocationResult(
          denialReason: LocationDenialReason.permissionDeniedForever);
    }
    if (permission == LocationPermission.denied) {
      return const LocationResult(
          denialReason: LocationDenialReason.permissionDenied);
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: accuracy, timeLimit: timeout),
      );
      return LocationResult(lat: pos.latitude, lng: pos.longitude);
    } catch (_) {
      // 真机偶尔拿不到，退到 last known
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          return LocationResult(lat: last.latitude, lng: last.longitude);
        }
      } catch (_) {}
      return const LocationResult(denialReason: LocationDenialReason.unknown);
    }
  }
}

final locationServiceProvider =
    Provider<LocationService>((ref) => LocationService());
