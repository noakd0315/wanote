import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanote/features/ai/presentation/widgets/ai_usage_badge.dart';
import 'package:wanote/l10n/generated/app_localizations.dart';
import 'package:wanote/shared/services/ai_usage_repository.dart';

/// The badge reports a balance the owner pays real money into, so it has to
/// answer to every writer -- not only to the screen it happens to sit on.
///
/// It used to be handed a token the consultation screen bumped after
/// spending a call, which covered that one change and nothing else. A
/// ticket bought on the paywall reached Firestore and never reached the
/// badge, so the purchase looked like it had gone missing (PM, 2026-08-21:
/// チケット回数も表示されませんでした。DBを見る限り加算されていました).
class _StreamingUsageRepository implements AiUsageRepository {
  final StreamController<AiUsageStatus> _controller =
      StreamController<AiUsageStatus>.broadcast();

  void emit(AiUsageStatus status) => _controller.add(status);

  Future<void> close() => _controller.close();

  @override
  Stream<AiUsageStatus> watchStatus(String uid) => _controller.stream;

  @override
  Future<AiUsageStatus> getStatus(String uid) async =>
      throw StateError('the badge must watch, not read');

  @override
  Future<void> recordConsultationUsed(String uid) async {}

  @override
  Future<void> creditTickets(
    String uid,
    int count, {
    required String transactionId,
  }) async {}

  @override
  Future<void> setUnlimitedSubscription(String uid, bool active) async {}
}

Widget _host(AiUsageRepository repository) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('ja'),
  home: Scaffold(
    body: AiUsageBadge(uid: 'uid-1', usageRepository: repository),
  ),
);

void main() {
  late _StreamingUsageRepository repository;

  setUp(() => repository = _StreamingUsageRepository());
  tearDown(() => repository.close());

  testWidgets('a ticket credited elsewhere appears without any prompting', (
    tester,
  ) async {
    await tester.pumpWidget(_host(repository));

    // The free month is running and nothing has been bought: the badge has
    // no number worth showing.
    repository.emit(
      const AiUsageStatus(
        freeConsultationsRemainingThisMonth: 5,
        ticketsRemaining: 0,
        hasUnlimitedSubscription: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('チケット'), findsNothing);

    // The paywall credits five tickets. Nothing on this screen did it, and
    // nothing on this screen is going to be told about it.
    repository.emit(
      const AiUsageStatus(
        freeConsultationsRemainingThisMonth: 5,
        ticketsRemaining: 5,
        hasUnlimitedSubscription: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('チケット 5枚'), findsOneWidget);
  });

  testWidgets('the count follows a call spent from another screen', (
    tester,
  ) async {
    await tester.pumpWidget(_host(repository));

    repository.emit(
      const AiUsageStatus(
        freeConsultationsRemainingThisMonth: 5,
        ticketsRemaining: 0,
        hasUnlimitedSubscription: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('残り5回'), findsOneWidget);

    repository.emit(
      const AiUsageStatus(
        freeConsultationsRemainingThisMonth: 4,
        ticketsRemaining: 0,
        hasUnlimitedSubscription: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('残り4回'), findsOneWidget);
  });
}
