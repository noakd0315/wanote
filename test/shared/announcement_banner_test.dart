import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wanote/l10n/generated/app_localizations.dart';
import 'package:wanote/shared/models/announcement.dart';
import 'package:wanote/shared/services/announcement_repository.dart';
import 'package:wanote/shared/widgets/announcement_banner.dart';

class _FakeRepository implements AnnouncementRepository {
  _FakeRepository(this.announcements);

  final List<Announcement> announcements;

  @override
  Stream<List<Announcement>> watchVisible() => Stream.value(announcements);
}

class _FailingRepository implements AnnouncementRepository {
  @override
  Stream<List<Announcement>> watchVisible() =>
      Stream.error(Exception('offline'));
}

/// The banner shown above every section.
///
/// Most of what it does is stay out of the way: it sits on top of the whole
/// app, so anything that makes it render when it has nothing to say -- a
/// loading frame, an empty card, an error -- is a permanent strip of noise
/// on every screen.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Announcement announcement({
    String id = 'a1',
    String titleJa = 'サポート休止のお知らせ',
    bool important = false,
  }) => Announcement(
    id: id,
    titleJa: titleJa,
    bodyJa: '8/13〜8/20 はお問い合わせに対応できません。',
    publishedAt: DateTime(2026, 8, 1),
    important: important,
  );

  Future<void> pump(
    WidgetTester tester, {
    required AnnouncementRepository repository,
    bool importantOnly = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AnnouncementBanner(
            repository: repository,
            importantOnly: importantOnly,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the notice', (tester) async {
    await pump(tester, repository: _FakeRepository([announcement()]));

    expect(find.text('サポート休止のお知らせ'), findsOneWidget);
  });

  testWidgets('renders nothing when there is no notice', (tester) async {
    await pump(tester, repository: _FakeRepository([]));

    expect(find.byType(Card), findsNothing);
  });

  testWidgets('renders nothing when the notices fail to load', (tester) async {
    // Offline, or a rules change. A banner apologising for its own failure
    // would be on every screen in the app.
    await pump(tester, repository: _FailingRepository());

    expect(find.byType(Card), findsNothing);
  });

  testWidgets('stays gone after being dismissed', (tester) async {
    await pump(tester, repository: _FakeRepository([announcement()]));

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('サポート休止のお知らせ'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(AnnouncementReadState.prefsKey), contains('a1'));
  });

  testWidgets('does not come back on the next launch', (tester) async {
    SharedPreferences.setMockInitialValues({
      AnnouncementReadState.prefsKey: ['a1'],
    });

    await pump(tester, repository: _FakeRepository([announcement()]));

    expect(find.text('サポート休止のお知らせ'), findsNothing);
  });

  testWidgets('moves on to the next notice once one is dismissed', (
    tester,
  ) async {
    await pump(
      tester,
      repository: _FakeRepository([
        announcement(),
        announcement(id: 'a2', titleJa: 'メンテナンスのお知らせ'),
      ]),
    );

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('メンテナンスのお知らせ'), findsOneWidget);
  });

  testWidgets('the sign-in screen shows only important notices', (
    tester,
  ) async {
    // It is shown before anyone is signed in, so it is reserved for what
    // people need in order to understand why the app is not working.
    await pump(
      tester,
      repository: _FakeRepository([
        announcement(titleJa: '通常のお知らせ'),
        announcement(id: 'a2', titleJa: '障害のお知らせ', important: true),
      ]),
      importantOnly: true,
    );

    expect(find.text('障害のお知らせ'), findsOneWidget);
    expect(find.text('通常のお知らせ'), findsNothing);
  });
}
