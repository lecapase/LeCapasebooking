class BlockedTimeRange {
  final String startTime;
  final String endTime;

  const BlockedTimeRange({
    required this.startTime,
    required this.endTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'startTime': startTime,
      'endTime': endTime,
    };
  }

  factory BlockedTimeRange.fromMap(Map<String, dynamic> map) {
    return BlockedTimeRange(
      startTime: map['startTime'] ?? '',
      endTime: map['endTime'] ?? '',
    );
  }
}

class ServiceAvailability {
  final String id;
  final String name;

  bool isOpen;
  String startTime;
  String endTime;
  int maxOnlineGuests;

  List<BlockedTimeRange> blockedRanges;

  ServiceAvailability({
    required this.id,
    required this.name,
    required this.isOpen,
    required this.startTime,
    required this.endTime,
    required this.maxOnlineGuests,
    List<BlockedTimeRange>? blockedRanges,
  }) : blockedRanges = blockedRanges ?? [];

  ServiceAvailability copy() {
    return ServiceAvailability(
      id: id,
      name: name,
      isOpen: isOpen,
      startTime: startTime,
      endTime: endTime,
      maxOnlineGuests: maxOnlineGuests,
      blockedRanges: blockedRanges
          .map(
            (range) => BlockedTimeRange(
              startTime: range.startTime,
              endTime: range.endTime,
            ),
          )
          .toList(),
    );
  }
}

class DayAvailability {
  final int weekday;
  final String name;

  ServiceAvailability lunch;
  ServiceAvailability dinner;

  DayAvailability({
    required this.weekday,
    required this.name,
    required this.lunch,
    required this.dinner,
  });
}

class DateAvailabilityException {
  final DateTime date;

  ServiceAvailability lunch;
  ServiceAvailability dinner;

  DateAvailabilityException({
    required this.date,
    required this.lunch,
    required this.dinner,
  });
}