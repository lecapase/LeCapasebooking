import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecapase_booking/features/bookings/notification_policy.dart';

void main() {
  test(
    'six removals run concurrently, report progress and continue after failures',
    () async {
      final pending = <int, Completer<bool>>{};
      final results = <int, bool>{};
      var active = 0;
      var peak = 0;
      final work = deleteNotificationsConcurrently<int>(
        List.generate(14, (i) => i),
        remove: (id) async {
          active++;
          if (active > peak) peak = active;
          final completion = Completer<bool>();
          pending[id] = completion;
          try {
            return await completion.future;
          } finally {
            active--;
          }
        },
        onComplete: (id, success) => results[id] = success,
      );
      expect(pending.length, 6);
      pending[0]!.completeError(StateError('network failure'));
      await Future<void>.delayed(Duration.zero);
      expect(results[0], isFalse);
      expect(pending.containsKey(6), isTrue);
      while (results.length < 14) {
        for (final entry in pending.entries.toList()) {
          if (!entry.value.isCompleted) entry.value.complete(entry.key != 3);
        }
        await Future<void>.delayed(Duration.zero);
      }
      await work;
      expect(peak, 6);
      expect(results.length, 14);
      expect(results.values.where((success) => success).length, 12);
    },
  );
}
