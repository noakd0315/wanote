/// Pure, framework-free detector for the "call the vet right now" branch
/// described in spec section 6.5: certain high-urgency keywords must short
/// -circuit the whole AI consultation flow *before* any backend/API call is
/// made — no network round-trip, no token spend, just an immediate fixed
/// message.
///
/// Kept dependency-free (no Flutter, no Firebase) so it's trivially unit
/// testable and can also be reused server-side later if needed.
class EmergencyKeywordDetector {
  const EmergencyKeywordDetector({List<String>? keywords})
    : _keywords = keywords ?? defaultKeywords;

  /// Minimum set called out explicitly by spec 6.5 ("けいれん、意識がない、
  /// 誤飲 等") plus two additional high-urgency terms that seem reasonable
  /// to include out of the gate (ぐったり = collapsed/limp, 血を吐く =
  /// vomiting blood). Extend this list freely — it's a plain constant, not
  /// baked into any control flow.
  static const List<String> defaultKeywords = [
    'けいれん',
    '意識がない',
    '誤飲',
    'ぐったり',
    '血を吐く',
  ];

  /// Fixed message shown instead of calling the AI backend, per spec 6.5:
  /// "AI回答より先に「至急動物病院へ」という定型メッセージを優先表示する".
  static const String emergencyMessage =
      '至急動物病院へ連絡・受診してください。\n'
      'この内容は緊急性が高い可能性があるため、AIによる回答はスキップし、'
      'すぐに動物病院に相談することをおすすめします。';

  final List<String> _keywords;

  static final RegExp _whitespace = RegExp('[\\s　]+');

  String _normalize(String input) =>
      input.replaceAll(_whitespace, '').toLowerCase();

  /// True if [text] contains any configured emergency keyword. Whitespace
  /// (including full-width spaces) and case are normalized away first, so
  /// e.g. "けい れん" or mixed-case ASCII variants still match; this does
  /// not attempt kana/kanji fuzzy matching.
  bool isEmergency(String text) {
    if (text.trim().isEmpty) return false;
    final normalized = _normalize(text);
    return _keywords.any((keyword) => normalized.contains(_normalize(keyword)));
  }
}
