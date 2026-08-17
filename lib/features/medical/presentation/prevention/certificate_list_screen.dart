import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../data/certificate_cache_service.dart';
import '../../data/prevention_program_repository.dart';
import '../../data/prevention_record_repository.dart';
import '../../domain/models/prevention_program.dart';
import '../../domain/models/prevention_record.dart';
import 'prevention_program_list_screen.dart';
import '../../../../shared/widgets/stream_error_view.dart';
import '../../../../shared/widgets/wanote_loading_indicator.dart';
import '../../domain/latest_certificates.dart';

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
class CertificateListScreen extends StatefulWidget {
  CertificateListScreen({
    super.key,
    required this.uid,
    required this.petId,
    PreventionRecordRepository? repository,
    PreventionProgramRepository? programRepository,
    CertificateCacheService? cacheService,
  }) : repository = repository ?? FirestorePreventionRecordRepository(),
       programRepository =
           programRepository ?? FirestorePreventionProgramRepository(),
       cacheService = cacheService ?? FileSystemCertificateCacheService();

  final String uid;
  final String petId;
  final PreventionRecordRepository repository;

  /// Only needed to resolve each record's `program_id` into the program name
  /// shown on the tile -- PM request: a certificate thumbnail plus a date
  /// alone doesn't say *which* vaccination it is, which is the first thing
  /// you need when showing it at a counter.
  final PreventionProgramRepository programRepository;
  final CertificateCacheService cacheService;

  @override
  State<CertificateListScreen> createState() => _CertificateListScreenState();
}

class _CertificateListScreenState extends State<CertificateListScreen> {
  /// Whether superseded certificates are showing as well as current ones.
  ///
  /// Off by default (PM request: 証明書は種別ごとに最新だけ). This screen is
  /// used at a counter, where the question is always "is this dog's X up to
  /// date" -- last year's certificate for the same programme is not an
  /// answer to it, and after a few years of boosters the current one is
  /// buried among them. Nothing is deleted; the older ones are one tap away.
  bool _showAll = false;

