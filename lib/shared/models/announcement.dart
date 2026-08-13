import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// One notice shown inside the app: maintenance, a policy change, or -- the
/// case that prompted the feature -- a period when support cannot answer
/// enquiries.
///
/// Written by hand in the Firebase console, never by the app (see
/// firestore.rules). That is the whole point: a notice has to be publishable
/// in a minute, without a release and without an admin screen to maintain.
class Announcement extends Equatable {
  const Announcement({
    required this.id,
    required this.titleJa,
    required this.bodyJa,
    required this.publishedAt,
    this.titleEn,
    this.bodyEn,
    this.expiresAt,
    this.important = false,
  });

  final String id;
  final String titleJa;
  final String bodyJa;

  /// English is optional; a notice written in a hurry falls back to
  /// Japanese rather than showing nothing.
  final String? titleEn;
  final String? bodyEn;

  final DateTime publishedAt;

  /// When the notice stops showing itself. Null means it stays until
  /// deleted.
  ///
  /// This is the field the feature exists for: "support is away until the
  /// 20th" has to disappear on the 20th. Relying on someone remembering to
  /// delete it means the app eventually tells people support is closed while
  /// it is open.
  final DateTime? expiresAt;

  /// Shown even on the sign-in screen, before anyone is signed in. For
  /// things people need to know when the app is not working -- an outage
  /// nobody can sign in to read about is the case that matters.
  final bool important;

  bool isVisibleAt(DateTime now) {
    if (publishedAt.isAfter(now)) return false;
    final expiry = expiresAt;
    return expiry == null || expiry.isAfter(now);
  }

  /// The title in [languageCode], falling back to Japanese.
  String titleFor(String languageCode) =>
      languageCode == 'en' ? (titleEn ?? titleJa) : titleJa;

  String bodyFor(String languageCode) =>
      languageCode == 'en' ? (bodyEn ?? bodyJa) : bodyJa;

  factory Announcement.fromMap(String id, Map<String, dynamic> map) {
    return Announcement(
      id: id,
      titleJa: map['title_ja'] as String? ?? '',
      bodyJa: map['body_ja'] as String? ?? '',
      titleEn: _readNonEmpty(map['title_en']),
      bodyEn: _readNonEmpty(map['body_en']),
      // A notice with no published_at is treated as published immediately.
      // Getting a notice out is the urgent case; a missing field should not
      // be what silently swallows it.
      publishedAt:
          _readDate(map['published_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      expiresAt: _readDate(map['expires_at']),
      important: map['important'] as bool? ?? false,
    );
  }

  static String? _readNonEmpty(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value;
  }

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  @override
  List<Object?> get props => [
    id,
    titleJa,
    bodyJa,
    titleEn,
    bodyEn,
    publishedAt,
    expiresAt,
    important,
  ];
}
