import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:synchronized/synchronized.dart';

import '../core/constants/app_constants.dart';
import '../modules/google_auth/services/google_auth_service.dart';
import '../core/di/dependency_injection.dart';

class ApiResponse<T> {
  final bool isSuccess;
  final T? data;
  final String? error;
  final int? statusCode;
  final String? statusMessage;
  final Map<String, dynamic>? extra;

  ApiResponse({
    required this.isSuccess,
    this.data,
    this.error,
    this.statusCode,
    this.statusMessage,
    this.extra,
  });

  factory ApiResponse.success(T? data,
          {int? statusCode,
          String? statusMessage,
          Map<String, dynamic>? extra}) =>
      ApiResponse<T>(
        isSuccess: true,
        data: data,
        statusCode: statusCode,
        statusMessage: statusMessage,
        extra: extra,
      );

  factory ApiResponse.error(String? error,
          {int? statusCode,
          String? statusMessage,
          Map<String, dynamic>? extra}) =>
      ApiResponse<T>(
        isSuccess: false,
        error: error,
        statusCode: statusCode,
        statusMessage: statusMessage,
        extra: extra,
      );
}

class ApiService {
  String baseUrl;
  String? _authToken;
  bool _isRefreshingToken = false;
  late final Dio _dio;
  final _tokenLock = Lock();

  String? get authToken => _authToken;
  bool get hasAuthToken => _authToken != null && _authToken!.isNotEmpty;

  static const _redirectStatusCodes = [301, 302, 307, 308];

  ApiService({required this.baseUrl}) {
    _initDio();
    _setupInterceptors();
    debugPrint('🔄 API Service initialized with baseUrl: $baseUrl');
  }

