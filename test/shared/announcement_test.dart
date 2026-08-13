import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanote/shared/models/announcement.dart';

/// In-app notices.
///
/// The window logic is the part that matters. The feature was asked for so
/// that "support cannot answer enquiries until the 20th" can be published --
/// and a notice like that has to stop showing on the 20th by itself. If it
/// depends on someone remembering to delete it, the app eventually tells
/// people support is closed while it is open.
void main() {
  final now = DateTime(2026, 8, 12, 10);

  Announcement announcement({
    DateTime? publishedAt,
    DateTime? expiresAt,
    String? titleEn,
    String? bodyEn,
    bool important = false,
  }) => Announcement(
    id: 'a1',
    titleJa: 'サポート休止のお知らせ',
    bodyJa: '8/13〜8/20 はお問い合わせに対応できません。',
    titleEn: titleEn,
    bodyEn: bodyEn,
    publishedAt: publishedAt ?? DateTime(2026, 8, 1),
    expiresAt: expiresAt,
    important: important,
  );

  group('visibility', () {
    test('a published notice with no expiry keeps showing', () {
      expect(announcement().isVisibleAt(now), isTrue);
    });

    test('hides itself once the expiry passes', () {
      expect(
        announcement(expiresAt: DateTime(2026, 8, 12, 9)).isVisibleAt(now),
        isFalse,
      );
    });

    test('is still visible in the final minute before expiry', () {
      expect(
        announcement(expiresAt: DateTime(2026, 8, 12, 10, 1)).isVisibleAt(now),
        isTrue,
      );
    });

    test('stays hidden until its publication time', () {
      // Lets a notice be written in advance -- "we will be away next week"
      // typed today, appearing on the day.
      expect(
        announcement(publishedAt: DateTime(2026, 8, 13)).isVisibleAt(now),
        isFalse,
      );
    });
  });

  group('language', () {
    test('uses the English text when there is some', () {
      final a = announcement(titleEn: 'Support closed', bodyEn: 'Back on 20th');
      expect(a.titleFor('en'), 'Support closed');
      expect(a.bodyFor('en'), 'Back on 20th');
    });

    test('falls back to Japanese rather than showing nothing', () {
      // Notices are written by hand, often in a hurry. A missing translation
      // must not turn into a blank banner.
      final a = announcement();
      expect(a.titleFor('en'), a.titleJa);
      expect(a.bodyFor('en'), a.bodyJa);
    });

    test('treats an empty English string as absent', () {
      final a = Announcement.fromMap('a1', {
        'title_ja': 'お知らせ',
        'body_ja': '本文',
        'title_en': '   ',
        'body_en': '',
        'published_at': Timestamp.fromDate(DateTime(2026, 8, 1)),
      });

      expect(a.titleFor('en'), 'お知らせ');
      expect(a.bodyFor('en'), '本文');
    });
  });

  group('fromMap', () {
    test('reads the fields the console writes', () {
      final a = Announcement.fromMap('notice-1', {
        'title_ja': '障害のお知らせ',
        'body_ja': '現在サインインできない事象が発生しています。',
        'published_at': Timestamp.fromDate(DateTime(2026, 8, 10)),
        'expires_at': Timestamp.fromDate(DateTime(2026, 8, 20)),
        'important': true,
      });

      expect(a.id, 'notice-1');
      expect(a.important, isTrue);
      expect(a.publishedAt, DateTime(2026, 8, 10));
      expect(a.expiresAt, DateTime(2026, 8, 20));
    });

    test('accepts an ISO string date, which is easy to type by hand', () {
      final a = Announcement.fromMap('a1', {
        'title_ja': 'お知らせ',
        'body_ja': '本文',
        'published_at': '2026-08-10T00:00:00.000',
      });

      expect(a.publishedAt, DateTime(2026, 8, 10));
    });

    test('shows a notice missing published_at rather than swallowing it', () {
      // Getting a notice out is the urgent case. A field forgotten in the
      // console should not be the thing that silently hides it.
      final a = Announcement.fromMap('a1', {
        'title_ja': 'お知らせ',
        'body_ja': '本文',
      });

      expect(a.isVisibleAt(now), isTrue);
      expect(a.important, isFalse);
    });
  });
}
