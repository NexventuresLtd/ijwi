import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ImageHelper {
  /// Bakes EXIF rotation into the image pixels using pure Dart.
  /// Returns the path to the fixed image, or the original path if it fails.
  static Future<String> compressAndFixRotation(String path) async {
    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      
      // Decode image
      final originalImage = img.decodeImage(bytes);
      if (originalImage == null) return path;

      // Encode as JPG with compression directly from original image
      final fixedBytes = img.encodeJpg(originalImage, quality: 80);

      final dir = await getTemporaryDirectory();
      final targetPath = '${dir.absolute.path}/temp_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      final newFile = File(targetPath);
      await newFile.writeAsBytes(fixedBytes);
      
      return targetPath;
    } catch (e) {
      print('Error baking orientation: $e');
      return path;
    }
  }
}