  void _initDio() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        followRedirects: true,
        validateStatus: (status) => true,
        receiveDataWhenStatusError: true,
      ),
    );

    if (AppConstants.enableNetworkLogging && kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        requestHeader: true,
        responseHeader: true,
        error: true,
      ));
    }
  }

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _handleRequest,
        onResponse: _handleResponse,
        onError: _handleError,
      ),
    );
  }

  void _handleRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    if (kReleaseMode) {
      const railwayUrl = AppConstants.baseUrl;
      final uri = Uri.parse(options.baseUrl);
      final railwayUri = Uri.parse(railwayUrl);

      if (uri.host != railwayUri.host) {
        options.baseUrl = railwayUrl;
        debugPrint(
            '🔄 Forcing Railway URL in release mode: ${options.baseUrl}');
      }
    }

    if (options.baseUrl.contains('localhost') ||
        options.baseUrl.contains('127.0.0.1') ||
        options.baseUrl.contains('10.0.2.2')) {
      options.baseUrl = AppConstants.baseUrl;
      debugPrint('🔄 Replacing localhost with Railway URL: ${options.baseUrl}');
    }

    final bool hasAuthHeader = options.headers.containsKey('Authorization') &&
        options.headers['Authorization'] != null &&
        options.headers['Authorization'].toString().isNotEmpty;

    if (!hasAuthHeader && _authToken != null && _authToken!.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $_authToken';
      if (kDebugMode) {
        debugPrint(
            '🔑 Using token: ${_authToken!.substring(0, math.min(10, _authToken!.length))}...');
      }
    }

    if (options.path.contains('/users/me') &&
        !hasAuthHeader &&
        (_authToken == null || _authToken!.isEmpty)) {
      debugPrint(
          '⚠️ Accessing user profile without token, trying to load from storage');
      await _loadTokenFromStorage();

      if (_authToken != null && _authToken!.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $_authToken';
        debugPrint('🔄 Loaded token from storage for user profile request');
      }
    }

    if (kDebugMode) {
      debugPrint('🌐 [${options.method}] ${options.uri}');
    }

    handler.next(options);
  }

  void _handleResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint(
          '✅ Response: ${response.statusCode} ${response.requestOptions.uri}');
    }
    handler.next(response);
  }

  Future<void> _handleError(
      DioException e, ErrorInterceptorHandler handler) async {
    debugPrint('❌ API Error: ${e.message} for ${e.requestOptions.uri}');

    if (e.response != null) {
      if ([401, 403].contains(e.response!.statusCode)) {
        await _handleAuthError(e, handler);
        return;
      }

      if (_redirectStatusCodes.contains(e.response!.statusCode)) {
        await _handleRedirect(e, handler);
        return;
      }
    }

    handler.next(e);
  }

  Future<void> _handleAuthError(
      DioException e, ErrorInterceptorHandler handler) async {
    debugPrint(
        '🔐 Auth Error: ${e.response?.statusCode} - ${e.response?.data}');

    bool isVerificationIssue = _isEmailVerificationIssue(e);
    bool isTokenExpired = _isTokenExpiredError(e);
    bool isGoogleAuthRequest =
        e.requestOptions.path.contains('google-signin') ||
            e.requestOptions.path.contains('auth/google');

    if (!isGoogleAuthRequest && isTokenExpired) {
      await _tokenLock.synchronized(() async {
        if (_isRefreshingToken) return;
        _isRefreshingToken = true;

        try {
          final refreshedToken = await _refreshToken();

          if (refreshedToken != null && refreshedToken.isNotEmpty) {
            _authToken = refreshedToken;
            debugPrint('🔄 Token refreshed successfully');

            final opts = Options(
              method: e.requestOptions.method,
              headers: {
                ...e.requestOptions.headers,
                'Authorization': 'Bearer $refreshedToken',
              },
            );

            final response = await _dio.request(
              e.requestOptions.path,
              data: e.requestOptions.data,
              queryParameters: e.requestOptions.queryParameters,
              options: opts,
            );

            _isRefreshingToken = false;
            return handler.resolve(response);
          } else {
            await _clearToken();
            debugPrint('🗑️ Token cleared after failed refresh');

            if (isVerificationIssue) {
              e = DioException(
                requestOptions: e.requestOptions,
                response: e.response,
                type: e.type,
                error: "EMAIL_VERIFICATION_REQUIRED",
              );
            }
          }
        } catch (refreshError) {
          debugPrint('❌ Error during token refresh: $refreshError');
          await _clearToken();
        } finally {
          _isRefreshingToken = false;
        }
      });
    }

    handler.next(e);
  }

  bool _isEmailVerificationIssue(DioException e) {
    if (e.response?.statusCode == 403) {
      try {
        final responseData = e.response!.data;
        if (responseData is Map<String, dynamic> &&
            responseData.containsKey('detail')) {
          final detail = responseData['detail'];
          return detail is String &&
              detail.toLowerCase().contains('email not verified');
        }
      } catch (parseError) {
        debugPrint('⚠️ Error parsing response data: $parseError');
      }
    }
    return false;
  }

  bool _isTokenExpiredError(DioException e) {
    if (e.response?.statusCode == 401) {
      try {
        final responseData = e.response!.data;
        if (responseData is Map<String, dynamic>) {
          final detail = responseData['detail'];
          return detail is String &&
              (detail.toLowerCase().contains('expired') ||
                  detail.toLowerCase().contains('invalid token') ||
                  detail.toLowerCase().contains('not authenticated'));
        }
      } catch (parseError) {
        debugPrint('⚠️ Error parsing token error response: $parseError');
      }
      return true;
    }
    return false;
  }

  Future<void> _handleRedirect(
      DioException e, ErrorInterceptorHandler handler) async {
    final redirectUrl = e.response!.headers.map['location']?.first;

    if (redirectUrl != null) {
      final redirectUri = Uri.parse(redirectUrl);
      final newBaseUrl =
          '${redirectUri.scheme}://${redirectUri.host}:${redirectUri.port}';
      final originalUri = e.requestOptions.uri;

      final Map<String, dynamic> extra = {
        'isRedirect': true,
        'redirectStatus': e.response!.statusCode,
        'redirectLocation': redirectUrl,
        'originalUrl': originalUri.toString(),
      };

      if (newBaseUrl != baseUrl) {
        extra['newBaseUrl'] = newBaseUrl;
      }

      if (e.requestOptions.method == 'GET') {
        debugPrint('🔄 Automatically following GET redirect');
        final options = Options(
          method: e.requestOptions.method,
          headers: e.requestOptions.headers,
        );

        _dio
            .fetch(options.compose(
              BaseOptions(baseUrl: e.requestOptions.baseUrl),
              redirectUrl,
              data: e.requestOptions.data,
            ))
            .then(
              (r) => handler.resolve(r),
              onError: (error) => handler.reject(error),
            );
      } else {
        debugPrint('🔄 Returning redirect info for non-GET request');
        final response = Response(
          requestOptions: e.requestOptions,
          statusCode: e.response!.statusCode,
          headers: e.response!.headers,
          extra: extra,
        );
        handler.resolve(response);
      }
    } else {
      handler.next(e);
    }
  }

  void setAuthToken(String token) {
    if (token.isEmpty) {
      debugPrint("ApiService: Attempted to set empty auth token");
      return;
    }

    _authToken = token;
    _dio.options.headers['Authorization'] = 'Bearer $token';
    if (kDebugMode) {
      debugPrint(
          "ApiService: Set auth token: ${token.substring(0, math.min(20, token.length))}...");
    }
  }

  void clearAuthToken() {
    _authToken = null;
    _dio.options.headers.remove('Authorization');
    debugPrint("ApiService: Cleared auth token");
  }

  void updateBaseUrl(String newBaseUrl) {
    try {
      final oldUri = Uri.parse(baseUrl);
      final newUri = Uri.parse(newBaseUrl);

      if (newUri.host == oldUri.host &&
          newUri.port == oldUri.port &&
          newUri.scheme == oldUri.scheme) {
        return;
      }

      debugPrint("🔄 Updating base URL from $baseUrl to $newBaseUrl");
      baseUrl = newBaseUrl;
      _dio.options.baseUrl = newBaseUrl;
    } catch (e) {
      debugPrint("⚠️ ApiService: Error parsing URLs: $e");
      baseUrl = newBaseUrl;
      _dio.options.baseUrl = newBaseUrl;
    }
  }

  Future<void> _clearToken() async {
    clearAuthToken();

    try {
      const storage = FlutterSecureStorage();
      await storage.delete(key: AppConstants.tokenKey);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.tokenKey);
    } catch (e) {
      debugPrint("ApiService: Error clearing token from storage: $e");
    }
  }

  String? _getHeaderValue(Headers headers, String name) {
    return headers.map.containsKey(name) &&
            headers.map[name]?.isNotEmpty == true
        ? headers.map[name]?.first
        : null;
  }

  Future<String?> checkRedirect(String path) async {
    try {
      final response = await _dio.head(
        path,
        options: Options(
          headers: {
            'Accept': 'application/json',
            if (_authToken != null && _authToken!.isNotEmpty)
              'Authorization': 'Bearer $_authToken',
          },
          followRedirects: false,
          validateStatus: (status) => true,
          receiveTimeout: const Duration(seconds: 3),
          sendTimeout: const Duration(seconds: 3),
        ),
      );

      if (_redirectStatusCodes.contains(response.statusCode)) {
        final redirectUrl = _getHeaderValue(response.headers, 'location');
        if (redirectUrl == null) return null;

        if (redirectUrl.startsWith('http')) {
          return redirectUrl;
        } else {
          return redirectUrl;
        }
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ ApiService: Error checking for redirects: $e');
      return null;
    }
  }

  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    bool validateTokenFirst = false,
  }) async {
    if (validateTokenFirst) {
      await ensureValidToken();
    }

    try {
      final redirectUrl = await checkRedirect(path);
      if (redirectUrl != null) {
        final redirectUri = Uri.parse(redirectUrl);
        final newBaseUrl =
            '${redirectUri.scheme}://${redirectUri.host}:${redirectUri.port}';
        if (newBaseUrl != baseUrl) {
          updateBaseUrl(newBaseUrl);
        }
      }

      final requestOptions = options ??
          Options(
            headers: {
              'Accept': 'application/json',
              if (_authToken != null && _authToken!.isNotEmpty)
                'Authorization': 'Bearer $_authToken',
            },
          );

      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: requestOptions,
      );

      return _processResponse<T>(response);
    } on DioException catch (e) {
      return _handleDioError<T>(e);
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  Future<ApiResponse<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    bool checkTrailingSlash = false,
  }) async {
    try {
      final requestOptions = options?.copyWith(
            followRedirects: false,
            validateStatus: (status) => true,
          ) ??
          Options(
            followRedirects: false,
            validateStatus: (status) => true,
          );

      final response = await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: requestOptions,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );

      if (_redirectStatusCodes.contains(response.statusCode)) {
        return _handleRedirectResponse<T>(response);
      }

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return ApiResponse<T>.success(
          response.data,
          statusCode: response.statusCode,
          statusMessage: response.statusMessage,
        );
      } else {
        return ApiResponse<T>.error(
          _formatErrorMessage(response),
          statusCode: response.statusCode,
          statusMessage: response.statusMessage,
        );
      }
    } on DioException catch (e) {
      return _handleDioError<T>(e);
    } catch (e) {
      return ApiResponse<T>.error(
        e.toString(),
        statusCode: 500,
        statusMessage: 'Internal error',
      );
    }
  }

  Future<ApiResponse<T>> uploadFile<T>(
    String path, {
    required FormData formData,
    Map<String, dynamic>? queryParameters,
    ProgressCallback? onSendProgress,
  }) async {
    try {
      final options = Options(
        followRedirects: false,
        validateStatus: (status) => true,
        contentType: 'multipart/form-data',
        headers: {
          'Accept': 'application/json',
          if (_authToken != null && _authToken!.isNotEmpty)
            'Authorization': 'Bearer $_authToken',
        },
      );

      final response = await _dio.post<dynamic>(
        path,
        data: formData,
        queryParameters: queryParameters,
        options: options,
        onSendProgress: onSendProgress,
      );

      if (_redirectStatusCodes.contains(response.statusCode)) {
        return _handleRedirectResponse<T>(response);
      }

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        dynamic responseData = response.data;
        if (responseData == null) {
          if (T == Map<String, dynamic>) {
            responseData = <String, dynamic>{};
          } else if (T == List<dynamic>) {
            responseData = <dynamic>[];
          }
        }

        return ApiResponse<T>.success(
          responseData as T,
          statusCode: response.statusCode,
          statusMessage: response.statusMessage,
        );
      }

      return ApiResponse<T>.error(
        _formatErrorMessage(response),
        statusCode: response.statusCode,
        statusMessage: response.statusMessage,
      );
    } on DioException catch (e) {
      return _handleDioError<T>(e);
    } catch (e) {
      return ApiResponse<T>.error(
        e.toString(),
        statusCode: 500,
        statusMessage: 'Internal error',
      );
    }
  }

  ApiResponse<T> _handleRedirectResponse<T>(Response response) {
    final redirectUrl = _getHeaderValue(response.headers, 'location');
    if (redirectUrl == null) {
      return ApiResponse<T>.error(
        'Redirect without location header',
        statusCode: response.statusCode,
        statusMessage: response.statusMessage,
      );
    }

    String? newBaseUrl;
    if (redirectUrl.startsWith('http')) {
      final redirectUri = Uri.parse(redirectUrl);
      newBaseUrl =
          '${redirectUri.scheme}://${redirectUri.host}:${redirectUri.port}';

      final currentUri = Uri.parse(baseUrl);
      if (redirectUri.host == currentUri.host &&
          redirectUri.port == currentUri.port &&
          redirectUri.scheme == currentUri.scheme) {
        newBaseUrl = null;
      }
    }

    dynamic defaultData;
    if (T == Map<String, dynamic>) {
      defaultData = <String, dynamic>{};
    } else if (T == List<dynamic>) {
      defaultData = <dynamic>[];
    } else {
      defaultData = null;
    }

    return ApiResponse<T>.success(
      defaultData as T,
      extra: {
        'isRedirect': true,
        'redirectStatus': response.statusCode,
        'redirectLocation': redirectUrl,
        'originalUrl': response.requestOptions.uri.toString(),
        if (newBaseUrl != null) 'newBaseUrl': newBaseUrl,
      },
      statusCode: response.statusCode,
      statusMessage: 'Redirect to $redirectUrl',
    );
  }

  Future<ApiResponse<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final requestOptions = options ??
          Options(
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (_authToken != null && _authToken!.isNotEmpty)
                'Authorization': 'Bearer $_authToken',
            },
          );

      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: requestOptions,
      );

      return ApiResponse<T>.success(response.data as T?,
          statusCode: response.statusCode);
    } catch (e) {
      return ApiResponse<T>.error(_parseError(e),
          statusCode: _getStatusCode(e));
    }
  }

  Future<ApiResponse<T>> delete<T>(String endpoint, {Options? options}) async {
    try {
      final Options requestOptions = options ?? Options();
      if (_authToken != null &&
          _authToken!.isNotEmpty &&
          (requestOptions.headers == null ||
              !requestOptions.headers!.containsKey('Authorization'))) {
        requestOptions.headers ??= {};
        requestOptions.headers!['Authorization'] = 'Bearer $_authToken';
      }

      final response = await _dio.delete<dynamic>(
        endpoint,
        options: requestOptions,
      );

      final T? responseData = _extractResponseData<T>(response.data);

      return ApiResponse<T>(
        isSuccess: true,
        data: responseData,
        statusCode: response.statusCode,
        statusMessage: response.statusMessage,
      );
    } on DioException catch (e) {
      final errorMessage = _getErrorDetailFromDioException(e);

      if (e.response?.statusCode == 404) {
        return ApiResponse<T>(
          isSuccess: false,
          error: "Resource not found or already deleted",
          statusCode: 404,
          statusMessage: e.response?.statusMessage,
        );
      }

      return ApiResponse<T>(
        isSuccess: false,
        error: errorMessage,
        statusCode: e.response?.statusCode,
        statusMessage: e.response?.statusMessage,
      );
    } catch (e) {
      return ApiResponse<T>(
        isSuccess: false,
        error: e.toString(),
        statusCode: 0,
      );
    }
  }

  ApiResponse<T> _processResponse<T>(Response response) {
    try {
      if (T == dynamic) {
        return ApiResponse.success(response.data as T);
      }

      if (T.toString().contains('Map<String, dynamic>')) {
        if (response.data is Map) {
          return ApiResponse.success(response.data as T);
        } else if (response.data is List) {
          return ApiResponse.success({'items': response.data} as T);
        }
      }

      if (T.toString().contains('List<dynamic>')) {
        if (response.data is List) {
          return ApiResponse.success(response.data as T);
        } else if (response.data is Map) {
          final mapData = response.data as Map;
          if (mapData.containsKey('items') && mapData['items'] is List) {
            return ApiResponse.success(mapData['items'] as T);
          }
        }
      }

      return ApiResponse.success(response.data as T);
    } catch (e) {
      debugPrint('⚠️ Type conversion error: $e');
      return ApiResponse.success(response.data as T);
    }
  }

  String _getErrorDetailFromDioException(DioException e) {
    if (e.response?.data != null) {
      try {
        if (e.response!.data is Map) {
          final data = e.response!.data as Map;
          for (final key in ['detail', 'message', 'error']) {
            if (data.containsKey(key)) {
              return data[key].toString();
            }
          }
        } else if (e.response!.data is String) {
          return e.response!.data;
        }
      } catch (_) {}
    }

    return e.response?.statusMessage ?? e.message ?? "Unknown error";
  }

  T? _extractResponseData<T>(dynamic data) {
    if (data == null) return null;

    try {
      if (data is T) return data;

      if (T.toString().contains('List') && data is Map) {
        final mapData = data;
        if (mapData.containsKey('items') && mapData['items'] is List) {
          return mapData['items'] as T;
        } else if (mapData.containsKey('results') &&
            mapData['results'] is List) {
          return mapData['results'] as T;
        }
      }

      if (T.toString().contains('Map') && data is Map) {
        return data as T;
      }
    } catch (e) {
      debugPrint('Error extracting data: $e');
    }

    try {
      return data as T;
    } catch (_) {
      return null;
    }
  }

  String _parseError(dynamic error) {
    if (error is DioException) {
      if (error.response != null) {
        final Map<String, dynamic>? data = error.response?.data;
        if (data != null) {
          if (data.containsKey('detail')) {
            return data['detail'].toString();
          } else if (data.containsKey('message')) {
            return data['message'].toString();
          }
        }

        if (error.response?.statusCode != null) {
          return 'Server error: ${error.response?.statusCode}';
        }
      }

      return switch (error.type) {
        DioExceptionType.connectionTimeout => 'Connection timeout',
        DioExceptionType.sendTimeout => 'Send timeout',
        DioExceptionType.receiveTimeout => 'Receive timeout',
        DioExceptionType.badCertificate => 'Bad certificate',
        DioExceptionType.badResponse => 'Bad response',
        DioExceptionType.cancel => 'Request cancelled',
        DioExceptionType.connectionError => 'Connection error',
        DioExceptionType.unknown => 'Unknown error',
      };
    } else if (error is SocketException) {
      return 'Network connection error';
    } else {
      return error.toString();
    }
  }

  int? _getStatusCode(dynamic error) {
    if (error is DioException && error.response != null) {
      return error.response?.statusCode;
    }
    return null;
  }

  ApiResponse<T> _handleDioError<T>(DioException e) {
    if (e.response != null) {
      return ApiResponse<T>.error(
        _formatErrorMessage(e.response!),
        statusCode: e.response!.statusCode,
        statusMessage: e.response!.statusMessage,
      );
    } else {
      return ApiResponse<T>.error(
        _parseError(e),
        statusCode: e.type == DioExceptionType.connectionTimeout ? 408 : 500,
        statusMessage: e.message,
      );
    }
  }

  String _formatErrorMessage(Response response) {
    try {
      if (response.data is Map) {
        final Map<String, dynamic> data = response.data as Map<String, dynamic>;
        if (data.containsKey('detail')) {
          return data['detail'].toString();
        } else if (data.containsKey('message')) {
          return data['message'].toString();
        }
      }
      return 'Server error: ${response.statusCode}';
    } catch (e) {
      return 'Server error: ${response.statusCode}';
    }
  }

  Future<String?> _refreshToken() async {
    try {
      const storage = FlutterSecureStorage();
      final storedToken = await storage.read(key: AppConstants.tokenKey);

      if (storedToken != null &&
          storedToken.isNotEmpty &&
          storedToken != _authToken) {
        debugPrint('🔄 Found newer token in secure storage');
        return storedToken;
      }

      final googleAuthService = GlobalServiceAccess.getGoogleAuthService();
      final firebaseToken = googleAuthService != null
          ? await googleAuthService.refreshFirebaseToken()
          : await GoogleAuthService.getFreshFirebaseToken();

      if (firebaseToken != null) {
        try {
          final refreshDio = Dio(BaseOptions(
            baseUrl: baseUrl,
            headers: {'Content-Type': 'application/json'},
          ));

          final response = await refreshDio.post<Map<String, dynamic>>(
            '${AppConstants.apiPrefix}/auth/google-signin',
            data: {
              'firebase_token': firebaseToken,
              'refresh': true,
              'email': FirebaseAuth.instance.currentUser?.email,
              'name': FirebaseAuth.instance.currentUser?.displayName,
              'photo_url': FirebaseAuth.instance.currentUser?.photoURL,
            },
          );

          if (response.statusCode == 200 &&
              response.data != null &&
              response.data!['access_token'] != null) {
            final newToken = response.data!['access_token'] as String;
            await storage.write(key: AppConstants.tokenKey, value: newToken);

            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(AppConstants.tokenKey, newToken);

            debugPrint('✅ Successfully refreshed token using Firebase');
            return newToken;
          }
        } catch (e) {
          debugPrint('❌ Failed to exchange Firebase token: $e');
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final prefToken = prefs.getString(AppConstants.tokenKey);

      if (prefToken != null &&
          prefToken.isNotEmpty &&
          prefToken != _authToken) {
        debugPrint('🔄 Using token from shared preferences');
        await storage.write(key: AppConstants.tokenKey, value: prefToken);
        return prefToken;
      }

      debugPrint('❌ No valid token found for refresh');
      return null;
    } catch (e) {
      debugPrint('❌ Error in token refresh process: $e');
      return null;
    }
  }

  Future<void> ensureValidToken() async {
    if (!hasAuthToken) {
      await _loadTokenFromStorage();
      if (!hasAuthToken) return;
    }

    await _tokenLock.synchronized(() async {
      try {
        final response = await _dio.get(
          '${AppConstants.apiPrefix}/auth/validate-token',
          options: Options(
            headers: {'Authorization': 'Bearer $_authToken'},
            validateStatus: (status) => true,
            receiveTimeout: const Duration(seconds: 5),
            sendTimeout: const Duration(seconds: 5),
          ),
        );

        if (response.statusCode == 401 || response.statusCode == 403) {
          debugPrint('🔄 Token validation failed, refreshing token');
          final newToken = await _refreshToken();
          if (newToken == null) {
            debugPrint('❌ Token refresh failed, clearing token');
            await _clearToken();
          } else {
            debugPrint(
                '✅ Token refreshed: ${newToken.substring(0, math.min(10, newToken.length))}...');
            _authToken = newToken;
            _dio.options.headers['Authorization'] = 'Bearer $newToken';
          }
        } else if (response.statusCode != null &&
            response.statusCode! >= 200 &&
            response.statusCode! < 300) {
          debugPrint('✅ Token validated successfully');
        }
      } catch (e) {
        debugPrint('⚠️ Token validation check failed: $e');

        if (e is DioException &&
            (e.type == DioExceptionType.connectionTimeout ||
                e.type == DioExceptionType.receiveTimeout ||
                e.type == DioExceptionType.connectionError)) {
          debugPrint('⚠️ Network error during validation, keeping token');
        }
      }
    });
  }

  Future<Response<T>> headRequest<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    bool followRedirects = false,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    try {
      final options = Options(
        method: 'HEAD',
        headers: headers,
        followRedirects: followRedirects,
        validateStatus: (status) => true,
        receiveTimeout: timeout,
        sendTimeout: timeout,
      );

      return await _dio.request<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return Response(
          requestOptions: e.requestOptions,
          statusCode: 408,
          statusMessage: 'Timeout',
        );
      }
      rethrow;
    }
  }

  Future<void> _loadTokenFromStorage() async {
    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: AppConstants.tokenKey);

      if (token != null && token.isNotEmpty) {
        _authToken = token;
        _dio.options.headers['Authorization'] = 'Bearer $token';
        debugPrint('✅ Loaded token from secure storage');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final prefToken = prefs.getString(AppConstants.tokenKey);

      if (prefToken != null && prefToken.isNotEmpty) {
        _authToken = prefToken;
        _dio.options.headers['Authorization'] = 'Bearer $prefToken';
        debugPrint('✅ Loaded token from shared preferences');

        await storage.write(key: AppConstants.tokenKey, value: prefToken);
      }
    } catch (e) {
      debugPrint('❌ Error loading token from storage: $e');
    }
  }

  Future<ApiResponse<T>> _executeRequest<T>(
      Future<Response> Function() requestFn) async {
    try {
      // Log the token and headers before every request
      debugPrint('ApiService: Using token: [32m[1m[4m[7m$_authToken[0m');
      debugPrint('ApiService: Dio headers: [36m${_dio.options.headers}[0m');
      final response = await requestFn();
      return _processResponse<T>(response);
    } on DioException catch (e) {
      return _handleDioError<T>(e);
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }
}
