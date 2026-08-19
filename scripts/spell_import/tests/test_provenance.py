import json
import pathlib
import shutil
import subprocess
import tempfile
import unittest
from unittest import mock

from scripts.spell_import import provenance


def identity(book_id="arm5-core", sha="a" * 64, rev=None, parsed=360, imported=250):
    return provenance.SourceIdentity(
        book_id=book_id,
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
            found = provenance.describe("some-book", "Some Book", book, root, parsed=3, imported=2)
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
            self.assertIsNone(provenance.describe("some-book", "Some Book", book, root).rulebook)


class GitRevisionDegradationTest(unittest.TestCase):
    """Test that git_revision gracefully handles all failure modes."""

    def test_git_absent_from_path_yields_none(self):
        """FileNotFoundError (git not found) is caught and returns None."""
        with mock.patch("subprocess.run") as mock_run:
            mock_run.side_effect = FileNotFoundError("git not found")
            result = provenance.git_revision(pathlib.Path("/tmp"), "some/file.md")
            self.assertIsNone(result)

    def test_non_zero_exit_code_yields_none(self):
        """Non-zero exit code (e.g., file not tracked) returns None."""
        with mock.patch("subprocess.run") as mock_run:
            mock_run.return_value = mock.Mock(returncode=128, stdout="")
            result = provenance.git_revision(pathlib.Path("/tmp"), "some/file.md")
            self.assertIsNone(result)

    def test_malformed_stdout_yields_none(self):
        """Stdout not matching exactly 3 null-separated parts returns None."""
        with mock.patch("subprocess.run") as mock_run:
            # Only 2 parts instead of 3
            mock_run.return_value = mock.Mock(returncode=0, stdout="abc\x00def")
            result = provenance.git_revision(pathlib.Path("/tmp"), "some/file.md")
            self.assertIsNone(result)

    def test_empty_stdout_yields_none(self):
        """Empty stdout returns None."""
        with mock.patch("subprocess.run") as mock_run:
            mock_run.return_value = mock.Mock(returncode=0, stdout="")
            result = provenance.git_revision(pathlib.Path("/tmp"), "some/file.md")
            self.assertIsNone(result)

    def test_subprocess_timeout_yields_none(self):
        """subprocess.TimeoutExpired is caught and returns None."""
        with mock.patch("subprocess.run") as mock_run:
            mock_run.side_effect = subprocess.TimeoutExpired("git", 10)
            result = provenance.git_revision(pathlib.Path("/tmp"), "some/file.md")
            self.assertIsNone(result)


class LockFileTest(unittest.TestCase):
    def test_round_trips_with_a_revision(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = pathlib.Path(tmp) / "source.lock"
            ident = identity(rev=REV)
            provenance.write({ident.book_id: ident}, path)
            self.assertEqual(provenance.load(path), {ident.book_id: ident})

    def test_round_trips_without_a_revision(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = pathlib.Path(tmp) / "source.lock"
            ident = identity(rev=None)
            provenance.write({ident.book_id: ident}, path)
            loaded = provenance.load(path)
            self.assertIsNone(loaded[ident.book_id].rulebook)
            self.assertEqual(loaded, {ident.book_id: ident})

    def test_absent_lock_loads_as_none(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(provenance.load(pathlib.Path(tmp) / "nope.lock"), {})

    def test_a_pre_mapping_lock_raises_a_message_naming_the_cause(self):
        """Rebasing a branch that predates the {book_id: entry} mapping leaves a
        single-identity source.lock on disk. `from_dict` fed one of that
        format's string field values, not a dict, used to fail with a bare
        AttributeError; it must instead name the old format and what to do.
        """
        with tempfile.TemporaryDirectory() as tmp:
            path = pathlib.Path(tmp) / "source.lock"
            old_format = {
                "book": "Ars Magica - Definitive Edition (Core Rules)",
                "path": "reviewed/Ars Magica - Definitive Edition (Core Rules).md",
                "sha256": "a" * 64,
                "rulebook": None,
                "spellsParsed": 360,
                "spellsImported": 250,
            }
            path.write_text(json.dumps(old_format), encoding="utf-8")
            with self.assertRaises(ValueError) as raised:
                provenance.load(path)
            message = str(raised.exception)
            self.assertIn("old", message)
            self.assertIn("source.lock", message)
            self.assertIn("--accept-source", message)

    def test_written_lock_is_readable_json_ending_in_a_newline(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = pathlib.Path(tmp) / "source.lock"
            ident = identity(rev=REV)
            provenance.write({ident.book_id: ident}, path)
            text = path.read_text(encoding="utf-8")
            self.assertTrue(text.endswith("\n"))
            self.assertEqual(json.loads(text)[ident.book_id]["rulebook"]["commit"], "97cc62d")

    def test_writing_twice_is_byte_identical(self):
        with tempfile.TemporaryDirectory() as tmp:
            first = pathlib.Path(tmp) / "a.lock"
            second = pathlib.Path(tmp) / "b.lock"
            ident = identity(rev=REV)
            provenance.write({ident.book_id: ident}, first)
            provenance.write({ident.book_id: ident}, second)
            self.assertEqual(first.read_bytes(), second.read_bytes())


class MatchesTest(unittest.TestCase):
    def test_only_the_hash_decides(self):
        other_rev = provenance.RulebookRevision(commit="ffffff", date="2026-08-01", subject="x")
        recorded = identity(rev=REV)
        self.assertTrue(
            provenance.matches({recorded.book_id: recorded}, identity(rev=other_rev)))

    def test_a_different_hash_is_a_mismatch(self):
        recorded = identity(sha="a" * 64)
        self.assertFalse(
            provenance.matches({recorded.book_id: recorded}, identity(sha="b" * 64)))

    def test_an_absent_lock_never_matches(self):
        self.assertFalse(provenance.matches({}, identity()))


class DescribeChangeTest(unittest.TestCase):
    def test_names_both_revisions_and_both_counts(self):
        old = identity(sha="a" * 64, rev=REV, parsed=360, imported=250)
        new = identity(
            sha="b" * 64,
            rev=provenance.RulebookRevision("005a33c", "2026-07-13", "Merge pull request #54"),
            parsed=346,
            imported=241,
        )
        message = provenance.describe_change({old.book_id: old}, new)
        self.assertIn("97cc62d", message)
        self.assertIn("Review chapter 16", message)
        self.assertIn("005a33c", message)
        self.assertIn("360", message)
        self.assertIn("346", message)
        self.assertIn("--accept-source", message)

    def test_reads_sensibly_when_no_lock_exists_yet(self):
        message = provenance.describe_change({}, identity())
        self.assertIn("has no record of", message)
        self.assertIn("--accept-source", message)


class MultiBookLockTest(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmpdir, ignore_errors=True)

    def _identity(self, book_id="arm5-core", sha="abc123"):
        return provenance.SourceIdentity(
            book_id=book_id, book="A Book", path="reviewed/A Book.md",
            sha256=sha, rulebook=None, spells_parsed=10, spells_imported=9)

    def test_the_lock_round_trips_several_books(self):
        path = pathlib.Path(self.tmpdir) / "source.lock"
        identities = {
            "arm5-core": self._identity("arm5-core", "aaa"),
            "arm5-hohmc": self._identity("arm5-hohmc", "bbb"),
        }
        provenance.write(identities, path)
        loaded = provenance.load(path)
        self.assertEqual(sorted(loaded), ["arm5-core", "arm5-hohmc"])
        self.assertEqual(loaded["arm5-hohmc"].sha256, "bbb")

    def test_an_absent_lock_loads_as_an_empty_mapping(self):
        path = pathlib.Path(self.tmpdir) / "nonesuch.lock"
        self.assertEqual(provenance.load(path), {})

    def test_matches_compares_the_named_book_only(self):
        lock = {"arm5-core": self._identity("arm5-core", "aaa"),
                "arm5-hohmc": self._identity("arm5-hohmc", "bbb")}
        self.assertTrue(provenance.matches(lock, self._identity("arm5-hohmc", "bbb")))
        self.assertFalse(provenance.matches(lock, self._identity("arm5-hohmc", "ccc")))

    def test_a_book_absent_from_the_lock_does_not_match(self):
        lock = {"arm5-core": self._identity("arm5-core", "aaa")}
        self.assertFalse(provenance.matches(lock, self._identity("arm5-hohmc", "bbb")))

    def test_describe_change_names_the_book_that_moved(self):
        lock = {"arm5-hohmc": self._identity("arm5-hohmc", "bbb")}
        message = provenance.describe_change(lock, self._identity("arm5-hohmc", "ccc"))
        self.assertIn("arm5-hohmc", message)


class PinnedRevisionTest(unittest.TestCase):
    """The commit CI checks the rulebook out at.

    The workflow used to read this straight out of the lock JSON, which is
    how keying the lock by book id broke CI without a test noticing. The
    rule lives here now so it is reachable from the suite.
    """

    @staticmethod
    def _at(book_id, commit, date):
        return identity(
            book_id=book_id,
            rev=provenance.RulebookRevision(commit=commit, date=date, subject="s"),
        )

    def test_picks_the_newest_recorded_revision(self):
        lock = {
            "arm5-hohmc": self._at("arm5-hohmc", "2539318", "2026-07-18"),
            "arm5-core": self._at("arm5-core", "9c6aee1", "2026-08-16"),
        }
        self.assertEqual(provenance.pinned_revision(lock), "9c6aee1")

    def test_insertion_order_does_not_decide_it(self):
        lock = {
            "arm5-core": self._at("arm5-core", "9c6aee1", "2026-08-16"),
            "arm5-hohmc": self._at("arm5-hohmc", "2539318", "2026-07-18"),
        }
        self.assertEqual(provenance.pinned_revision(lock), "9c6aee1")

    def test_a_book_with_no_revision_is_skipped_rather_than_fatal(self):
        lock = {
            "arm5-core": self._at("arm5-core", "9c6aee1", "2026-08-16"),
            "arm5-hohmc": identity(book_id="arm5-hohmc", rev=None),
        }
        self.assertEqual(provenance.pinned_revision(lock), "9c6aee1")

    def test_none_when_no_book_records_a_revision(self):
        self.assertIsNone(provenance.pinned_revision({"arm5-core": identity(rev=None)}))

    def test_none_for_an_empty_lock(self):
        self.assertIsNone(provenance.pinned_revision({}))

    def test_the_committed_lock_yields_a_revision(self):
        """The regression this exists for: CI must get a sha from the real lock."""
        pinned = provenance.pinned_revision(provenance.load())
        self.assertIsNotNone(pinned, "the committed source.lock pins nothing -- CI cannot run")
        self.assertRegex(pinned, r"^[0-9a-f]{7,40}$")
