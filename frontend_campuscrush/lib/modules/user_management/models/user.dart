import '../../../core/constants/app_constants.dart';

class User {
  final String id;
  final String username;
  final String email;
  final String fullName;
  final String university;
  final String? bio;
  final String? profilePicture;
  final String? department;
  final String? graduationYear;
  final DateTime createdAt;
  final DateTime updatedAt;

  const User({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    required this.university,
    this.bio,
    this.profilePicture,
    this.department,
    this.graduationYear,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Returns the first name based on the full name
  String get firstName {
    final nameParts = fullName.split(' ');
    return nameParts.isNotEmpty ? nameParts.first : '';
  }

  /// Returns the last name based on the full name
  String get lastName {
    final nameParts = fullName.split(' ');
    return nameParts.length > 1 ? nameParts.skip(1).join(' ') : '';
  }

  /// Returns the initials of the user's name
  String get initials {
    if (fullName.isEmpty) return '';

    final nameParts = fullName.split(' ');
    if (nameParts.isEmpty) return '';

    if (nameParts.length == 1) {
      return nameParts[0].isNotEmpty ? nameParts[0][0].toUpperCase() : '';
    }

    final first = nameParts[0].isNotEmpty ? nameParts[0][0] : '';
    final last = nameParts.last.isNotEmpty ? nameParts.last[0] : '';

    return '$first$last'.toUpperCase();
  }

  /// Returns true if the profile picture URL is a localhost URL
  bool get hasLocalProfilePicture =>
      profilePicture != null && AppConstants.isLocalUrl(profilePicture!);

  /// Returns true if the profile picture URL is valid and usable
  bool get hasValidProfilePicture =>
      profilePicture != null &&
      AppConstants.isProfilePictureValid(profilePicture!);

  /// Returns a safe, usable profile picture URL or null
  String? get safeProfilePictureUrl => (profilePicture?.isNotEmpty ?? false)
      ? AppConstants.fixProfilePictureUrl(profilePicture!)
      : null;

  /// Creates a UI Avatar fallback URL for the user
  String get fallbackAvatarUrl => AppConstants.getAvatarFallbackUrl(fullName);

  factory User.fromJson(Map<String, dynamic> json) {
    try {
      // Extract and validate essential fields
      final String id = json['id']?.toString() ?? '';
      final String validId = id.isEmpty
          ? 'unknown-id-${DateTime.now().millisecondsSinceEpoch}'
          : id;

      final String? username = json['username']?.toString();
      final String? rawFullName = json['full_name']?.toString();

      // Determine fullName with fallbacks
      String fullName = rawFullName?.trim() ?? '';
      if (fullName.isEmpty) {
        fullName = username?.isNotEmpty == true ? username! : 'User';
      }

      // Process profile picture
      String? profilePicture = json['profile_picture']?.toString();
      if (profilePicture?.isEmpty ?? true) {
        profilePicture = AppConstants.getAvatarFallbackUrl(fullName);
      }

      return User(
        id: validId,
        username: username ?? 'user_$validId',
        email: json['email']?.toString() ?? '',
        fullName: fullName,
        university: json['university']?.toString() ?? 'Unknown University',
        bio: json['bio']?.toString(),
        profilePicture: profilePicture,
        department: json['department']?.toString(),
        graduationYear: json['graduation_year']?.toString(),
        createdAt: _parseDateTime(json['created_at']),
        updatedAt: _parseDateTime(json['updated_at']),
      );
    } catch (e) {
      // Create fallback user with available information
      final String id = json['id']?.toString() ??
          'error-${DateTime.now().millisecondsSinceEpoch}';
      final String username = json['username']?.toString() ?? 'user_$id';
      String fullName = json['full_name']?.toString() ?? '';

      if (fullName.isEmpty) {
        fullName = username.isNotEmpty ? username : 'User $id';
      }

      return User(
        id: id,
        username: username,
        email: json['email']?.toString() ?? '',
        fullName: fullName,
        university: 'Unknown University',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return DateTime.now();
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'full_name': fullName,
      'university': university,
      'bio': bio,
      'profile_picture': profilePicture,
      'department': department,
      'graduation_year': graduationYear,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  User copyWith({
    String? id,
    String? username,
    String? email,
    String? fullName,
    String? university,
    String? bio,
    String? profilePicture,
    String? department,
    String? graduationYear,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      university: university ?? this.university,
      bio: bio ?? this.bio,
      profilePicture: profilePicture ?? this.profilePicture,
      department: department ?? this.department,
      graduationYear: graduationYear ?? this.graduationYear,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
