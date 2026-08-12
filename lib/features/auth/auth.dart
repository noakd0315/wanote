/// Public API surface for the auth feature. Other features/main.dart should
/// only import this barrel, never files under lib/features/auth/**
/// directly, so the feature's internal layout can change without breaking
/// callers (per wanote/.claude/CLAUDE.md's directory-ownership rule).
library;

// Shared models re-exported for convenience so callers do not need a
// separate import for the account/pet shapes they will receive back from
// AuthController.
export '../../shared/models/models.dart';

// Data layer (exposed mainly so main.dart can construct concrete
// repositories to inject into AuthController; screens should not need
// these directly).
export 'data/account_backend_client.dart';
export 'data/account_deletion_service.dart';
export 'data/account_document_eraser.dart';
export 'data/account_file_eraser.dart';
export 'data/auth_repository.dart';
export 'data/biometric_service.dart';
export 'data/pet_profile_repository.dart';
export 'data/user_account_repository.dart';

// Pure domain logic (unit-tested independently under test/features/auth/).
export 'domain/active_pet_resolver.dart';
export 'domain/auth_gate_resolver.dart';
export 'domain/biometric_fallback_resolver.dart';

// Presentation layer.
export 'presentation/auth_controller.dart';
export 'presentation/screens/account_deletion_screen.dart';
export 'presentation/screens/biometric_setup_screen.dart';
export 'presentation/screens/launch_gate_screen.dart';
export 'presentation/screens/pet_profile_form_screen.dart';
export 'presentation/screens/pet_profile_switch_screen.dart';
export 'presentation/screens/sign_up_screen.dart';
