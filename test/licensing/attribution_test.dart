import 'package:eruditus/data/datasources/asset_data_loader.dart';
import 'package:eruditus/licensing/attribution.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the Ars Magica attribution carries every CC BY-SA 4.0 §3(a) part', () {
    const a = arsMagicaAttribution;

    test('(A)(i) identifies the creators, including the transcriber', () {
      expect(a.creators, contains('Atlas Games'));
      expect(a.creators, contains('OriginalMadman'),
          reason: '§3(a)(1)(A)(i) covers "any others designated to receive '
              'attribution" — the markdown transcription is credited in the '
              'source material and must be retained');
    });

    test('(A)(ii) carries a copyright notice with the years', () {
      expect(a.copyrightNotice, contains('1993'));
      expect(a.copyrightNotice, contains('2024'));
      expect(a.copyrightNotice, contains('Trident'));
    });

    test('(A)(iii) names the licence', () {
      expect(a.licenceName, 'Creative Commons Attribution-ShareAlike 4.0 International');
    });

    test('(A)(v) and (C) give a URI for the material and for the licence', () {
      expect(a.sourceUri, contains('github.com/OriginalMadman/Ars-Magica-Open-License'));
      expect(a.sourceUri, contains(pinnedRulebookCommit),
          reason: 'the URI must identify the material we actually adapted, '
              'not a moving branch — see todo item 30');
      expect(a.licenceUri, 'https://creativecommons.org/licenses/by-sa/4.0/');
    });

    test('(B) indicates that we modified the material', () {
      expect(a.modificationNote, isNotEmpty);
      expect(a.modificationNote.toLowerCase(), contains('modif'));
    });

    test('it names the books actually shipped in assets/data', () {
      expect(a.books, containsAll(<String>[
        'Ars Magica Fifth Edition',
        'Ars Magica 5e - Houses of Hermes: Mystery Cults',
      ]));
    });

    test('it names exactly the books in assets/data/books.json, so a third '
        'book cannot be silently under-credited', () async {
      final catalogTitles = (await AssetDataLoader().loadBooks())
          .map((book) => book.title)
          .toSet();

      expect(a.books.toSet(), catalogTitles,
          reason: 'assets/data/books.json and arsMagicaAttribution.books have '
              'drifted apart — §3(a)(1)(A)(i) attribution is per-work, so '
              'every book in the catalog needs an entry here');
    });
  });

  test('(A)(iv) is a notice referring to the disclaimer of warranties', () {
    expect(warrantyDisclaimerNotice, isNotEmpty);
    expect(warrantyDisclaimerNotice.toLowerCase(), contains('warrant'));
  });

  test('the full §5 disclaimer text is available as well', () {
    expect(warrantyDisclaimerFullText, contains('AS-IS'));
    expect(warrantyDisclaimerFullText, contains('MERCHANTABILITY'));
  });

  test('trademarks are disclaimed, because §2(b)(2) does not license them', () {
    expect(trademarkNotice.toLowerCase(), contains('trademark'));
    expect(trademarkNotice, contains('Ars Magica'));
  });

  test('endorsement is disclaimed, per §2(a)(6) and §5', () {
    expect(endorsementNotice.toLowerCase(), contains('endorse'));
    expect(endorsementNotice, contains('Atlas Games'));
  });

  test('the repo licence summary states both halves of the split', () {
    expect(repoLicenceSummary, contains('MIT'));
    expect(repoLicenceSummary, contains('CC BY-SA 4.0'));
    expect(repoLicenceSummary, contains('assets/data'));
  });

  test('sourceEditions is a list, so a second edition is additive', () {
    expect(sourceEditions, contains(arsMagicaAttribution));
    expect(sourceEditions, isA<List<SourceEditionAttribution>>());
  });
}
