import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/wanote_loading_indicator.dart';

/// One past record, described well enough to pick it out of a list.
class HistoryCopyOption<T> {
  const HistoryCopyOption({
    required this.value,
    required this.title,
    required this.subtitle,
  });

  final T value;
  final String title;
  final String subtitle;
}

/// Lets a new record start from an old one (PM request: 通院歴・投薬・予防医療
/// の履歴をコピーして入力したい).
///
/// The same visit to the same clinic for the same thing gets recorded over
/// and over -- monthly heartworm, a course of the same medication, the
/// annual booster at the annual vet. Retyping the hospital name and the
/// diagnosis each time is the work this removes.
///
/// Copies the *content* and never the date: the whole point is that this is
/// a new occurrence, and a copied date would silently record it as having
/// happened when the old one did. Each form fills its own fields from the
/// chosen record and leaves its date at today.
///
/// Generic over the record type because all three lists want identical
/// behaviour and none of them share a base class -- Visit, Medication and
/// PreventionRecord are separate models owned by separate screens.
Future<T?> showHistoryCopyPicker<T>({
  required BuildContext context,
  required Stream<List<HistoryCopyOption<T>>> options,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: StreamBuilder<List<HistoryCopyOption<T>>>(
        stream: options,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: WanoteLoadingIndicator(size: 40),
            );
          }
          final items = snapshot.data!;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    l10n.historyCopyPickerTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l10n.historyCopyPickerEmptyMessage),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    // Capped rather than showing everything: this is "the
                    // one I did last time", and scrolling a year of records
                    // to find it is slower than typing the fields again.
                    itemCount: items.length > 10 ? 10 : items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        title: Text(item.title),
                        subtitle: Text(item.subtitle),
                        onTap: () => Navigator.of(context).pop(item.value),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    ),
  );
}
