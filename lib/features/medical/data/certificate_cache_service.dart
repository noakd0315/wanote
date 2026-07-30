import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Certificate list (spec 5.3) needs to be viewable at a glance even offline
/// (pet hotel/grooming-counter use case), so we keep a local copy of each
/// certificate image keyed by `record_id` in the app's documents directory,
/// and only hit Firebase Storage's download URL the first time (or if the
/// local copy has gone missing).
///
/// Kept behind an interface so screens/tests can inject a fake instead of
/// touching the real filesystem/network.
abstract class CertificateCacheService {
  /// Returns the local file for [recordId], downloading it from
  /// [remoteUrl] first if it isn't cached yet (or re-downloading if the
  /// cached file was deleted from disk). Returns `null` if there is no
  /// remote URL to fall back to and nothing is cached.
  Future<File?> getOrDownload({
    required String recordId,
    required String? remoteUrl,
  });

  /// True if [recordId] already has a cached local copy, without touching
  /// the network. Screens can use this to decide whether to show an
  /// offline-available badge.
  Future<bool> isCached(String recordId);

  /// Removes the cached copy for [recordId] (e.g. when the record/
  /// certificate is deleted so we don't leak storage).
  Future<void> evict(String recordId);
}

class FileSystemCertificateCacheService implements CertificateCacheService {
  FileSystemCertificateCacheService({
    http.Client? httpClient,
    Future<Directory> Function()? documentsDirProvider,
  }) : _httpClient = httpClient ?? http.Client(),
       _documentsDirProvider =
           documentsDirProvider ?? getApplicationDocumentsDirectory;

  final http.Client _httpClient;
  final Future<Directory> Function() _documentsDirProvider;

  static const String _cacheSubdirName = 'certificate_cache';

  Future<Directory> _cacheDir() async {
    final docsDir = await _documentsDirProvider();
    final dir = Directory('${docsDir.path}/$_cacheSubdirName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _localFile(String recordId) async {
    final dir = await _cacheDir();
    return File('${dir.path}/$recordId');
  }

  @override
  Future<bool> isCached(String recordId) async {
    final file = await _localFile(recordId);
    return file.exists();
  }

  @override
  Future<File?> getOrDownload({
    required String recordId,
    required String? remoteUrl,
  }) async {
    final file = await _localFile(recordId);
    if (await file.exists()) {
      return file;
    }
    if (remoteUrl == null) {
      return null;
    }
    final response = await _httpClient.get(Uri.parse(remoteUrl));
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to download certificate for $recordId: HTTP ${response.statusCode}',
      );
    }
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file;
  }

  @override
  Future<void> evict(String recordId) async {
    final file = await _localFile(recordId);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
