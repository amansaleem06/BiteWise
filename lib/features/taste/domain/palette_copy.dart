/// User-facing names for the personal eating brief (formerly “AI diet plan”).
abstract final class PaletteCopy {
  static const name = 'Your Palette';
  static const feedTab = 'Palette';
  static const feedSubtitle = 'Plates that fit how you eat';
  static const passportBlurb =
      'Pick cuisines, dishes, and anything to skip — we\'ll plate a week around you.';
  static const emptyFeedTitle = 'Palette is waiting';
  static const emptyFeedSubtitle =
      'Build Your Palette and we\'ll serve plates that match it here.';
  static const emptyFeedAction = 'Open Your Palette';
}

/// Common allergy / skip chips shown while building [PaletteCopy.name].
abstract final class Avoidance {
  static const common = <String>[
    'Nuts',
    'Peanuts',
    'Dairy',
    'Gluten',
    'Eggs',
    'Shellfish',
    'Fish',
    'Soy',
    'Sesame',
    'Pork',
  ];
}
