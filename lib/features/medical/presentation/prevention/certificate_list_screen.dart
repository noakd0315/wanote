import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../data/certificate_cache_service.dart';
import '../../data/prevention_record_repository.dart';
import '../../domain/models/prevention_record.dart';
import 'prevention_program_list_screen.dart';

/// Spec 5.3's certificate list requirement: "一覧から証明書を即座に確認できる
/// ようにする（ペットホテル・ドッグラン・トリミング施設での提示を想定）",
/// with an offline-friendly local cache so the certificate is viewable even
/// without a network connection at the counter.
///
/// This screen is intentionally read-only (spec 5.4's OCR capture/registration
/// flow lives on [PreventionRecordFormScreen], reached via a prevention
/// program's record list) -- but with no link between the two, a user
/// landing on this empty tab has no way to discover where to actually add a
/// certificate. The FAB/empty-state button below exists to bridge that gap.
class CertificateListScreen extends StatelessWidget {
  CertificateListScreen({
    super.key,
    required this.uid,
    required this.petId,
    PreventionRecordRepository? repository,
    CertificateCacheService? cacheService,
  }) : repository = repository ?? FirestorePreventionRecordRepository(),
       cacheService = cacheService ?? FileSystemCertificateCacheService();

  final String uid;
  final String petId;
  final PreventionRecordRepository repository;
  final CertificateCacheService cacheService;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      // Transparent so HomeShell's shared DogSilhouetteBackground (behind
      // its Navigator) shows through this tab-root screen, per the PM's
      // request to scatter the pattern across each screen.
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l10n.certificateListTitle)),
      body: StreamBuilder<List<PreventionRecord>>(
        stream: repository.watchRecords(uid, petId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final records = snapshot.data!
              .where((r) => r.certificateFile != null)
              .toList();
          if (records.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.description_outlined, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      l10n.certificateListEmptyTitle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.certificateListEmptyDescription,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _openPreventionPrograms(context),
                      icon: const Icon(Icons.vaccines_outlined),
                      label: Text(l10n.certificateAddPreventionRecordLabel),
                    ),
                  ],
                ),
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.8,
            ),
            itemCount: records.length,
            itemBuilder: (context, index) {
              final record = records[index];
              return _CertificateTile(
                record: record,
                cacheService: cacheService,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        // Plain "+" (not a camera icon) -- PM note: this button navigates
        // to 予防医療 rather than directly launching the camera, so a
        // photo-specific icon was misleading.
        tooltip: l10n.certificateAddPreventionRecordLabel,
        onPressed: () => _openPreventionPrograms(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _openPreventionPrograms(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PreventionProgramListScreen(uid: uid, petId: petId),
      ),
    );
  }
}

class _CertificateTile extends StatelessWidget {
  const _CertificateTile({required this.record, required this.cacheService});

  final PreventionRecord record;
  final CertificateCacheService cacheService;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          child: _CertificateImage(record: record, cacheService: cacheService),
        ),
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(
              child: _CertificateImage(
                record: record,
                cacheService: cacheService,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(4),
              child: Text(
                record.administeredAt.toLocal().toString().split(' ').first,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CertificateImage extends StatelessWidget {
  const _CertificateImage({required this.record, required this.cacheService});

  final PreventionRecord record;
  final CertificateCacheService cacheService;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: cacheService.getOrDownload(
        recordId: record.recordId,
        remoteUrl: record.certificateFile,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final file = snapshot.data;
        if (file != null) {
          return Image.file(file, fit: BoxFit.cover, width: double.infinity);
        }
        // The offline cache is filesystem-backed (path_provider), which has
        // no web implementation -- getOrDownload() fails there, and every
        // certificate rendered as a broken-image icon (PM report: 証明書の
        // 画像が一覧、詳細ともに表示されていません). Falling back to the
        // Storage URL keeps the list usable wherever the cache can't run;
        // on mobile the cached file above is still preferred, so the
        // offline counter-side use case in spec 5.3 is unaffected.
        final remoteUrl = record.certificateFile;
        if (remoteUrl != null) {
          return Image.network(
            remoteUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (context, error, stackTrace) =>
                const Center(child: Icon(Icons.broken_image)),
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const Center(child: CircularProgressIndicator()),
          );
        }
        return const Center(child: Icon(Icons.broken_image));
      },
    );
  }
}
