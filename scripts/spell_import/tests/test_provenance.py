import json
import pathlib
import tempfile
import unittest

from scripts.spell_import import provenance


def identity(sha="a" * 64, rev=None, parsed=360, imported=250):
    return provenance.SourceIdentity(
        book="Ars Magica - Definitive Edition (Core Rules)",
        path="reviewed/Ars Magica - Definitive Edition (Core Rules).md",
        sha256=sha,
        rulebook=rev,
        spells_parsed=parsed,
        spells_imported=imported,
    )


REV = provenance.RulebookRevision(commit="97cc62d", date="2026-07-18", subject="Review chapter 16")


class DescribeTest(unittest.TestCase):
    def test_hashes_the_file_and_records_a_posix_relative_path(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            (root / "reviewed").mkdir()
            book = root / "reviewed" / "Some Book.md"
            book.write_text("hello", encoding="utf-8")
            found = provenance.describe("Some Book", book, root, parsed=3, imported=2)
            self.assertEqual(found.path, "reviewed/Some Book.md")
            # sha256("hello")
            self.assertEqual(
                found.sha256,
                "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824",
            )
            self.assertEqual((found.spells_parsed, found.spells_imported), (3, 2))

    def test_a_non_git_root_yields_no_revision_rather_than_raising(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            (root / "reviewed").mkdir()
            book = root / "reviewed" / "Some Book.md"
            book.write_text("hello", encoding="utf-8")
            self.assertIsNone(provenance.describe("Some Book", book, root).rulebook)


class LockFileTest(unittest.TestCase):
    def test_round_trips_with_a_revision(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = pathlib.Path(tmp) / "source.lock"
            provenance.write(identity(rev=REV), path)
            self.assertEqual(provenance.load(path), identity(rev=REV))

    def test_round_trips_without_a_revision(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = pathlib.Path(tmp) / "source.lock"
            provenance.write(identity(rev=None), path)
            loaded = provenance.load(path)
            self.assertIsNone(loaded.rulebook)
            self.assertEqual(loaded, identity(rev=None))

    def test_absent_lock_loads_as_none(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertIsNone(provenance.load(pathlib.Path(tmp) / "nope.lock"))

    def test_written_lock_is_readable_json_ending_in_a_newline(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = pathlib.Path(tmp) / "source.lock"
            provenance.write(identity(rev=REV), path)
            text = path.read_text(encoding="utf-8")
            self.assertTrue(text.endswith("\n"))
            self.assertEqual(json.loads(text)["rulebook"]["commit"], "97cc62d")

    def test_writing_twice_is_byte_identical(self):
        with tempfile.TemporaryDirectory() as tmp:
            first = pathlib.Path(tmp) / "a.lock"
            second = pathlib.Path(tmp) / "b.lock"
            provenance.write(identity(rev=REV), first)
            provenance.write(identity(rev=REV), second)
            self.assertEqual(first.read_bytes(), second.read_bytes())


class MatchesTest(unittest.TestCase):
    def test_only_the_hash_decides(self):
        other_rev = provenance.RulebookRevision(commit="ffffff", date="2026-08-01", subject="x")
        self.assertTrue(provenance.matches(identity(rev=REV), identity(rev=other_rev)))

    def test_a_different_hash_is_a_mismatch(self):
        self.assertFalse(provenance.matches(identity(sha="a" * 64), identity(sha="b" * 64)))

    def test_an_absent_lock_never_matches(self):
        self.assertFalse(provenance.matches(None, identity()))


class DescribeChangeTest(unittest.TestCase):
    def test_names_both_revisions_and_both_counts(self):
        old = identity(sha="a" * 64, rev=REV, parsed=360, imported=250)
        new = identity(
            sha="b" * 64,
            rev=provenance.RulebookRevision("005a33c", "2026-07-13", "Merge pull request #54"),
            parsed=346,
            imported=241,
        )
        message = provenance.describe_change(old, new)
        self.assertIn("97cc62d", message)
        self.assertIn("Review chapter 16", message)
        self.assertIn("005a33c", message)
        self.assertIn("360", message)
        self.assertIn("346", message)
        self.assertIn("--accept-source", message)

    def test_reads_sensibly_when_no_lock_exists_yet(self):
        message = provenance.describe_change(None, identity())
        self.assertIn("no source.lock", message)
        self.assertIn("--accept-source", message)
