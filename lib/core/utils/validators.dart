/// Form field validators shared by forms and the authentication repository.
abstract final class Validators {
  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required';
    if (v.length > 254) return 'Enter a valid email address';
    final parts = v.split('@');
    if (parts.length != 2) return 'Enter a valid email address';
    final local = parts[0];
    final labels = parts[1].split('.');
    final localPattern = RegExp(r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+$");
    final labelPattern = RegExp(r'^[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?$');
    if (local.isEmpty ||
        local.length > 64 ||
        !localPattern.hasMatch(local) ||
        local.startsWith('.') ||
        local.endsWith('.') ||
        local.contains('..') ||
        labels.length < 2 ||
        labels.any(
          (label) =>
              label.isEmpty ||
              label.length > 63 ||
              !labelPattern.hasMatch(label),
        ) ||
        !RegExp(r'^[a-zA-Z]{2,}$').hasMatch(labels.last)) {
      return 'Enter a valid email address';
    }
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

  static String? optionalPhone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    return phone(v);
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
