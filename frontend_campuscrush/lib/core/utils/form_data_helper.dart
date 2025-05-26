import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart';
import 'package:http_parser/http_parser.dart';

/// Helper class for consistent handling of multipart form data across the app
class FormDataHelper {
  /// Creates a FormData object with text fields and optional file fields
  static Future<FormData> create({
    Map<String, dynamic>? fields,
    Map<String, File>? files,
  }) async {
    // Create base FormData with text fields
    final formData = FormData.fromMap(fields ?? {});

    // Add files if provided
    if (files != null && files.isNotEmpty) {
      for (final entry in files.entries) {
        final file = entry.value;
        final mediaType = _getMediaContentType(file.path);

        formData.files.add(
          MapEntry(
            entry.key,
            await MultipartFile.fromFile(
              file.path,
              filename: basename(file.path),
              contentType: mediaType,
            ),
          ),
        );
      }
    }

    return formData;
  }

  /// Determines the MediaType based on file extension
  static MediaType _getMediaContentType(String filePath) {
    final ext = extension(filePath).toLowerCase().replaceFirst('.', '');

    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'gif':
        return MediaType('image', 'gif');
      case 'mp4':
        return MediaType('video', 'mp4');
      case 'mov':
        return MediaType('video', 'quicktime');
      default:
        return MediaType('application', 'octet-stream');
    }
  }
}
