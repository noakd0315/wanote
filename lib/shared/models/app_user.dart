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
    this.activeSessionId,
  });

  final String uid;
  final String email;
  final AuthProviderType authProvider;
  final bool biometricEnabled;

  /// Random id claimed by whichever device most recently signed in (PM
  /// report: multiple devices could stay signed in to the same account at
  /// once, which shouldn't be allowed). Compared against each device's own
  /// locally-stored copy so a device can tell when a *different* device has
  /// taken over the account and sign itself out -- see
  /// AuthController._subscribeToSession's doc comment for the full flow.
  final String? activeSessionId;

  AppUser copyWith({bool? biometricEnabled, String? activeSessionId}) {
    return AppUser(
      uid: uid,
      email: email,
      authProvider: authProvider,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      activeSessionId: activeSessionId ?? this.activeSessionId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': uid,
      'email': email,
      'auth_provider': authProvider.wireName,
      'biometric_enabled': biometricEnabled,
      'active_session_id': activeSessionId,
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
      activeSessionId: map['active_session_id'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    uid,
    email,
    authProvider,
    biometricEnabled,
    activeSessionId,
  ];
}
