import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../models/reaction.dart';
import '../../../../services/api_service.dart';
import '../../../../services/auth_service.dart';

class ReactionProvider extends ChangeNotifier {
  final ApiService _apiService;
  final AuthService _authService;
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  List<Reaction> _reactions = [];
  final Map<String, List<Map<String, dynamic>>> _reactionCounts = {};

  ReactionProvider(
      {required ApiService apiService, required AuthService authService})
      : _apiService = apiService,
        _authService = authService;

  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String get errorMessage => _errorMessage;
  List<Reaction> get reactions => List.unmodifiable(_reactions);
  Map<String, List<Map<String, dynamic>>> get reactionCounts =>
      Map.unmodifiable(_reactionCounts);

  Future<void> fetchReactions(String postId,
      {int skip = 0, int limit = 100}) async {
    _setLoading(true);

    try {
      final response = await _apiService.get<List<dynamic>>(
        '/posts/$postId/reactions',
        queryParameters: {
          'skip': skip,
          'limit': limit,
        },
      );

      if (response.isSuccess && response.data != null) {
        _reactions = response.data!
            .map((item) => Reaction.fromJson(item as Map<String, dynamic>))
            .toList();
        _setError(false, '');
      } else {
        _setError(true, response.error ?? 'Failed to fetch reactions');
      }
    } catch (e) {
      _setError(true, e.toString());
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> fetchReactionCounts(String postId) async {
    _setLoading(true);

    try {
      final response = await _apiService.get<List<dynamic>>(
        '/posts/$postId/reactions/counts',
      );

      if (response.isSuccess && response.data != null) {
        final counts = response.data!.cast<Map<String, dynamic>>();
        _reactionCounts[postId] = counts;
        _setError(false, '');
      } else {
        _setError(true, response.error ?? 'Failed to fetch reaction counts');
      }
    } catch (e) {
      _setError(true, e.toString());
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<Reaction?> createOrUpdateReaction(
      String postId, ReactionType reactionType) async {
    _setLoading(true);

    try {
      final reactionTypeStr = reactionType.toString().split('.').last;
      final data = {
        'reaction_type': reactionTypeStr,
        'post_id': postId,
      };

      final currentUserId = _authService.currentUser?.id;
      final existingReaction = _findUserReactionForPost(postId, currentUserId);
      final isUpdating =
          existingReaction != null && existingReaction.id.isNotEmpty;

      final options = _createAuthOptions();

      final response = await _apiService.post<Map<String, dynamic>>(
        '/posts/$postId/reactions',
        data: data,
        options: options,
      );

      if (response.isSuccess && response.data != null) {
        final newReaction = Reaction.fromJson(response.data!);
        _updateLocalReactions(newReaction, isUpdating);
        await fetchReactionCounts(postId);
        _setError(false, '');
        return newReaction;
      } else {
        _setError(true, response.error ?? 'Failed to create reaction');
        return null;
      }
    } catch (e) {
      _setError(true, e.toString());
      return null;
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<bool> deleteReaction(String postId) async {
    _setLoading(true);

    try {
      final currentUserId = _authService.currentUser?.id;
      if (currentUserId == null) {
        _setError(true, 'User not authenticated');
        return false;
      }

      final hasReaction = _reactions
          .any((r) => r.userId == currentUserId && r.postId == postId);

      if (!hasReaction) {
        _removeUserReactionFromLocal(postId, currentUserId);
        _setError(false, '');
        return true;
      }

      final options = _createAuthOptions();
      final endpoint = '/posts/$postId/reactions';

      final response = await _apiService.delete<Map<String, dynamic>>(
        endpoint,
        options: options,
      );

      final isSuccess = response.isSuccess || response.statusCode == 404;

      if (isSuccess) {
        _removeUserReactionFromLocal(postId, currentUserId);
        await fetchReactionCounts(postId);
        _setError(false, '');
        return true;
      } else {
        _setError(true, response.error ?? 'Failed to delete reaction');
        return false;
      }
    } catch (e) {
      _setError(true, e.toString());
      return false;
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  bool hasUserReacted(String postId, String userId) {
    return _reactions.any((r) => r.postId == postId && r.userId == userId);
  }

  ReactionType? getUserReactionType(String postId, String userId) {
    final reaction = _findUserReactionForPost(postId, userId);
    return reaction?.id.isNotEmpty == true ? reaction!.type : null;
  }

  // Helper methods
  Options _createAuthOptions() {
    final authToken = _authService.token;
    return Options(
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (authToken != null && authToken.isNotEmpty)
          'Authorization': 'Bearer $authToken',
      },
    );
  }

  Reaction? _findUserReactionForPost(String postId, String? userId) {
    if (userId == null) return null;

    try {
      return _reactions.firstWhere(
        (r) => r.userId == userId && r.postId == postId,
      );
    } catch (_) {
      return null;
    }
  }

  void _updateLocalReactions(Reaction newReaction, bool isUpdating) {
    if (isUpdating) {
      final existingIndex = _reactions.indexWhere((r) =>
          r.userId == newReaction.userId && r.postId == newReaction.postId);

      if (existingIndex != -1) {
        _reactions[existingIndex] = newReaction;
      } else {
        _reactions.add(newReaction);
      }
    } else {
      _reactions.add(newReaction);
    }
  }

  void _removeUserReactionFromLocal(String postId, String userId) {
    _reactions.removeWhere(
        (reaction) => reaction.userId == userId && reaction.postId == postId);
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
  }

  void _setError(bool hasError, String message) {
    _hasError = hasError;
    _errorMessage = message;
  }

  void clearErrors() {
    _hasError = false;
    _errorMessage = '';
    notifyListeners();
  }
}
