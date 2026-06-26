import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ImageService {
  /// Compress image to max 1024px width, JPEG 85% quality
  static Future<Uint8List> compress(File file, {int maxWidth = 1024, int quality = 85}) async {
    final result = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      minWidth: maxWidth,
      minHeight: 1,
      quality: quality,
      format: CompressFormat.jpeg,
    );
    return result;
  }

  /// Compress from bytes (for camera)
  static Future<Uint8List> compressBytes(Uint8List bytes,
      {int maxWidth = 1024, int quality = 85}) async {
    final result = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: maxWidth,
      minHeight: 1,
      quality: quality,
      format: CompressFormat.jpeg,
    );
    return result;
  }
}
