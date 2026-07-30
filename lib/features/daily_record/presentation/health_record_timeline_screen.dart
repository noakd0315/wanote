import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/health_record_repository.dart';
import '../models/health_record.dart';
import 'health_record_detail_screen.dart';
import 'health_record_form_screen.dart';

/// Spec 2.2: "記録一覧（タイムライン表示、日付降順）".
class HealthRecordTimelineScreen extends StatelessWidget {
  const HealthRecordTimelineScreen({
    super.key,
    required this.uid,
    required this.petId,
    required this.repository,
  });

  final String uid;
  final String petId;
  final HealthRecordRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('健康記録')),
      body: StreamBuilder<List<HealthRecord>>(
        stream: repository.watchTimeline(uid, petId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final records = snapshot.data ?? const <HealthRecord>[];
          // watchTimeline already orders by recorded_at descending, but sort
          // defensively in case a caller passes a differently-ordered fake.
          final sorted = [...records]
            ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
          if (sorted.isEmpty) {
            return const Center(child: Text('記録がまだありません'));
          }
          return ListView.builder(
            itemCount: sorted.length,
            itemBuilder: (context, index) {
              final record = sorted[index];
              return ListTile(
                leading: record.photos.isNotEmpty
                    ? const Icon(Icons.photo)
                    : const Icon(Icons.notes),
                title: Text(DateFormat('yyyy/MM/dd HH:mm').format(record.recordedAt)),
                subtitle: Text(
                  record.tags.isEmpty ? (record.memo ?? '') : record.tags.map((t) => t.wireName).join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => HealthRecordDetailScreen(
                        uid: uid,
                        record: record,
                        repository: repository,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => HealthRecordFormScreen(
                uid: uid,
                petId: petId,
                repository: repository,
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
