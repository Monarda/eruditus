import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/utils/map_serialization.dart';

/// Where a catalog entry or spell came from, and — if published — where.
///
/// Self-validating: the published/user-created ⟺ has-citations rule is
/// enforced in this constructor, once, rather than by every model that
/// embeds a [Provenance] remembering to call a shared validator function.
class Provenance {
  final PublicationSource source;
  final List<Citation> citations;

  Provenance({required this.source, this.citations = const []}) {
    if (source == PublicationSource.published && citations.isEmpty) {
      throw FormatException('Provenance: a published entry needs at least one citation');
    }
    if (source == PublicationSource.userCreated && citations.isNotEmpty) {
      throw FormatException('Provenance: a user-created entry cannot have citations');
    }
  }

  Map<String, dynamic> toMap() => {
        'source': source.wireValue,
        'citations': citations.map((c) => c.toMap()).toList(),
      };

  factory Provenance.fromMap(Map<String, dynamic> map) => Provenance(
        source: PublicationSource.fromWire(requireField<String>(map, 'source', 'Provenance')),
        citations: (map['citations'] as List?)
                ?.map((c) => Citation.fromMap(c as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}
