import '../../../../core/constants/app_constants.dart';
import '../../../../services/api_service.dart';
import '../../../../services/auth_service.dart';
import '../models/comment.dart';
import '../../../../modules/user_management/models/user.dart';
import '../../reactions/models/reaction.dart';

class CommentsService {
  final ApiService _apiService;
  final AuthService _authService;

  CommentsService({
    required ApiService apiService,
    required AuthService authService,
  })  : _apiService = apiService,
        _authService = authService;

  String _getEndpoint(String postId, [String? commentId]) {
    final basePath = '${AppConstants.apiPrefix}/posts/$postId/comments';
    return commentId != null ? '$basePath/$commentId' : basePath;
  }

  String _getReactionEndpoint(String postId, String commentId) =>
      '${AppConstants.commentsBasePath}/$postId/comments/$commentId/like';

  Future<List<Comment>> getComments(String postId,
      {int skip = 0, int limit = 20}) async {
    try {
      final endpoint = _getEndpoint(postId);
      final queryParams = 'skip=$skip&limit=$limit';
      final response = await _apiService.get<dynamic>('$endpoint?$queryParams');

      if (response.isSuccess && response.data != null) {
        return _parseCommentsResponse(response.data);
      } else {
        throw Exception('Failed to fetch comments: ${response.error}');
      }
    } catch (e) {
      throw Exception('Error fetching comments: $e');
    }
  }

  List<Comment> _parseCommentsResponse(dynamic data) {
    try {
      if (data is Map<String, dynamic> && data.containsKey('comments')) {
        return _parseCommentsList(data['comments'] as List);
      } else if (data is List) {
        return _parseCommentsList(data);
      }
      throw Exception('Invalid response format');
    } catch (e) {
      throw Exception('Error parsing comments response: $e');
    }
  }

  List<Comment> _parseCommentsList(List<dynamic> commentsList) {
    return commentsList
        .where((json) => json != null)
        .map((json) {
          try {
            return Comment.safeFromJson(json as Map<String, dynamic>);
          } catch (e) {
            return null;
          }
        })
        .whereType<Comment>()
        .toList();
  }

  Future<Comment?> getLatestComment(String postId) async {
    try {
      final response = await _apiService.get<dynamic>(
        '${_getEndpoint(postId)}/latest',
      );

      if (response.isSuccess && response.data != null) {
        return _parseCommentResponse(response.data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Comment? _parseCommentResponse(dynamic data) {
    try {
      if (data is Map<String, dynamic>) {
        return Comment.safeFromJson(data);
      } else if (data is List && data.isNotEmpty && data.first != null) {
        return Comment.safeFromJson(data.first as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Comment> addComment(String postId, String content,
      {String? parentId}) async {
    try {
      _validateCurrentUser();

      final endpoint = '${AppConstants.commentsBasePath}/$postId/comments';

      final Map<String, dynamic> data = {
        'post_id': postId,
        'content': content,
      };

      if (parentId != null) {
        data['parent_id'] = parentId;
      }

      final response = await _apiService.post<dynamic>(endpoint, data: data);

      if (response.isSuccess) {
        final parsedComment = _parseCommentResponse(response.data);
        if (parsedComment != null) {
          return parsedComment;
        }

        return _createCommentWithCurrentUser(postId, content,
            parentId: parentId);
      } else {
        throw Exception('Failed to create comment: ${response.error}');
      }
    } catch (e) {
      throw Exception('Error adding comment: $e');
    }
  }

  void _validateCurrentUser() {
    if (_authService.currentUser == null) {
      throw Exception('You must be logged in to perform this action');
    }
  }

  Comment _createCommentWithCurrentUser(String postId, String content,
      {String? commentId, String? parentId, bool isEdited = false}) {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      throw Exception('Cannot create comment: You must be logged in');
    }

    final String fullName =
        currentUser.fullName.isNotEmpty ? currentUser.fullName : 'Current User';

    final String profilePicture = currentUser.hasValidProfilePicture
        ? (currentUser.profilePicture ?? '')
        : AppConstants.getAvatarFallbackUrl(fullName);

    final User completeUser = currentUser.copyWith(
        fullName: fullName, profilePicture: profilePicture);

    return Comment(
      id: commentId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      postId: postId,
      content: content,
      author: completeUser,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      likeCount: 0,
      hasLiked: false,
      parentId: parentId,
      repliesCount: 0,
      isEdited: isEdited,
    );
  }

  Future<Comment> editComment(
      String postId, String commentId, String content) async {
    try {
      final endpoint = _getEndpoint(postId, commentId);

      final response = await _apiService.put<dynamic>(
        endpoint,
        data: {'content': content},
      );

      if (response.isSuccess && response.data != null) {
        final parsedComment = _parseCommentResponse(response.data);
        if (parsedComment != null) {
          return parsedComment;
        }

        return _createCommentWithCurrentUser(postId, content,
            commentId: commentId, isEdited: true);
      } else {
        throw Exception('Failed to edit comment: ${response.error}');
      }
    } catch (e) {
      throw Exception('Error editing comment: $e');
    }
  }

  Future<bool> deleteComment(String postId, String commentId) async {
    try {
      final endpoint = _getEndpoint(postId, commentId);
      final response = await _apiService.delete<Map<String, dynamic>>(endpoint);
      return response.isSuccess;
    } catch (e) {
      throw Exception('Error deleting comment: $e');
    }
  }

  Future<bool> reactToComment(
      String postId, String commentId, ReactionType reactionType) async {
    try {
      final endpoint = _getReactionEndpoint(postId, commentId);
      final reactionTypeStr = reactionType.toString().split('.').last;

      final response = await _apiService.post<Map<String, dynamic>>(
        endpoint,
        data: {
          'reaction_type': reactionTypeStr,
          'post_id': postId,
          'comment_id': commentId
        },
      );

      return response.isSuccess;
    } catch (e) {
      throw Exception('Error reacting to comment: $e');
    }
  }

  Future<bool> likeComment(String postId, String commentId) async {
    return reactToComment(postId, commentId, ReactionType.like);
  }

  Future<bool> unlikeComment(String postId, String commentId) async {
    try {
      final endpoint = _getReactionEndpoint(postId, commentId);
      final response = await _apiService.delete<Map<String, dynamic>>(endpoint);
      return response.isSuccess;
    } catch (e) {
      throw Exception('Error unliking comment: $e');
    }
  }

  Future<bool> toggleCommentReaction(
      String postId, String commentId, ReactionType reactionType) async {
    try {
      final reactionTypeStr = reactionType.toString().split('.').last;
      final endpoint = _getReactionEndpoint(postId, commentId);

      final response = await _apiService.post<dynamic>(
        endpoint,
        data: {
          'reaction_type': reactionTypeStr,
          'post_id': postId,
          'comment_id': commentId
        },
      );

      return response.isSuccess;
    } catch (e) {
      return false;
    }
  }

  Future<bool> toggleLikeComment(String postId, String commentId) async {
    return toggleCommentReaction(postId, commentId, ReactionType.like);
  }
}
