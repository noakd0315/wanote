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

  /// Every keyword, in every language the app ships, checked on every
  /// message.
  ///
  /// Not switched on the current locale, deliberately: someone using the app
  /// in Japanese may still type "not breathing", and someone using it in
  /// English may type a word they know in Japanese. The cost of carrying
  /// both lists is a longer scan of one short string; the cost of picking
  /// the wrong list is missing an emergency.
  static const List<String> defaultKeywords = [
    ...japaneseKeywords,
    ...englishKeywords,
  ];

  /// Minimum set called out explicitly by spec 6.5 ("けいれん、意識がない、
  /// 誤飲 等") plus two additional high-urgency terms (ぐったり = collapsed
  /// /limp, 血を吐く = vomiting blood).
  static const List<String> japaneseKeywords = [
    'けいれん',
    '意識がない',
    '誤飲',
    'ぐったり',
    '血を吐く',
  ];

  /// The same emergencies in English, plus the ones a vet would put on any
  /// "come in now" list.
  ///
  /// Phrases rather than single words wherever a single word would be
  /// ambiguous. Matching ignores whitespace, so word boundaries are gone --
  /// "blood" alone would fire on "bloodwork", and "toxic" on "non-toxic".
  /// A false positive here costs an AI answer the owner did not get; a false
  /// negative costs them the one thing this check exists for. The list leans
  /// toward matching, but not so far that ordinary questions trip it.
  static const List<String> englishKeywords = [
    'seizure',
    'seizing',
    'convulsion',
    'unconscious',
    'unresponsive',
    'collapsed',
    'not breathing',
    'cannot breathe',
    "can't breathe",
    'difficulty breathing',
    'trouble breathing',
    'labored breathing',
    'laboured breathing',
    'choking',
    'swallowed',
    'ingested',
    'vomiting blood',
    'blood in vomit',
    'blood in stool',
    'bloated',
    'heatstroke',
    'heat stroke',
    'hit by a car',
    'poisoned',
    'poisoning',
    'xylitol',
    'antifreeze',
    'pale gums',
    "won't wake up",
    'will not wake up',
  ];

  // The emergency wording itself is not here. It lives in the l10n files
  // and is rendered by EmergencyNotice: a message this important must not
  // exist in only one language. A Japanese copy of it used to sit here,
  // unused, waiting to be picked up by mistake.

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
