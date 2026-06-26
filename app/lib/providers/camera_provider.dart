import 'dart:io';
import 'dart:typed_data';
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

  const CameraState({
    this.status = CameraStatus.idle,
    this.imageFile,
    this.imageBytes,
    this.recipe,
    this.errorMessage,
  });

  CameraState copyWith({
    CameraStatus? status,
    File? imageFile,
    Uint8List? imageBytes,
    Recipe? recipe,
    String? errorMessage,
  }) =>
      CameraState(
        status: status ?? this.status,
        imageFile: imageFile ?? this.imageFile,
        imageBytes: imageBytes ?? this.imageBytes,
        recipe: recipe ?? this.recipe,
        errorMessage: errorMessage,
      );
}

class CameraNotifier extends StateNotifier<CameraState> {
  final ApiClient _api;

  CameraNotifier(this._api) : super(const CameraState());

  void setImage(File file, Uint8List bytes) {
    state = CameraState(
      status: CameraStatus.picking,
      imageFile: file,
      imageBytes: bytes,
    );
  }

  Future<void> analyze() async {
    if (state.imageFile == null) return;
    state = state.copyWith(status: CameraStatus.uploading);

    try {
      final compressed = await ImageService.compress(state.imageFile!);
      state = state.copyWith(status: CameraStatus.analyzing, imageBytes: compressed);

      final formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(compressed, filename: 'food.jpg'),
      });

      final res = await _api.dio.post('/ai/recognize', data: formData);
      final recipe = Recipe.fromJson(res.data as Map<String, dynamic>);

      state = state.copyWith(status: CameraStatus.done, recipe: recipe);
    } catch (e) {
      state = state.copyWith(
        status: CameraStatus.error,
        errorMessage: '识别失败: ${e.toString()}',
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
