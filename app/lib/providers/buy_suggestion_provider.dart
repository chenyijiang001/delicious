import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/buy_suggestion.dart';
import '../services/api_client.dart';
import '../services/location_service.dart';

enum BuySuggestionStatus {
  idle,
  locating,
  loading,
  loaded,
  locationDenied,
  error,
}

class BuySuggestionState {
  final BuySuggestionStatus status;
  final BuySuggestion? data;
  final LocationDenialReason? denialReason;
  final String? errorMessage;
  final double? lat;
  final double? lng;

  const BuySuggestionState({
    this.status = BuySuggestionStatus.idle,
    this.data,
    this.denialReason,
    this.errorMessage,
    this.lat,
    this.lng,
  });

  BuySuggestionState copyWith({
    BuySuggestionStatus? status,
    BuySuggestion? data,
    LocationDenialReason? denialReason,
    String? errorMessage,
    double? lat,
    double? lng,
  }) =>
      BuySuggestionState(
        status: status ?? this.status,
        data: data ?? this.data,
        denialReason: denialReason,
        errorMessage: errorMessage,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
      );
}

class BuySuggestionNotifier extends StateNotifier<BuySuggestionState> {
  final ApiClient _api;
  final LocationService _location;

  BuySuggestionNotifier(this._api, this._location)
      : super(const BuySuggestionState());

  Future<void> load({String? cityCode}) async {
    state = state.copyWith(status: BuySuggestionStatus.locating);
    final loc = await _location.requestCurrent();
    if (!loc.hasLocation && cityCode == null) {
      state = BuySuggestionState(
        status: BuySuggestionStatus.locationDenied,
        denialReason: loc.denialReason,
      );
      return;
    }

    state = state.copyWith(
      status: BuySuggestionStatus.loading,
      lat: loc.lat,
      lng: loc.lng,
    );

    try {
      final body = <String, dynamic>{
        if (loc.hasLocation)
          'location': {'lat': loc.lat, 'lng': loc.lng}
        else if (cityCode != null)
          'city_code': cityCode,
        'channels': ['offline', 'online', 'delivery'],
        'radius_m': 1500,
      };
      final res = await _api.dio.post('/shopping/buy-suggestions', data: body);
      final data = BuySuggestion.fromJson(res.data as Map<String, dynamic>);
      state = BuySuggestionState(
        status: BuySuggestionStatus.loaded,
        data: data,
        lat: loc.lat,
        lng: loc.lng,
      );
    } catch (e) {
      state = state.copyWith(
        status: BuySuggestionStatus.error,
        errorMessage: '获取建议失败',
      );
    }
  }

  Future<void> reportClick({
    required String channel,
    required String target,
    required int missingCount,
  }) async {
    try {
      await _api.dio.post('/shopping/buy-suggestions/click', data: {
        'channel': channel,
        'target': target,
        'missing_count': missingCount,
      });
    } catch (_) {
      // 埋点失败不打断跳转
    }
  }
}

final buySuggestionProvider =
    StateNotifierProvider<BuySuggestionNotifier, BuySuggestionState>((ref) {
  return BuySuggestionNotifier(
    ref.watch(apiClientProvider),
    ref.watch(locationServiceProvider),
  );
});
