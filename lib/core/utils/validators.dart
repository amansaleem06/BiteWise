/// Form field validators used across auth and profile flows.
abstract final class Validators {
  static final RegExp _email = RegExp(r'^[\w\.\-+]+@([\w-]+\.)+[\w-]{2,}$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required';
    if (!_email.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != original) return 'Passwords do not match';
    return null;
  }

  static String? phone(String? value) {
    final v = value?.trim() ?? '';
    if (v.length < 7) return 'Enter a valid phone number';
    if (v.length > 24) return 'Phone number is too long';
    return null;
  }

  static String? address(String? value) {
    final v = value?.trim() ?? '';
    if (v.length < 6) return 'Enter the business street address';
    if (v.length > 160) return 'Address is too long';
    return null;
  }

  static String? displayName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Name is required';
    if (v.length < 2) return 'Name is too short';
    if (v.length > 50) return 'Name is too long';
    return null;
  }
}
