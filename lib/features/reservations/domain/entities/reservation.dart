import 'package:equatable/equatable.dart';

enum ReservationStatus {
  pending,
  confirmed,
  rejected,
  cancelled,
  completed;

  static ReservationStatus fromKey(String? key) =>
      ReservationStatus.values.firstWhere(
        (s) => s.name == key,
        orElse: () => ReservationStatus.pending,
      );

  String get label => switch (this) {
        pending => 'Pending',
        confirmed => 'Confirmed',
        rejected => 'Declined',
        cancelled => 'Cancelled',
        completed => 'Completed',
      };

  /// Still counts as an active/upcoming booking.
  bool get isActive => this == pending || this == confirmed;
}

class Reservation extends Equatable {
  const Reservation({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    this.restaurantLogoUrl,
    required this.userId,
    required this.userName,
    required this.partySize,
    required this.dateTime,
    this.note,
    this.status = ReservationStatus.pending,
    this.createdAt,
  });

  final String id;
  final String restaurantId;
  final String restaurantName;
  final String? restaurantLogoUrl;
  final String userId;
  final String userName;
  final int partySize;
  final DateTime dateTime;
  final String? note;
  final ReservationStatus status;
  final DateTime? createdAt;

  bool get isUpcoming => status.isActive && dateTime.isAfter(DateTime.now());

  @override
  List<Object?> get props => [id, status, dateTime];
}
