/// Validation utility class with regex patterns
class Validators {
  // Email regex pattern
  // Validates standard email format: example@domain.com
  static final RegExp emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  // Phone regex pattern
  // First digit must be 6, 7, 8, or 9
  // Remaining 9 digits can be 0-9
  // Total: 10 digits
  static final RegExp phoneRegex = RegExp(
    r'^[6-9][0-9]{9}$',
  );

  /// Validate email address
  /// Returns error message if invalid, null if valid
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    
    return null;
  }

  /// Validate phone number
  /// Returns error message if invalid, null if valid
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    
    // Remove any spaces or special characters
    final cleanedPhone = value.replaceAll(RegExp(r'[^\d]'), '');
    
    if (!phoneRegex.hasMatch(cleanedPhone)) {
      return 'Enter a valid 10-digit phone number starting with 6, 7, 8, or 9';
    }
    
    return null;
  }

  /// Validate name (optional - for completeness)
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    
    return null;
  }

  /// Validate password (optional - for completeness)
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    
    return null;
  }
}
