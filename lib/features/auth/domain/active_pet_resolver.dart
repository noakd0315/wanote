/// Pure "which pet is active" decision for the multi-pet household feature
/// (spec 1.4 — 多頭飼い対応：1アカウントで複数ペットプロフィールを切り替え).
///
/// Kept framework-free (no Firestore/shared_preferences here) so it's
/// trivially unit-testable; `AuthController` is the only caller and is
/// responsible for persisting the result (see
/// lib/features/auth/presentation/auth_controller.dart).
class ActivePetResolver {
  const ActivePetResolver();

  /// Decides which pet id should be active given the current [petIds] for
  /// the account and the [previousActiveId] (typically loaded from a
  /// device-local preference, or the previously-active pet held in memory).
  ///
  /// Rules:
  /// - If [previousActiveId] is still present in [petIds], keep it.
  /// - Otherwise fall back to the first pet in [petIds] (covers both "the
  ///   previously active pet was deleted" and "this is the very first
  ///   load, nothing persisted yet").
  /// - If [petIds] is empty, there is no active pet.
  String? resolve({
    required List<String> petIds,
    required String? previousActiveId,
  }) {
    if (previousActiveId != null && petIds.contains(previousActiveId)) {
      return previousActiveId;
    }
    if (petIds.isNotEmpty) {
      return petIds.first;
    }
    return null;
  }
}
