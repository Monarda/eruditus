/// The attribution CC BY-SA 4.0 §3(a) requires eruditus to carry for the
/// rulebook text it ships, defined once so `NOTICE.md` and the About screen
/// cannot drift apart.
///
/// **This is content, not chrome, and never enters ARB.** See DECISIONS.md,
/// "Internationalisation": ARB holds the vocabulary that labels the interface;
/// a licensor's own copyright line, creator credit and disclaimer are not ours
/// to translate. The About screen's headings and buttons *are* chrome and do
/// go through `AppLocalizations`.
library;

/// The rulebook checkout these assets were extracted from. Named rather than
/// a branch, so §3(a)(1)(A)(v)'s URI identifies the material actually adapted
/// — the same discipline as `source.lock` (todo item 30).
const String pinnedRulebookCommit = 'ffc1c6b';

/// One licensed work the catalog draws on, with the §3(a)(1) attribution that
/// must be retained *for that work*.
///
/// A list rather than a single notice because §3(a)(1)(A)(i) requires
/// retaining creator identification as supplied *with the material*: a
/// separately published edition — a translation, say — comes with its own
/// translators and its own copyright line, and needs its own entry rather
/// than an appendix to this one.
class SourceEditionAttribution {
  final String creators;
  final String copyrightNotice;
  final String licenceName;
  final String licenceUri;
  final String sourceUri;
  final String modificationNote;

  /// Titles as they appear in `assets/data/books.json`.
  final List<String> books;

  const SourceEditionAttribution({
    required this.creators,
    required this.copyrightNotice,
    required this.licenceName,
    required this.licenceUri,
    required this.sourceUri,
    required this.modificationNote,
    required this.books,
  });
}

const SourceEditionAttribution arsMagicaAttribution = SourceEditionAttribution(
  creators: 'Trident, Inc. d/b/a Atlas Games®. '
      'Open License Markdown version by OriginalMadman.',
  copyrightNotice: 'Based on the material for Ars Magica, © 1993–2024, '
      'licensed by Trident, Inc. d/b/a Atlas Games®.',
  licenceName: 'Creative Commons Attribution-ShareAlike 4.0 International',
  licenceUri: 'https://creativecommons.org/licenses/by-sa/4.0/',
  sourceUri: 'https://github.com/OriginalMadman/Ars-Magica-Open-License'
      '/tree/$pinnedRulebookCommit',
  modificationNote: 'This material has been modified: guideline and spell text '
      'was transcribed, restructured into JSON, assigned identifiers, and in '
      'places corrected. The source itself is a corrected transcription of the '
      'published books. See scripts/spell_import/ for what the extractor does.',
  books: <String>[
    'Ars Magica Fifth Edition',
    'Ars Magica 5e - Houses of Hermes: Mystery Cults',
  ],
);

/// Every source edition the shipped catalog draws on. Adding one is additive.
const List<SourceEditionAttribution> sourceEditions = <SourceEditionAttribution>[
  arsMagicaAttribution,
];

/// §3(a)(1)(A)(iv) asks only for "a notice that refers to the disclaimer of
/// warranties", which this is. [warrantyDisclaimerFullText] goes further than
/// required and reproduces §5 itself.
const String warrantyDisclaimerNotice =
    'The Licensed Material is offered as-is and as-available, and the licensor '
    'makes no representations or warranties of any kind concerning it. See '
    'Section 5 of the licence for the full disclaimer of warranties and '
    'limitation of liability.';

/// CC BY-SA 4.0 §5(a), reproduced verbatim.
const String warrantyDisclaimerFullText =
    'UNLESS OTHERWISE SEPARATELY UNDERTAKEN BY THE LICENSOR, TO THE EXTENT '
    'POSSIBLE, THE LICENSOR OFFERS THE LICENSED MATERIAL AS-IS AND '
    'AS-AVAILABLE, AND MAKES NO REPRESENTATIONS OR WARRANTIES OF ANY KIND '
    'CONCERNING THE LICENSED MATERIAL, WHETHER EXPRESS, IMPLIED, STATUTORY, OR '
    'OTHER. THIS INCLUDES, WITHOUT LIMITATION, WARRANTIES OF TITLE, '
    'MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, NON-INFRINGEMENT, '
    'ABSENCE OF LATENT OR OTHER DEFECTS, ACCURACY, OR THE PRESENCE OR ABSENCE '
    'OF ERRORS, WHETHER OR NOT KNOWN OR DISCOVERABLE. WHERE DISCLAIMERS OF '
    'WARRANTIES ARE NOT ALLOWED IN FULL OR IN PART, THIS DISCLAIMER MAY NOT '
    'APPLY TO YOU.';

/// §2(b)(2): the licence grants no trademark rights. The text is licensed;
/// the marks are not.
const String trademarkNotice =
    'No trademark rights are granted by the licence. "Ars Magica", "Atlas '
    'Games" and related marks belong to their owners. Order of Hermes, '
    'Tremere, Doissetep and Grimgroth are trademarks of Paradox Interactive '
    'AB. Eruditus is not affiliated with any of them.';

/// §2(a)(6) and §5: nothing here may imply the licensor endorses this app.
const String endorsementNotice =
    'Eruditus is an unofficial, fan-made tool. Nothing in it is endorsed or '
    'sponsored by Atlas Games or by any other rights holder.';

/// How the repository itself is licensed — the §3(b) answer.
///
/// Content-first, not path-first: rulebook-derived content is CC BY-SA 4.0
/// wherever it appears, and the software is MIT by default. Kept identical,
/// character-for-character, to the opening paragraph of NOTICE.md's "How
/// eruditus is licensed" section — test/licensing/repo_licence_files_test.dart
/// asserts NOTICE.md contains this exact string.
const String repoLicenceSummary =
    'Eruditus is licensed in two halves: rulebook-derived content is Adapted '
    'Material under CC BY-SA 4.0 wherever it appears in this repository, and '
    'everything else is MIT. That currently includes assets/data, '
    'scripts/spell_import/resolutions.json, '
    'scripts/spell_import/hand_authored_templates.json and '
    'scripts/spell_import/container_modes.json. See LICENSE and NOTICE.md.';
