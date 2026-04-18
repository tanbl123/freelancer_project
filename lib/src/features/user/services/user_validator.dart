/// Static validation helpers for all user-related form fields.
/// Used by both service layer and form validators in screens.
class UserValidator {
  UserValidator._();

  static String? validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    final re = RegExp(r'^[\w.+\-]+@[\w\-]+\.[a-zA-Z]{2,}$');
    if (!re.hasMatch(v.trim())) return 'Enter a valid email address';
    return null;
  }

  static String? validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'At least 8 characters required';
    if (!RegExp(r'[A-Z]').hasMatch(v)) {
      return 'Include at least one uppercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(v)) {
      return 'Include at least one number';
    }
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]').hasMatch(v)) {
      return 'Include at least one special character';
    }
    return null;
  }

  static String? validateConfirmPassword(String? v, String original) {
    if (v == null || v.isEmpty) return 'Please confirm your password';
    if (v != original) return 'Passwords do not match';
    return null;
  }

  static String? validateDisplayName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Name is required';
    if (v.trim().length < 2) return 'At least 2 characters required';
    if (!RegExp(r"^[\p{L}\s'\-\.]+$", unicode: true).hasMatch(v.trim())) {
      return 'Name may only contain letters, spaces, hyphens or apostrophes';
    }
    return null;
  }

  static String? validatePhone(String? v) {
    if (v == null || v.trim().isEmpty) return null; // optional
    final digits = v.trim().replaceAll(RegExp(r'[\s\-()]'), '');
    if (!RegExp(r'^\+?[0-9]{9,15}$').hasMatch(digits)) {
      return 'Enter a valid phone number (e.g. 0123456789)';
    }
    return null;
  }

  static String? validateRequired(String? v, String fieldName) {
    if (v == null || v.trim().isEmpty) return '$fieldName is required';
    return null;
  }

  static String? validateUrl(String? v) {
    if (v == null || v.trim().isEmpty) return null; // optional
    final re = RegExp(r'^https?://[\w\-]+(\.[\w\-]+)+([\w\-._~:/?#\[\]@!$&()*+,;=%])*$');
    if (!re.hasMatch(v.trim())) return 'Enter a valid URL (starting with http:// or https://)';
    return null;
  }
}
