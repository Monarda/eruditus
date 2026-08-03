import os
import pathlib
import tempfile
import unittest
from unittest.mock import patch

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
            with patch.dict(os.environ, {"ARS_RULEBOOK_ROOT": tmp}):
                self.assertEqual(sources.default_root(), pathlib.Path(tmp))

    def test_default_root_without_the_env_var_is_the_sibling_directory(self):
        with patch.dict(os.environ, {}, clear=False):
            os.environ.pop("ARS_RULEBOOK_ROOT", None)
            self.assertEqual(sources.default_root().name, "Ars-Magica-Open-License")

    def test_env_isolation_is_restored_after_tests(self):
        """Verify that mutating os.environ in tests does not affect subsequent tests.

        This test demonstrates that the isolation around ARS_RULEBOOK_ROOT works:
        - Set a sentinel value before running isolated tests
        - Run the env-var tests (which use patch.dict)
        - Verify the sentinel value survives intact
        """
        sentinel = "test-isolation-sentinel"
        os.environ["ARS_RULEBOOK_ROOT"] = sentinel
        try:
            # Simulate what happens when the other tests run and temporarily change the env
            with tempfile.TemporaryDirectory() as tmp:
                with patch.dict(os.environ, {"ARS_RULEBOOK_ROOT": tmp}):
                    self.assertEqual(sources.default_root(), pathlib.Path(tmp))

            with patch.dict(os.environ, {}, clear=False):
                os.environ.pop("ARS_RULEBOOK_ROOT", None)
                self.assertEqual(sources.default_root().name, "Ars-Magica-Open-License")

            # After both isolated sections, the original value must be restored
            self.assertEqual(os.environ.get("ARS_RULEBOOK_ROOT"), sentinel)
        finally:
            del os.environ["ARS_RULEBOOK_ROOT"]


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
