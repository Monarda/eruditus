/// Where a catalog entry or spell came from: an entry the user authored, or
/// one taken from a published book.
///
/// Used by [Spell] and, from here on, by [BaseEffect], [Parameter], and
/// [Modifier] too — one enum for "published or user-created" across every
/// kind of catalog data, rather than a plain string repeated per model.
enum PublicationSource {
  userCreated('user-created'),
  published('published');

  const PublicationSource(this.wireValue);

  final String wireValue;

  static PublicationSource fromWire(String value) => switch (value) {
        'user-created' => PublicationSource.userCreated,
        'published' => PublicationSource.published,
        _ => throw FormatException('Unknown PublicationSource: "$value"'),
      };
}
