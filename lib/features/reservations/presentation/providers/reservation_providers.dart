import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/firestore_reservation_repository.dart';
import '../../domain/entities/reservation.dart';
import '../../domain/repositories/reservation_repository.dart';

final reservationRepositoryProvider = Provider<ReservationRepository>(
  (ref) => FirestoreReservationRepository(),
);

final myReservationsProvider =
    StreamProvider.autoDispose<List<Reservation>>(
  (ref) => ref.read(reservationRepositoryProvider).watchMine(),
);

/// Booking form submission state.
class BookingController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Returns null on success, or an error message.
  Future<String?> submit({
    required String restaurantId,
    required String restaurantName,
    String? restaurantLogoUrl,
    required DateTime dateTime,
    required int partySize,
    String? note,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(reservationRepositoryProvider).create(
            restaurantId: restaurantId,
            restaurantName: restaurantName,
            restaurantLogoUrl: restaurantLogoUrl,
            dateTime: dateTime,
            partySize: partySize,
            note: note,
          ),
    );
    return state.hasError ? 'Couldn\'t request the reservation.' : null;
  }
}

final bookingControllerProvider =
    AsyncNotifierProvider.autoDispose<BookingController, void>(
  BookingController.new,
);
