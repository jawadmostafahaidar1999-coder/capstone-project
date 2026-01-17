import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

import '../services/api_client.dart';

class UploadedImage {
  final Uint8List bytes;
  final String filename;
  final String path; // "/storage/...."

  const UploadedImage({
    required this.bytes,
    required this.filename,
    required this.path,
  });
}

class ImageUploadHelper {
  static final ImagePicker _picker = ImagePicker();

  static Future<UploadedImage?> pickAndUpload({
    required ApiClient apiClient,
    required String folder,
    bool auth = true,
    int imageQuality = 75,
    double maxWidth = 1200,
    double maxHeight = 1200,
  }) async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: imageQuality,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
    if (x == null) return null;

    final bytes = await x.readAsBytes();
    final filename = (x.name.trim().isNotEmpty)
        ? x.name.trim()
        : 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final res = await apiClient.uploadBytes(
      '/uploads',
      bytes: bytes,
      filename: filename,
      auth: auth,
      fields: {'folder': folder},
    );

    // supports both {data:{path}} and {path}
    final dynamic data = res['data'];
    final String? path =
        (res['path'] ?? (data is Map ? (data['path'] ?? data['url']) : null))
            ?.toString();

    if (path == null || path.trim().isEmpty) {
      throw ApiException(500, 'Upload failed: no path returned.');
    }

    return UploadedImage(bytes: bytes, filename: filename, path: path.trim());
  }
}
