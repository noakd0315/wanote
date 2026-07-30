/// Matches the `auth_provider` enum defined in
/// docs/dog_health_app_spec.md section 1.3.
enum AuthProviderType {
  email,
  apple,
  google;

  String get wireName => name;

  static AuthProviderType fromWireName(String value) {
    return AuthProviderType.values.firstWhere(
      (e) => e.wireName == value,
      orElse: () => AuthProviderType.email,
    );
  }
}
