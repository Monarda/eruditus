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
