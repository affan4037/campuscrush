import '../../../services/api_service.dart';
import '../models/auth_models.dart';

class AuthApiService {
  final ApiService apiService;

  AuthApiService(this.apiService);

  /// Verify email with token
  Future<ApiResponse<VerificationResponse>> verifyEmail(String token) async {
    try {
      final response = await apiService.post<Map<String, dynamic>>(
        '/auth/verify-email',
        data: {'token': token},
      );

      if (response.isSuccess && response.data != null) {
        return ApiResponse<VerificationResponse>.success(
          VerificationResponse.fromJson(response.data!),
          statusCode: response.statusCode,
          statusMessage: response.statusMessage,
          extra: response.extra,
        );
      } else {
        return ApiResponse<VerificationResponse>.error(
          response.error ?? 'Email verification failed',
          statusCode: response.statusCode,
          statusMessage: response.statusMessage,
          extra: response.extra,
        );
      }
    } catch (e) {
      return ApiResponse<VerificationResponse>.error(e.toString());
    }
  }

  /// Get current user profile
  Future<ApiResponse<Map<String, dynamic>>> getUserProfile() async {
    try {
      return await apiService.get<Map<String, dynamic>>('/users/profile');
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>.error(e.toString());
    }
  }
}
