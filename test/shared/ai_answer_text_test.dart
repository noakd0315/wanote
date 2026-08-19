import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanote/shared/widgets/ai_answer_text.dart';

/// The answer that was actually on screen when this was reported
/// (PM, 2026-08-19), markers and all.
const _reportedAnswer = '''
# 食事配分についてのご質問ですね

体重4.8kgの成犬であれば、114g/日を**2〜3回に分けて与える**ことをお勧めします。

**配分例：**
- 2回食：朝57g、夜57g
- 3回食：朝38g、昼38g、夜38g
''';

void main() {
  const base = TextStyle(fontSize: 14);
  const heading = TextStyle(fontSize: 16, fontWeight: FontWeight.bold);

  String rendered(String source) => aiAnswerPlainText(source);

  List<InlineSpan> spansOf(String source) =>
      buildAiAnswerSpans(source, baseStyle: base, headingStyle: heading);

  group('aiAnswerPlainText', () {
    test('leaves no marker from the reported answer on screen', () {
      final text = rendered(_reportedAnswer);
      expect(text, isNot(contains('#')));
      expect(text, isNot(contains('**')));
      expect(text, contains('食事配分についてのご質問ですね'));
      expect(text, contains('2〜3回に分けて与える'));
      expect(text, contains('配分例：'));
    });

    test('turns list markers into bullets, keeping the item text', () {
      expect(rendered('- 2回食：朝57g、夜57g'), '・2回食：朝57g、夜57g');
      expect(rendered('* ノミ・ダニ'), '・ノミ・ダニ');
      expect(rendered('1. まず体重を測る'), '1. まず体重を測る');
    });

    test('keeps blank lines, so paragraphs stay apart', () {
      expect(rendered('a\n\nb'), 'a\n\nb');
    });

    test('leaves text it does not recognise exactly as written', () {
      // An unclosed marker is shown rather than guessed at -- the same
      // thing the screens did before, and better than mangling the answer.
      expect(rendered('体重は4.8kg**です'), '体重は4.8kg**です');
      expect(rendered('C:\\Dev\\wanote'), r'C:\Dev\wanote');
      expect(rendered('---'), '---');
    });

    test('does not treat an emphasised word at line start as a bullet', () {
      expect(rendered('*注意*してください'), '注意してください');
    });
  });

  group('buildAiAnswerSpans', () {
    TextStyle styleOfFirstMatch(String source, String text) {
      final span = spansOf(source).whereType<TextSpan>().firstWhere(
        (s) => s.text == text,
      );
      return span.style!;
    }

    test('renders a heading in the heading style', () {
      expect(styleOfFirstMatch('# 見出し', '見出し'), heading);
    });

    test('renders **bold** bold, and drops the markers', () {
      final style = styleOfFirstMatch('これは**太字**です', '太字');
      expect(style.fontWeight, FontWeight.bold);
      expect(style.fontSize, base.fontSize);
    });

    test('renders ***bold italic*** as both', () {
      final style = styleOfFirstMatch('***強調***', '強調');
      expect(style.fontWeight, FontWeight.bold);
      expect(style.fontStyle, FontStyle.italic);
    });

    test('leaves the surrounding text unstyled', () {
      final style = styleOfFirstMatch('これは**太字**です', 'これは');
      expect(style.fontWeight, isNot(FontWeight.bold));
    });
  });

  testWidgets('AiAnswerText shows the answer without its markers', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AiAnswerText(_reportedAnswer))),
    );

    final richText = tester.widget<RichText>(find.byType(RichText).first);
    final shown = richText.text.toPlainText();
    expect(shown, isNot(contains('**')));
    expect(shown, contains('食事配分についてのご質問ですね'));
  });
}
