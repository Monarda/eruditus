import unittest

from scripts.spell_import import sources


class ResolveBookTest(unittest.TestCase):
    def test_prefers_reviewed_over_raw(self):
        path = sources.resolve_book(sources.DE_TITLE)
        self.assertEqual(path.parent.name, "reviewed")

    def test_falls_back_to_wip_when_not_reviewed(self):
        path = sources.resolve_book("Ars Magica 5e - Magi of Hermes")
        self.assertEqual(path.parent.name, "wip")

    def test_uses_raw_only_as_last_resort(self):
        path = sources.resolve_book("Ars Magica 5e - Mundane Beasts")
        self.assertIn(path.parent.name, ("wip", "raw-md"))

    def test_unknown_book_raises(self):
        with self.assertRaises(FileNotFoundError):
            sources.resolve_book("Ars Magica 5e - No Such Book")

    def test_do_not_use_files_are_never_returned(self):
        for path in sources.all_books().values():
            self.assertNotIn("DO NOT USE", path.name)

    def test_read_lines_strips_newlines_but_keeps_blockquotes(self):
        lines = sources.read_lines(sources.resolve_book(sources.DE_TITLE))
        self.assertGreater(len(lines), 10000)
        self.assertFalse(any(line.endswith("\n") for line in lines))
        self.assertTrue(any(line.startswith(">") for line in lines))

    def test_sanctuary_of_ice_raw_md_collapses_into_reviewed_entry(self):
        title = "Ars Magica 4e - Sanctuary of Ice - The Greater Alps Tribunal"
        books = sources.all_books()
        self.assertIn(title, books)
        self.assertNotIn("Ars Magica 4e - Sanctuary of Ice", books)
        self.assertEqual(books[title].parent.name, "reviewed")

    def test_against_the_dark_raw_md_collapses_into_reviewed_entry(self):
        title = "Ars Magica 5e - Against the Dark - The Transylvanian Tribunal"
        books = sources.all_books()
        self.assertIn(title, books)
        self.assertNotIn(
            "Ars Magica 5e - Tribunal - Against the Dark - The Transylvanian Tribunal",
            books,
        )
        self.assertEqual(books[title].parent.name, "reviewed")

    def test_definitive_edition_raw_md_duplicates_collapse_into_reviewed_entry(self):
        # raw-md holds two more OCR renders of the DE core rulebook under
        # filenames that don't share DE_TITLE's stem at all ("Digital _alt
        # version", "High Contrast"), so they must be explicitly aliased
        # the same way Sanctuary of Ice / Against the Dark are above.
        books = sources.all_books()
        self.assertEqual(books[sources.DE_TITLE].parent.name, "reviewed")
        self.assertNotIn("Ars Magica Definitive Digital _alt version", books)
        self.assertNotIn("Ars Magica Definitive High Contrast", books)

        leaked_de_variants = [
            title
            for title, path in books.items()
            if path.parent.name == "raw-md" and "Definitive" in path.stem
        ]
        self.assertEqual(leaked_de_variants, [])

    def test_every_raw_md_title_is_triaged_against_reviewed_and_wip(self):
        """Corpus-wide audit: every raw-md file's title (after suffix and
        edition-tag stripping, and _TITLE_ALIASES lookup) must either
        collapse into a title already produced by reviewed/ or wip/, or be
        explicitly acknowledged below as legitimately raw-only content (a
        book with no reviewed/wip copy at all).

        This is the generic regression test for the bug class that let the
        Sanctuary of Ice, Against the Dark, and Definitive Edition raw-md
        duplicates ship unnoticed: a raw-md filename that diverges from its
        reviewed/wip counterpart by more than what _SUFFIX/_EDITION_TAG
        strip, and isn't yet listed in _TITLE_ALIASES, slips through
        all_books() as a second entry for a book that already has a better
        copy. Any *new* untriaged raw-md file -- not just the three known
        so far -- will fail this test and force a deliberate decision:
        either add a _TITLE_ALIASES entry, or add the title to
        known_raw_only_titles below because it is genuinely new content.
        """
        root = sources.RULEBOOK_ROOT
        canonical_titles = set()
        for folder in ("reviewed", "wip"):
            directory = root / folder
            if not directory.is_dir():
                continue
            for path in directory.glob("*.md"):
                canonical_titles.add(sources.title_of(path))

        # Titles confirmed, by hand, to have no reviewed/wip copy at all --
        # legitimately raw-only content, not an untriaged OCR duplicate.
        # Empty today: every raw-md file in this corpus collapses into a
        # reviewed/wip title once _TITLE_ALIASES is applied.
        known_raw_only_titles: set[str] = set()

        untriaged = []
        for path in sorted((root / "raw-md").glob("*.md")):
            if "DO NOT USE" in path.name:
                continue
            title = sources.title_of(path)
            if title in canonical_titles or title in known_raw_only_titles:
                continue
            untriaged.append((title, path.name))

        self.assertEqual(
            untriaged,
            [],
            "raw-md file(s) whose title matches neither a reviewed/wip "
            "book nor a known raw-only title -- this is either a new OCR "
            "duplicate needing a _TITLE_ALIASES entry, or legitimately "
            "new raw-only content that should be added to "
            "known_raw_only_titles in this test.",
        )
