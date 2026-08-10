import 'package:equatable/equatable.dart';

/// Lightweight restaurant reference used for tagging posts.
///
/// The full Restaurant entity (hours, menu, gallery, ...) arrives with the
/// Restaurants milestone; posts only need identity + display fields.
class RestaurantRef extends Equatable {
  const RestaurantRef({required this.id, required this.name, this.city});

  final String id;
  final String name;
  final String? city;

  @override
  List<Object?> get props => [id, name, city];
}
