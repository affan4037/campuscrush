/// Utility class providing form field validation methods
class Validators {
  // Private constructor to prevent instantiation
  Validators._();

  // Regular expression constants for improved performance (compiled once)
  static final RegExp _emailRegExp =
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
  static final RegExp _usernameRegExp = RegExp(r'^[a-zA-Z0-9_]+$');

  // Validation constants
  static const int _minUsernameLength = 3;
  static const int _maxUsernameLength = 20;
  static const int _minNameLength = 2;
  static const int _maxPostLength = 1000;
  static const int _maxCommentLength = 500;
  static const int _maxFutureYears = 6;
  static const String _allowedEmailDomain = 'gmail.com';

  // Error messages
  static const String _requiredField = 'is required';
  static const String _minLengthError = 'must be at least';
  static const String _maxLengthError = 'must be less than';
  static const String _charactersText = 'characters';

  // Core validation methods
  static String? required(String? value, String fieldName) {
    return value == null || value.trim().isEmpty
        ? '$fieldName $_requiredField'
        : null;
  }

  static String? minLength(String value, int minLength, String fieldName) {
    return value.length < minLength
        ? '$fieldName $_minLengthError $minLength $_charactersText long'
        : null;
  }

  static String? maxLength(String value, int maxLength, String fieldName) {
    return value.length > maxLength
        ? '$fieldName $_maxLengthError $maxLength $_charactersText'
        : null;
  }

  /// Validates email format and domain restrictions
  static String? validateEmail(String? value) {
    final requiredCheck = required(value, 'Email');
    if (requiredCheck != null) return requiredCheck;

    final normalizedValue = value!.trim();
    if (!_emailRegExp.hasMatch(normalizedValue)) {
      return 'Enter a valid email address';
    }

    final domain = normalizedValue.split('@').last.toLowerCase();
    if (domain != _allowedEmailDomain) {
      return 'Only Gmail accounts are allowed. Please use a Gmail address.';
    }

    return null;
  }

  /// Validates username format and length requirements
  static String? validateUsername(String? value) {
    final requiredCheck = required(value, 'Username');
    if (requiredCheck != null) return requiredCheck;

    final normalizedValue = value!.trim();

    final lengthCheck =
        minLength(normalizedValue, _minUsernameLength, 'Username');
    if (lengthCheck != null) return lengthCheck;

    if (normalizedValue.length > _maxUsernameLength) {
      return 'Username must be less than $_maxUsernameLength characters long';
    }

    if (!_usernameRegExp.hasMatch(normalizedValue)) {
      return 'Username can only contain letters, numbers, and underscores';
    }

    return null;
  }

  // Personal information validators
  static String? validateFullName(String? value) {
    final requiredCheck = required(value, 'Full name');
    if (requiredCheck != null) return requiredCheck;

    return minLength(value!.trim(), _minNameLength, 'Full name');
  }

  static String? validateUniversity(String? value) {
    final requiredCheck = required(value, 'University');
    if (requiredCheck != null) return requiredCheck;

    return minLength(value!.trim(), _minNameLength, 'University name');
  }

  static String? validateDepartment(String? value) {
    final requiredCheck = required(value, 'Department');
    if (requiredCheck != null) return requiredCheck;

    return minLength(value!.trim(), _minNameLength, 'Department name');
  }

  /// Validates that graduation year is within acceptable range
  static String? validateGraduationYear(String? value) {
    final requiredCheck = required(value, 'Graduation year');
    if (requiredCheck != null) return requiredCheck;

    final normalizedValue = value!.trim();
    final int? year = int.tryParse(normalizedValue);
    if (year == null) {
      return 'Please enter a valid year';
    }

    final int currentYear = DateTime.now().year;
    if (year < currentYear) {
      return 'Graduation year cannot be in the past';
    }

    if (year > currentYear + _maxFutureYears) {
      return 'Graduation year cannot be more than $_maxFutureYears years in the future';
    }

    return null;
  }

  // Content validators
  static String? validatePostContent(String? value) {
    final requiredCheck = required(value, 'Post content');
    if (requiredCheck != null) return requiredCheck;

    return maxLength(value!.trim(), _maxPostLength, 'Post content');
  }

  static String? validateCommentContent(String? value) {
    final requiredCheck = required(value, 'Comment content');
    if (requiredCheck != null) return requiredCheck;

    return maxLength(value!.trim(), _maxCommentLength, 'Comment');
  }

  /// Validates password strength and requirements
  static String? validatePassword(String? value) {
    final requiredCheck = required(value, 'Password');
    if (requiredCheck != null) return requiredCheck;

    final normalizedValue = value!.trim();

    if (normalizedValue.length < 8) {
      return 'Password must be at least 8 characters long';
    }

    if (!normalizedValue.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }

    if (!normalizedValue.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }

    if (!normalizedValue.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }

    if (!normalizedValue.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Password must contain at least one special character';
    }

    return null;
  }

  /// Validates that password confirmation matches the original password
  static String? validateConfirmPassword(String? value, String password) {
    final requiredCheck = required(value, 'Password confirmation');
    if (requiredCheck != null) return requiredCheck;

    if (value != password) {
      return 'Passwords do not match';
    }

    return null;
  }
}
