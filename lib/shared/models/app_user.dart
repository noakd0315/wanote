import 'package:equatable/equatable.dart';

import 'auth_provider_type.dart';

/// Mirrors the account-level fields from spec section 1.3 (user_id, email,
/// auth_provider, biometric_enabled). Pet profiles are modeled separately in
/// [PetProfile] since one account can hold multiple pets.
class AppUser extends Equatable {
  const AppUser({
    required this.uid,
    required this.email,
    required this.authProvider,
    required this.biometricEnabled,
  });

  final String uid;
  final String email;
  final AuthProviderType authProvider;
  final bool biometricEnabled;

  AppUser copyWith({bool? biometricEnabled}) {
    return AppUser(
      uid: uid,
      email: email,
      authProvider: authProvider,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': uid,
      'email': email,
      'auth_provider': authProvider.wireName,
      'biometric_enabled': biometricEnabled,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['user_id'] as String,
      email: map['email'] as String? ?? '',
      authProvider: AuthProviderType.fromWireName(
        map['auth_provider'] as String? ?? 'email',
      ),
      biometricEnabled: map['biometric_enabled'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [uid, email, authProvider, biometricEnabled];
}
