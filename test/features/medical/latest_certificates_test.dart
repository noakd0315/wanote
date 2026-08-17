import 'package:flutter_test/flutter_test.dart';
import 'package:wanote/features/medical/domain/latest_certificates.dart';
import 'package:wanote/features/medical/domain/models/prevention_record.dart';

void main() {
  PreventionRecord record(String id, String programId, DateTime at) =>
      PreventionRecord(
        recordId: id,
        programId: programId,
        petId: 'pet-1',
        administeredAt: at,
      );

  test('keeps only the newest record of each programme', () {
    final records = [
      record('rabies-2024', 'rabies', DateTime(2024, 4, 1)),
      record('rabies-2026', 'rabies', DateTime(2026, 4, 1)),
      record('rabies-2025', 'rabies', DateTime(2025, 4, 1)),
    ];
    expect(latestCertificatePerProgram(records).map((r) => r.recordId), [
      'rabies-2026',
    ]);
  });

  // The reason this groups by programme and not by PreventionType: both of
  // these are vaccines, and a counter asks to see both.
  test('two vaccine programmes each keep their own newest', () {
    final records = [
      record('rabies-2026', 'rabies', DateTime(2026, 4, 1)),
      record('combo-2026', 'combination', DateTime(2026, 5, 1)),
      record('combo-2025', 'combination', DateTime(2025, 5, 1)),
    ];
    expect(latestCertificatePerProgram(records).map((r) => r.recordId), [
      'combo-2026',
      'rabies-2026',
    ]);
  });

  test('the result is newest first, whatever order it came in', () {
    final records = [
      record('a', 'p1', DateTime(2024, 1, 1)),
      record('c', 'p3', DateTime(2026, 1, 1)),
      record('b', 'p2', DateTime(2025, 1, 1)),
    ];
    expect(latestCertificatePerProgram(records).map((r) => r.recordId), [
      'c',
      'b',
      'a',
    ]);
  });

  test('an empty list stays empty', () {
    expect(latestCertificatePerProgram(const []), isEmpty);
  });
}
