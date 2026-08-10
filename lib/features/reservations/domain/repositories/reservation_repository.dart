import '../entities/reservation.dart';

abstract interface class ReservationRepository {
  /// Creates a pending reservation request.
  Future<void> create({
    required String restaurantId,
    required String restaurantName,
    String? restaurantLogoUrl,
    required DateTime dateTime,
    required int partySize,
    String? note,
  });

  /// The viewer's reservations, most recent booking time first (live).
  Stream<List<Reservation>> watchMine({int limit});

  /// User-initiated cancellation (pending/confirmed only).
  Future<void> cancel(String reservationId);
}
