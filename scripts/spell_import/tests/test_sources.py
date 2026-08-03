import os
import pathlib
import tempfile
import unittest

from scripts.spell_import import sources


class ResolveBookTest(unittest.TestCase):
    def test_de_resolves_to_reviewed(self):
        path = sources.resolve_book(sources.DE_TITLE)
        self.assertEqual(path.parent.name, "reviewed")

    def test_falls_back_to_wip_when_not_reviewed(self):
        path = sources.resolve_book("Ars Magica 5e - Magi of Hermes")
        self.assertEqual(path.parent.name, "wip")

    def test_unknown_book_raises(self):
        with self.assertRaises(FileNotFoundError):
            sources.resolve_book("Ars Magica 5e - No Such Book")

    def test_read_lines_strips_newlines_but_keeps_blockquotes(self):
        lines = sources.read_lines(sources.resolve_book(sources.DE_TITLE))
        self.assertGreater(len(lines), 10000)
        self.assertFalse(any(line.endswith("\n") for line in lines))
        self.assertTrue(any(line.startswith(">") for line in lines))


class RootOverrideTest(unittest.TestCase):
    def test_all_books_reads_an_explicit_root(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            (root / "reviewed").mkdir()
            (root / "reviewed" / "Some Book.md").write_text("x", encoding="utf-8")
            self.assertEqual(set(sources.all_books(root)), {"Some Book"})

    def test_reviewed_wins_over_wip_for_the_same_title(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            for folder in ("reviewed", "wip"):
                (root / folder).mkdir()
                (root / folder / "Some Book.md").write_text(folder, encoding="utf-8")
            self.assertEqual(sources.resolve_book("Some Book", root).parent.name, "reviewed")

    def test_env_var_overrides_the_default_root(self):
        with tempfile.TemporaryDirectory() as tmp:
            os.environ["ARS_RULEBOOK_ROOT"] = tmp
            try:
                self.assertEqual(sources.default_root(), pathlib.Path(tmp))
            finally:
                del os.environ["ARS_RULEBOOK_ROOT"]

    def test_default_root_without_the_env_var_is_the_sibling_directory(self):
        os.environ.pop("ARS_RULEBOOK_ROOT", None)
        self.assertEqual(sources.default_root().name, "Ars-Magica-Open-License")


class SuggestionTest(unittest.TestCase):
    def test_unknown_title_close_to_a_real_one_is_suggested(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            (root / "reviewed").mkdir()
            (root / "reviewed" / "Ars Magica - Definitive Edition.md").write_text("x", encoding="utf-8")
            with self.assertRaises(FileNotFoundError) as caught:
                sources.resolve_book("Ars Magica - Definitive Editon", root)
            self.assertIn("did you mean", str(caught.exception).lower())
            self.assertIn("Ars Magica - Definitive Edition", str(caught.exception))

    def test_unknown_title_with_no_close_match_still_raises_cleanly(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            (root / "reviewed").mkdir()
            (root / "reviewed" / "Ars Magica - Definitive Edition.md").write_text("x", encoding="utf-8")
            with self.assertRaises(FileNotFoundError) as caught:
                sources.resolve_book("Completely Unrelated", root)
            self.assertNotIn("did you mean", str(caught.exception).lower())
