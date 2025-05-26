import 'package:dio/dio.dart';

class ApiConnectionTest {
  static Future<Map<String, dynamic>> testConnection(String baseUrl) async {
    final dio = Dio();
    final result = {
      'success': false,
      'message': '',
      'statusCode': null,
      'data': null,
    };

    try {
      // Set a short timeout for quick feedback
      dio.options.connectTimeout = const Duration(seconds: 5);
      dio.options.receiveTimeout = const Duration(seconds: 5);

      // Try to connect to the base URL
      final response = await dio.get(baseUrl);

      result['success'] = true;
      result['message'] = 'Connection successful';
      result['statusCode'] = response.statusCode;
      result['data'] = response.data;

      return result;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        result['message'] =
            'Connection timed out. Server might be down or unreachable.';
      } else if (e.type == DioExceptionType.unknown &&
          e.error != null &&
          e.error.toString().contains('SocketException')) {
        result['message'] =
            'Cannot connect to the server. Please check if the server is running.';
      } else if (e.response != null) {
        // The server responded with an error status code
        result['statusCode'] = e.response!.statusCode;
        result['message'] =
            'Server responded with status code: ${e.response!.statusCode}';
        result['data'] = e.response!.data;

        // If we got a response, the connection itself was successful
        if (e.response!.statusCode != null) {
          result['success'] = true;
        }
      } else {
        result['message'] = 'Connection error: ${e.message}';
      }

      return result;
    } catch (e) {
      result['message'] = 'Unexpected error: $e';
      return result;
    }
  }
}
