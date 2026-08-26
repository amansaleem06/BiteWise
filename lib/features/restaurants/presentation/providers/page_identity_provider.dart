import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/services/restaurant_page_voice.dart';
import '../../domain/entities/restaurant.dart';
import 'restaurant_providers.dart';

const _kPreferPersonal = 'tastewise.actAsPersonal';

/// Whether a restaurant owner is currently speaking as their page (Facebook-style)
/// or as their personal account.
class PageIdentity {
  const PageIdentity({
    required this.preferPersonal,
    this.ownedRestaurantId,
  });

  final bool preferPersonal;
  final String? ownedRestaurantId;

  bool get hasPage =>
      ownedRestaurantId != null && ownedRestaurantId!.isNotEmpty;

  bool get actingAsPage => hasPage && !preferPersonal;
}

class PageIdentityController extends StateNotifier<PageIdentity> {
  PageIdentityController(this._ownedRestaurantId)
      : super(
          PageIdentity(
            preferPersonal: false,
            ownedRestaurantId: _ownedRestaurantId,
          ),
        ) {
    _hydrate();
  }

  final String? _ownedRestaurantId;

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final prefer = prefs.getBool(_kPreferPersonal) ?? false;
    if (!mounted) return;
    state = PageIdentity(
      preferPersonal: prefer,
      ownedRestaurantId: _ownedRestaurantId,
    );
  }

  Future<void> setPreferPersonal(bool value) async {
    state = PageIdentity(
      preferPersonal: value,
      ownedRestaurantId: _ownedRestaurantId,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPreferPersonal, value);
  }
}

final pageIdentityProvider =
    StateNotifierProvider<PageIdentityController, PageIdentity>((ref) {
  final owned = ref.watch(currentUserProvider)?.ownedRestaurantId;
  return PageIdentityController(owned);
});

final actingPageVoiceProvider = FutureProvider<RestaurantPageVoice?>((ref) {
  final identity = ref.watch(pageIdentityProvider);
  if (!identity.actingAsPage) return Future.value(null);
  return RestaurantPageVoice.load();
});

final ownedRestaurantProvider = Provider<Restaurant?>((ref) {
  final id = ref.watch(currentUserProvider)?.ownedRestaurantId;
  if (id == null || id.isEmpty) return null;
  return ref.watch(restaurantControllerProvider(id)).valueOrNull;
});
