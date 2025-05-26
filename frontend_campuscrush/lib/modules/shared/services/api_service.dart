import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter/foundation.dart';
import '../../../services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';

class ApiResponse<T> {
  final bool isSuccess;
  final T? data;
  final String? error;
  final int? statusCode;

  ApiResponse.success(this.data, {this.statusCode})
      : isSuccess = true,
        error = null;
  ApiResponse.error(this.error, {this.statusCode})
      : isSuccess = false,
        data = null;
}

class ApiService {
  String baseUrl;
  late Dio _dio;
  final _auth = GetIt.instance<AuthService>();
  String? _authToken;

  static const Duration _timeoutDuration = Duration(seconds: 10);
  static const List<int> _redirectStatusCodes = [301, 302, 307, 308];

  ApiService({required this.baseUrl}) {
    _initializeDio();
  }

  void _initializeDio() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: _timeoutDuration,
      receiveTimeout: _timeoutDuration,
      followRedirects: true,
      maxRedirects: 3,
      validateStatus: (status) => status != null && status < 500,
    ));

    _dio.interceptors.add(_createInterceptor());

    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
      ));
    }
  }

  InterceptorsWrapper _createInterceptor() {
    return InterceptorsWrapper(
      onRequest: _handleRequest,
      onResponse: _handleResponse,
      onError: _handleError,
    );
  }

  void _handleRequest(
      RequestOptions options, RequestInterceptorHandler handler) {
    final bool hasAuthHeader = options.headers.containsKey('Authorization') &&
        options.headers['Authorization'] != null &&
        options.headers['Authorization'].toString().isNotEmpty;

    if (!hasAuthHeader) {
      final token = _authToken ?? _auth.token;
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      } else if (options.path.contains('/users/me')) {
        _loadTokenFromStorage().then((loadedToken) {
          if (loadedToken != null && loadedToken.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $loadedToken';
          }
        });
      }
    }

    if (kDebugMode) {
      debugPrint('🌐 [${options.method}] ${options.baseUrl}${options.path}');
    }

    return handler.next(options);
  }

  Future<void> _handleResponse(
      Response response, ResponseInterceptorHandler handler) async {
    if (_redirectStatusCodes.contains(response.statusCode) &&
        response.headers.map.containsKey('location') &&
        response.headers.map['location']!.isNotEmpty) {
      final redirectUrl = response.headers.map['location']![0];

      if (response.requestOptions.method == 'GET') {
        try {
          final uri = Uri.parse(redirectUrl);
          final newBaseUrl = '${uri.scheme}://${uri.host}:${uri.port}';

          if (newBaseUrl != baseUrl) {
            updateBaseUrl(newBaseUrl);
            final oldPath = response.requestOptions.path;

            try {
              final retryResponse = await _dio.request(
                oldPath,
                options: Options(
                  method: response.requestOptions.method,
                  headers: response.requestOptions.headers,
                ),
                data: response.requestOptions.data,
                queryParameters: response.requestOptions.queryParameters,
              );
              return handler.resolve(retryResponse);
            } catch (e) {
              debugPrint(kDebugMode ? '❌ Error retrying request: $e' : null);
            }
          }
        } catch (e) {
          debugPrint(kDebugMode ? '❌ Error processing redirect URL: $e' : null);
        }
      }
    }

    return handler.next(response);
  }

  void _handleError(DioException error, ErrorInterceptorHandler handler) {
    if (error.response?.statusCode == 401) {
      _auth.logout();
    }

    return handler.next(error);
  }

  void updateBaseUrl(String newBaseUrl) {
    baseUrl = newBaseUrl;
    _dio.options.baseUrl = newBaseUrl;
  }

  void setAuthToken(String token) {
    _authToken = token;
  }

  void clearAuthToken() {
    _authToken = null;
  }

  bool get hasAuthToken =>
      (_authToken != null && _authToken!.isNotEmpty) ||
      (_auth.isAuthenticated && _auth.token != null);

  String? get authToken => _authToken ?? _auth.token;

  Future<String> resolveRedirect(String path) async {
    try {
      final response = await _dio.head(
        path,
        options: Options(followRedirects: false),
      );

      if (_redirectStatusCodes.contains(response.statusCode)) {
        if (response.headers.map.containsKey('location') &&
            response.headers.map['location']!.isNotEmpty) {
          final redirectUrl = response.headers.map['location']![0];

          final uri = Uri.parse(redirectUrl);
          final newBaseUrl = '${uri.scheme}://${uri.host}:${uri.port}';

          if (newBaseUrl != baseUrl) {
            updateBaseUrl(newBaseUrl);
          }

          return redirectUrl;
        }
      }
    } catch (e) {
      debugPrint(kDebugMode ? '⚠️ Error checking for redirect: $e' : null);
    }

    return path;
  }

  Future<ApiResponse<T>> get<T>(String path,
      {Map<String, dynamic>? queryParameters,
      bool validateTokenFirst = false}) async {
    return _executeRequest<T>(
      () => _dio.get(path, queryParameters: queryParameters),
    );
  }

  Future<ApiResponse<T>> post<T>(String path,
      {Map<String, dynamic>? data,
      Map<String, dynamic>? queryParameters}) async {
    return _executeRequest<T>(
      () => _dio.post(path, data: data, queryParameters: queryParameters),
    );
  }

  Future<ApiResponse<T>> put<T>(String path,
      {Map<String, dynamic>? data,
      Map<String, dynamic>? queryParameters}) async {
    return _executeRequest<T>(
      () => _dio.put(path, data: data, queryParameters: queryParameters),
    );
  }

  Future<ApiResponse<T>> delete<T>(String path,
      {Map<String, dynamic>? queryParameters}) async {
    return _executeRequest<T>(
      () => _dio.delete(path, queryParameters: queryParameters),
    );
  }

  Future<ApiResponse<T>> uploadFile<T>(String path, FormData formData) async {
    return _executeRequest<T>(
      () => _dio.post(
        path,
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
            if (_authToken != null && _authToken!.isNotEmpty)
              'Authorization': 'Bearer $_authToken',
          },
        ),
      ),
      errorPrefix: 'UPLOAD',
    );
  }

  Future<ApiResponse<T>> _executeRequest<T>(
    Future<Response<dynamic>> Function() requestFunc, {
    String? errorPrefix,
  }) async {
    try {
      final response = await requestFunc();
      return ApiResponse<T>.success(response.data as T?,
          statusCode: response.statusCode);
    } catch (e) {
      debugPrint(kDebugMode ? '❌ ${errorPrefix ?? 'API'} Error: $e' : null);
      return ApiResponse<T>.error(
        _getErrorMessage(e),
        statusCode: _getStatusCode(e),
      );
    }
  }

  int? _getStatusCode(dynamic error) {
    if (error is DioException && error.response != null) {
      return error.response!.statusCode;
    }
    return null;
  }

  String _getErrorMessage(dynamic error) {
    if (error is DioException) {
      if (error.response != null) {
        final data = error.response!.data;
        if (data is Map && data['detail'] != null) {
          return data['detail'].toString();
        } else if (data is Map && data['message'] != null) {
          return data['message'].toString();
        } else if (error.response!.statusCode != null) {
          return 'Server error (${error.response!.statusCode})';
        }
      }

      switch (error.type) {
        case DioExceptionType.connectionTimeout:
          return 'Connection timeout';
        case DioExceptionType.sendTimeout:
          return 'Send timeout';
        case DioExceptionType.receiveTimeout:
          return 'Receive timeout';
        case DioExceptionType.badResponse:
          return 'Bad response';
        case DioExceptionType.cancel:
          return 'Request cancelled';
        default:
          return 'Network error';
      }
    }

    return error.toString();
  }

  Future<String?> _loadTokenFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.tokenKey);

      if (token != null && token.isNotEmpty) {
        _authToken = token;
        return token;
      }
    } catch (e) {
      debugPrint(kDebugMode ? '❌ Error loading token from storage: $e' : null);
    }
    return null;
  }
}
