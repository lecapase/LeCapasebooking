import 'package:flutter_test/flutter_test.dart';
import 'package:lecapase_booking/features/bookings/capacity_warning.dart';

void main() {
  test('exact capacity and reductions do not require an override', () {
    checkCapacityIncrease(currentGuests: 8, increase: 2, limit: 10);
    checkCapacityIncrease(currentGuests: 20, increase: -2, limit: 10);
  });
  test(
    'new booking, guest increase and reopened booking above capacity warn',
    () {
      expect(
        () => checkCapacityIncrease(currentGuests: 9, increase: 2, limit: 10),
        throwsA(
          isA<CapacityWarning>().having(
            (e) => e.projectedGuests,
            'projected guests',
            11,
          ),
        ),
      );
      expect(
        () => checkCapacityIncrease(currentGuests: 0, increase: 2, limit: 0),
        throwsA(isA<CapacityWarning>()),
      );
    },
  );
  test('concurrent increases need new approval above the approved total', () {
    checkCapacityIncrease(
      currentGuests: 9,
      increase: 2,
      limit: 10,
      approvedTotal: 11,
    );
    expect(
      () => checkCapacityIncrease(
        currentGuests: 10,
        increase: 2,
        limit: 10,
        approvedTotal: 11,
      ),
      throwsA(isA<CapacityWarning>()),
    );
  });
}
