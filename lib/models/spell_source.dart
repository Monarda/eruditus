/// Where a spell came from.
///
/// This lives in its own file so widgets, blocs and repositories can import it
/// without pulling in the whole `spell.dart` model graph.
///
/// The wire values match the plain `source` string that [BaseEffect],
/// [Parameter] and [Modifier] still use, so one word means one thing across the
/// codebase. Those catalogs carry no citations — only spells record where they
/// were published.
enum SpellSource {
  userCreated('user-created'),
  published('published');

  const SpellSource(this.wireValue);

  final String wireValue;

  static SpellSource fromWire(String value) => switch (value) {
        'user-created' => SpellSource.userCreated,
        'published' => SpellSource.published,
        _ => throw FormatException('Unknown SpellSource: "$value"'),
      };
}
