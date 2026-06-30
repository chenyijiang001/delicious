import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recipe.dart';
import '../services/api_client.dart';
import '../services/image_service.dart';

enum CameraStatus { idle, picking, uploading, analyzing, done, error }

class CameraState {
  final CameraStatus status;
  final File? imageFile;
  final Uint8List? imageBytes;
  final Recipe? recipe;
  final String? errorMessage;
  final String? errorCode; // 后端 detail.code，前端用来分支处理
  final DateTime? analyzingStartedAt;

  const CameraState({
    this.status = CameraStatus.idle,
    this.imageFile,
    this.imageBytes,
    this.recipe,
    this.errorMessage,
    this.errorCode,
    this.analyzingStartedAt,
  });

  CameraState copyWith({
    CameraStatus? status,
    File? imageFile,
    Uint8List? imageBytes,
    Recipe? recipe,
    String? errorMessage,
    String? errorCode,
    DateTime? analyzingStartedAt,
  }) =>
      CameraState(
        status: status ?? this.status,
        imageFile: imageFile ?? this.imageFile,
        imageBytes: imageBytes ?? this.imageBytes,
        recipe: recipe ?? this.recipe,
        errorMessage: errorMessage,
        errorCode: errorCode,
        analyzingStartedAt: analyzingStartedAt ?? this.analyzingStartedAt,
      );
}

class CameraNotifier extends StateNotifier<CameraState> {
  final ApiClient _api;

  CameraNotifier(this._api) : super(const CameraState());

  /// 选完图后立即识别，符合"拍照即所得"的产品诉求。
  Future<void> setImageAndAnalyze(File file, Uint8List bytes) async {
    state = CameraState(
      status: CameraStatus.uploading,
      imageFile: file,
      imageBytes: bytes,
      analyzingStartedAt: DateTime.now(),
    );
    await _analyze();
  }

  Future<void> retry() async {
    if (state.imageFile == null) return;
    state = state.copyWith(
      status: CameraStatus.uploading,
      analyzingStartedAt: DateTime.now(),
      errorMessage: null,
      errorCode: null,
    );
    await _analyze();
  }

  Future<void> _analyze() async {
    final file = state.imageFile;
    if (file == null) return;

    try {
      final compressed = await ImageService.compress(file);
      state = state.copyWith(
        status: CameraStatus.analyzing,
        imageBytes: compressed,
      );

      final formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(compressed, filename: 'food.jpg'),
      });

      final res = await _api.dio.post('/ai/recognize', data: formData);
      final recipe = Recipe.fromJson(res.data as Map<String, dynamic>);

      state = state.copyWith(status: CameraStatus.done, recipe: recipe);
    } on DioException catch (e) {
      final api = e.error;
      String code = 'network_error';
      String message = '识别失败，请重试';
      if (api is ApiException) {
        code = api.code;
        message = api.message;
      }
      state = state.copyWith(
        status: CameraStatus.error,
        errorMessage: message,
        errorCode: code,
      );
    } catch (e) {
      state = state.copyWith(
        status: CameraStatus.error,
        errorMessage: '识别失败：$e',
        errorCode: 'unknown',
      );
    }
  }

  void reset() {
    state = const CameraState();
  }
}

final cameraProvider =
    StateNotifierProvider<CameraNotifier, CameraState>((ref) {
  return CameraNotifier(ref.watch(apiClientProvider));
});
