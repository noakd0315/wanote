import 'models/prevention_record.dart';

/// The current certificate for each preventive care programme, newest first.
///
/// PM request: 証明書は種別ごとに最新だけ. The certificate list is used at a
/// counter -- a pet hotel, a dog run, a groomer -- where the question is
/// always "is this dog's X up to date". Last year's certificate for the same
/// programme is not an answer to that, and after a few years of boosters the
/// current one is buried among the ones it replaced.
///
/// Grouped by programme, not by [PreventionType]: 狂犬病 and 混合ワクチン are
/// both vaccines, and a counter asks for both. Collapsing to one row per
/// type would hide one behind the other.
///
/// Pure and framework-free so the grouping can be tested without a screen.
/// Nothing is discarded here -- the caller still holds the full list, and
/// the screen offers a way to show it.
List<PreventionRecord> latestCertificatePerProgram(
  List<PreventionRecord> records,
) {
  final latest = <String, PreventionRecord>{};
  for (final record in records) {
    final current = latest[record.programId];
    if (current == null ||
        record.administeredAt.isAfter(current.administeredAt)) {
      latest[record.programId] = record;
    }
  }
  return latest.values.toList()
    ..sort((a, b) => b.administeredAt.compareTo(a.administeredAt));
}
