import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/certificate_cache_service.dart';
import '../../data/prevention_record_repository.dart';
import '../../domain/models/prevention_record.dart';

/// Spec 5.3's certificate list requirement: "一覧から証明書を即座に確認できる
/// ようにする（ペットホテル・ドッグラン・トリミング施設での提示を想定）",
/// with an offline-friendly local cache so the certificate is viewable even
/// without a network connection at the counter.
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
    return Scaffold(
      appBar: AppBar(title: const Text('証明書一覧')),
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
            return const Center(child: Text('登録済みの証明書がありません'));
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
              return _CertificateTile(record: record, cacheService: cacheService);
            },
          );
        },
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
              child: _CertificateImage(record: record, cacheService: cacheService),
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
        if (file == null) {
          return const Center(child: Icon(Icons.broken_image));
        }
        return Image.file(file, fit: BoxFit.cover, width: double.infinity);
      },
    );
  }
}
