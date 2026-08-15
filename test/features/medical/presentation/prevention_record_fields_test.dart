import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wanote/features/medical/data/certificate_storage_service.dart';
import 'package:wanote/features/medical/data/prevention_record_repository.dart';
import 'package:wanote/features/medical/domain/models/prevention_program.dart';
import 'package:wanote/features/medical/presentation/prevention/prevention_record_form_screen.dart';
import 'package:wanote/l10n/generated/app_localizations.dart';

class MockPreventionRecordRepository extends Mock
    implements PreventionRecordRepository {}

/// The screen's default storage service reaches for FirebaseStorage in its
/// constructor, which throws without an initialized app. Nothing here
/// uploads anything, so a do-nothing stand-in is enough.
class MockCertificateStorageService extends Mock
    implements CertificateStorageService {}

/// The record form asks what the kind of care actually has.
///
/// A vaccination records which vaccine; a medication records which drug and
/// how much of it. Asking "how much" about a vaccine invites a guess at
/// something the owner did not measure, so the dose field is not merely
/// relabelled -- it is absent (PM request, 2026-08-15).
///
/// Worth a test because both branches render a perfectly plausible-looking
/// form: a regression here shows a working screen with the wrong question
/// on it, which nothing else would catch.
void main() {
  late MockPreventionRecordRepository repository;

  setUp(() => repository = MockPreventionRecordRepository());

  PreventionProgram program(PreventionType type) => PreventionProgram(
    programId: 'prog-1',
    petId: 'pet-1',
    type: type,
    productName: '狂犬病ワクチン',
    scheduleType: ScheduleType.annual,
    startDate: DateTime(2026, 1, 1),
    active: true,
  );

  Future<void> pumpForm(WidgetTester tester, PreventionType type) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PreventionRecordFormScreen(
          uid: 'uid-1',
          petId: 'pet-1',
          program: program(type),
          repository: repository,
          storageService: MockCertificateStorageService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a vaccination asks for the vaccine type and not a dose', (
    tester,
  ) async {
    await pumpForm(tester, PreventionType.vaccine);

    expect(find.text('ワクチンの種類'), findsOneWidget);
    expect(find.text('用量'), findsNothing);
    expect(find.text('薬品名'), findsNothing);
  });

  testWidgets('a medication asks for the drug name and the dose', (
    tester,
  ) async {
    await pumpForm(tester, PreventionType.medication);

    expect(find.text('薬品名'), findsOneWidget);
    expect(find.text('用量'), findsOneWidget);
    expect(find.text('ワクチンの種類'), findsNothing);
  });

  testWidgets("the product field starts on the programme's own product", (
    tester,
  ) async {
    // Re-typing "狂犬病ワクチン" on every dose of a programme that already
    // says so is work the app can do.
    await pumpForm(tester, PreventionType.vaccine);

    expect(find.text('狂犬病ワクチン'), findsOneWidget);
  });
}
