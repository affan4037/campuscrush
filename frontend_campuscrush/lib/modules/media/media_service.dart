// Frontend Media Module - Service

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
// Assuming you have a constants file for your base URL
// import 'package:campus_crush/core/constants/app_constants.dart';

class MediaService {
  final Dio _dio = Dio();
  // Replace with your actual backend base URL or import from constants
  final String baseUrl = 'YOUR_FASTAPI_BASE_URL';

  Future<String> uploadFile(File file) async {
    try {
      String fileName = file.path.split('/').last;
      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: fileName),
      });

      final response = await _dio.post(
        '$baseUrl/api/v1/media/upload', // Assuming /api/v1/media is the media router prefix and /upload is an upload endpoint
        data: formData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['url'];
      } else {
        throw Exception('Failed to upload file: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }

  // Add other media related methods here, e.g., for fetching or deleting
}
