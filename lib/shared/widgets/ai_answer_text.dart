import 'package:flutter/material.dart';

/// The Markdown the model actually writes: ATX headings, `***`/`**`/`*`
/// emphasis, inline code, and `-`/`*`/`+`/`1.` list items.
///
/// Anything not matched here is left exactly as it was typed, which is the
/// behaviour every one of these screens had before.
final RegExp _headingPattern = RegExp(r'^ {0,3}(#{1,6})\s+(.*)$');
final RegExp _bulletPattern = RegExp(r'^(\s*)[-*+]\s+(.*)$');
final RegExp _numberedPattern = RegExp(r'^(\s*)(\d{1,3})[.)]\s+(.*)$');
final RegExp _emphasisPattern = RegExp(
  r'\*\*\*(.+?)\*\*\*|\*\*(.+?)\*\*|\*(.+?)\*|`(.+?)`',
);

/// Turns one AI answer into styled spans.
///
/// Exposed for tests: the interesting behaviour is the parse, and it needs
/// no widget tree to check.
@visibleForTesting
List<InlineSpan> buildAiAnswerSpans(
  String text, {
  required TextStyle baseStyle,
  required TextStyle headingStyle,
}) {
  final spans = <InlineSpan>[];
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    if (i > 0) spans.add(TextSpan(text: '\n', style: baseStyle));
    spans.addAll(_lineSpans(lines[i], baseStyle, headingStyle));
  }
  return spans;
}

/// The same answer with every marker resolved away and no styling.
///
/// For the places that show a truncated preview: a three-line snippet in a
/// list is worse, not better, for having a heading rendered at heading size
/// inside it -- but it should not show `#` either.
String aiAnswerPlainText(String text) {
  const plain = TextStyle();
  final spans = buildAiAnswerSpans(
    text,
    baseStyle: plain,
    headingStyle: plain,
  );
  final buffer = StringBuffer();
  for (final span in spans) {
    if (span is TextSpan) buffer.write(span.text ?? '');
  }
  return buffer.toString();
}

List<InlineSpan> _lineSpans(String line, TextStyle base, TextStyle heading) {
  final headingMatch = _headingPattern.firstMatch(line);
  if (headingMatch != null) {
    return _inlineSpans(headingMatch.group(2)!, heading);
  }

  final bulletMatch = _bulletPattern.firstMatch(line);
  if (bulletMatch != null) {
    return <InlineSpan>[
      TextSpan(text: '${bulletMatch.group(1)}・', style: base),
      ..._inlineSpans(bulletMatch.group(2)!, base),
    ];
  }

  final numberedMatch = _numberedPattern.firstMatch(line);
  if (numberedMatch != null) {
    return <InlineSpan>[
      TextSpan(
        text: '${numberedMatch.group(1)}${numberedMatch.group(2)}. ',
        style: base,
      ),
      ..._inlineSpans(numberedMatch.group(3)!, base),
    ];
  }

  return _inlineSpans(line, base);
}

List<InlineSpan> _inlineSpans(String text, TextStyle style) {
  final spans = <InlineSpan>[];
  var index = 0;
  for (final match in _emphasisPattern.allMatches(text)) {
    if (match.start > index) {
      spans.add(
        TextSpan(text: text.substring(index, match.start), style: style),
      );
    }
    final boldItalic = match.group(1);
    final bold = match.group(2);
    final italic = match.group(3);
    final code = match.group(4);
    if (boldItalic != null) {
      spans.add(
        TextSpan(
          text: boldItalic,
          style: style.copyWith(
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    } else if (bold != null) {
      spans.add(
        TextSpan(
          text: bold,
          style: style.copyWith(fontWeight: FontWeight.bold),
        ),
      );
    } else if (italic != null) {
      spans.add(
        TextSpan(
          text: italic,
          style: style.copyWith(fontStyle: FontStyle.italic),
        ),
      );
    } else {
      spans.add(
        TextSpan(text: code, style: style.copyWith(fontFamily: 'monospace')),
      );
    }
    index = match.end;
  }
  if (index < text.length) {
    spans.add(TextSpan(text: text.substring(index), style: style));
  }
  return spans;
}

/// An AI answer, rendered rather than shown raw.
///
/// The model writes Markdown, and all three AI screens put that string
/// straight into a [Text] -- so owners read `**配分例：**` and
/// `# 食事配分についてのご質問ですね` with the markers intact (PM report,
/// 2026-08-19). It is the app's differentiating feature and it looked
/// broken.
///
/// The markers are rendered, not stripped. The answers genuinely do have
/// headings, emphasis and lists, and they read better with that structure
/// than flattened.
///
/// Hand-rolled instead of a package: `flutter_markdown` was discontinued in
/// 2025, and the alternatives bring a whole CommonMark implementation for a
/// subset whose producer we control. Anything unrecognised falls through
/// verbatim, so the worst case is what the screens already did.
///
/// One span tree, not a column of paragraphs, so a selection can run across
/// the whole answer -- the consultation history depends on that (advice
/// worth keeping is worth copying into a message to the clinic).
class AiAnswerText extends StatelessWidget {
  const AiAnswerText(this.text, {super.key, this.selectable = false});

  final String text;

  /// Whether the reader can select and copy the answer.
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final baseStyle =
        Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    final headingStyle = baseStyle.copyWith(
      fontWeight: FontWeight.bold,
      fontSize: (baseStyle.fontSize ?? 14) * 1.1,
    );
    final span = TextSpan(
      children: buildAiAnswerSpans(
        text,
        baseStyle: baseStyle,
        headingStyle: headingStyle,
      ),
    );
    return selectable ? SelectableText.rich(span) : Text.rich(span);
  }
}
