import 'package:eruditus/utils/map_serialization.dart';

class RequiredRequisite {
  final String art;

  RequiredRequisite({required this.art});

  Map<String, dynamic> toMap() => {'art': art};

  factory RequiredRequisite.fromMap(Map<String, dynamic> map) =>
      RequiredRequisite(art: requireField<String>(map, 'art', 'RequiredRequisite'));
}

class AdditionalRequisite {
  final String art;
  final int magnitude; // Always +1

  AdditionalRequisite({
    required this.art,
    this.magnitude = 1,
  });

  Map<String, dynamic> toMap() => {
    'art': art,
    'magnitude': magnitude,
  };

  factory AdditionalRequisite.fromMap(Map<String, dynamic> map) =>
      AdditionalRequisite(
        art: requireField<String>(map, 'art', 'AdditionalRequisite'),
        magnitude: map['magnitude'] as int? ?? 1,
      );
}