  String get uid => widget.uid;
  String get petId => widget.petId;
  PreventionRecordRepository get repository => widget.repository;
  PreventionProgramRepository get programRepository =>
      widget.programRepository;
  CertificateCacheService get cacheService => widget.cacheService;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      // Transparent so HomeShell's shared DogSilhouetteBackground (behind
      // its Navigator) shows through this tab-root screen, per the PM's
      // request to scatter the pattern across each screen.
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(l10n.certificateListTitle),
        actions: [
          IconButton(
            tooltip: _showAll
                ? l10n.certificateShowLatestOnlyTooltip
                : l10n.certificateShowAllTooltip,
            icon: Icon(_showAll ? Icons.filter_alt : Icons.filter_alt_outlined),
            onPressed: () => setState(() => _showAll = !_showAll),
          ),
        ],
      ),
      body: StreamBuilder<List<PreventionRecord>>(
        stream: repository.watchRecords(uid, petId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return StreamErrorView(error: snapshot.error!);
          }
          if (!snapshot.hasData) {
            return WanoteLoadingIndicator.centered();
          }
          final withCertificates = snapshot.data!
              .where((r) => r.certificateFile != null)
              .toList();
          final records = _showAll
              ? (withCertificates
                  ..sort((a, b) => b.administeredAt.compareTo(a.administeredAt)))
              : latestCertificatePerProgram(withCertificates);
          final hiddenCount = withCertificates.length - records.length;
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
          // Nested rather than combined: the program list only supplies a
          // display name, so it must never gate the certificates themselves
          // -- if it is still loading (or fails), the tiles still render and
          // simply omit the name.
          return StreamBuilder<List<PreventionProgram>>(
            stream: programRepository.watchPrograms(uid, petId),
            builder: (context, programSnapshot) {
              final programNames = {
                for (final program in programSnapshot.data ?? const [])
                  program.programId: program.productName,
              };
              // The grid is wrapped so the count of what is not shown can
              // sit above it. Without this the screen looks the same whether
              // a programme has one certificate or ten, and the filter is
              // invisible until someone goes looking for a missing one.
              return Column(
                children: [
                  if (hiddenCount > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.certificateOlderHiddenLabel(hiddenCount),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey),
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() => _showAll = true),
                            child: Text(l10n.certificateShowAllTooltip),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  // Taller than wide enough for the image plus two lines of
                  // caption (program name + date) without squeezing the
                  // thumbnail.
                  childAspectRatio: 0.68,
                ),
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final record = records[index];
                  return _CertificateTile(
                    record: record,
                    programName: programNames[record.programId],
                    cacheService: cacheService,
                  );
                },
                    ),
                  ),
                ],
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
  const _CertificateTile({
    required this.record,
    required this.programName,
    required this.cacheService,
  });

  final PreventionRecord record;

  /// Null while the program list is still loading, or if the record points
  /// at a program that has since been deleted -- the tile just drops the
  /// line in that case rather than showing a placeholder.
  final String? programName;
  final CertificateCacheService cacheService;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          // Near-fullscreen: a certificate is dense small print, so the
          // dialog needs the room for zooming to be useful at all.
          insetPadding: const EdgeInsets.all(16),
          child: _ZoomableCertificateView(
            record: record,
            programName: programName,
            cacheService: cacheService,
          ),
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
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (programName != null)
                    Text(
                      programName!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    record.administeredAt.toLocal().toString().split(' ').first,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen-ish certificate viewer with pinch-to-zoom -- PM request:
/// certificates are dense small print (hospital name, lot numbers, dates),
/// and the previous dialog rendered the image at a fixed size with no way to
/// magnify it.
///
/// [InteractiveViewer] handles pinch on touch devices and ctrl+scroll /
/// trackpad pinch on desktop and web. Double-tap is wired up as well because
/// pinch is awkward one-handed, which is the likely posture when showing
/// this at a counter.
class _ZoomableCertificateView extends StatefulWidget {
  const _ZoomableCertificateView({
    required this.record,
    required this.programName,
    required this.cacheService,
  });

  final PreventionRecord record;
  final String? programName;
  final CertificateCacheService cacheService;

  @override
  State<_ZoomableCertificateView> createState() =>
      _ZoomableCertificateViewState();
}

class _ZoomableCertificateViewState extends State<_ZoomableCertificateView> {
  final _controller = TransformationController();

  static const _doubleTapScale = 2.5;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDoubleTap(TapDownDetails details) {
    final isZoomedIn = _controller.value.getMaxScaleOnAxis() > 1.01;
    if (isZoomedIn) {
      _controller.value = Matrix4.identity();
      return;
    }
    // Zoom centred on whatever was tapped, so double-tapping a specific
    // field brings that field up rather than the middle of the page.
    final position = details.localPosition;
    _controller.value = Matrix4.identity()
      ..translateByDouble(
        -position.dx * (_doubleTapScale - 1),
        -position.dy * (_doubleTapScale - 1),
        0,
        1,
      )
      ..scaleByDouble(_doubleTapScale, _doubleTapScale, _doubleTapScale, 1);
  }

  @override
  Widget build(BuildContext context) {
    final caption = [
      if (widget.programName != null) widget.programName!,
      widget.record.administeredAt.toLocal().toString().split(' ').first,
    ].join('  ·  ');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  caption,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Flexible(
          child: InteractiveViewer(
            transformationController: _controller,
            minScale: 1,
            maxScale: 6,
            // Nested INSIDE the viewer, not wrapped around it: the viewer
            // claims the gesture arena for its own scale/pan recognizer, so
            // an outer GestureDetector never sees the second tap and the
            // double-tap silently does nothing.
            child: GestureDetector(
              onDoubleTapDown: _handleDoubleTap,
              // The zoom itself is applied from the down event's position;
              // this empty callback is what makes the double-tap gesture
              // get recognized at all.
              onDoubleTap: () {},
              child: _CertificateImage(
                record: widget.record,
                cacheService: widget.cacheService,
              ),
            ),
          ),
        ),
      ],
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
          return WanoteLoadingIndicator.centered();
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
                : WanoteLoadingIndicator.centered(),
          );
        }
        return const Center(child: Icon(Icons.broken_image));
      },
    );
  }
}
