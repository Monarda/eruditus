import dataclasses
import json
import unittest

from scripts.spell_import import extract_spells
from scripts.spell_import.sources import REPO_ROOT

LIBRARY = REPO_ROOT / "assets" / "data" / "spell_library.json"


class RunTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.report = extract_spells.run(write=False)

    def test_reports_no_parse_problems(self):
        self.assertEqual(self.report.problems, [])

    def test_every_emitted_spell_has_the_required_fields(self):
        for spell in self.report.spells:
            # printedLevel and description are in this list for the same
            # reason as the rest: dropping either from emit.build_spell would
            # otherwise go unnoticed in Python and surface only in
            # `flutter test`, where asset_data_loader_test.dart reads
            # printedLevel and spell cards fall back to description.
            for field in ("id", "name", "baseEffectId", "rangeId", "durationId",
                          "targetId", "source", "createdAt", "updatedAt",
                          "summary", "description", "printedLevel", "citations"):
                self.assertIn(field, spell, msg=spell.get("id"))
            self.assertEqual(spell["source"], "published")
            self.assertEqual(spell["citations"], [{"bookId": "arm5-core"}])

    def test_ids_are_unique(self):
        ids = [s["id"] for s in self.report.spells]
        self.assertEqual(len(ids), len(set(ids)))

    def test_no_page_numbers_are_invented(self):
        for spell in self.report.spells:
            for citation in spell["citations"]:
                self.assertNotIn("page", citation)

    def test_blocked_spells_are_reported_not_dropped_silently(self):
        # The audit found 74 blocked. Assert a range, not a number: each
        # blocker item that clears moves spells from blocked to imported, and
        # this test should not need editing when that happens.
        self.assertGreater(len(self.report.blocked), 0)
        self.assertLess(len(self.report.blocked), 120)


class RegenerationTest(unittest.TestCase):
    """Assertion 5: running the extractor produces no diff.

    This lives in Python rather than `flutter test` because it has to run the
    extractor. CI must run both suites; neither alone covers all five
    assertions.
    """

    def test_committed_library_matches_a_fresh_run(self):
        from scripts.spell_import import provenance

        report = extract_spells.run(write=False)
        committed = json.loads(LIBRARY.read_text(encoding="utf-8"))
        self.assertEqual(
            extract_spells.serialize(report.spells),
            extract_spells.serialize(committed),
            msg="\n\n" + extract_spells.regeneration_failure_message(
                provenance.load(), report.identity
            ),
        )

    def test_two_runs_are_byte_identical(self):
        first = extract_spells.serialize(extract_spells.run(write=False).spells)
        second = extract_spells.serialize(extract_spells.run(write=False).spells)
        self.assertEqual(first, second)


class HandDerivedTest(unittest.TestCase):
    """Of the 3 spells with no printed design line, only 1 has a legitimate
    hand-derivation. The other 2 were investigated, not skipped: their own
    prose explicitly disclaims normal Hermetic guideline arithmetic
    ("does not conform to the normal InAq guidelines", "fits poorly into
    the normal framework of Hermetic magic", Mercurian Ritual), and no
    combination of real base level + real magnitude tokens reproduces their
    printed level without inventing a requisite or an unimplemented
    modifier the text doesn't support. See HAND_DERIVED's module docstring
    in extract_spells.py for the full per-spell reasoning.
    """

    def test_the_derivable_spell_is_imported(self):
        report = extract_spells.run(write=False)
        names = {s["name"] for s in report.spells}
        self.assertIn("Enchantment of the Scrying Pool", names)

    def test_the_two_non_derivable_spells_stay_correctly_blocked(self):
        report = extract_spells.run(write=False)
        blocked_names = {name for name, _ in report.blocked}
        for name in ["Whispering Winds", "Hermes' Portal"]:
            self.assertIn(name, blocked_names)


class KnownUnresolvableStalenessTest(unittest.TestCase):
    """Guards extract_spells.KNOWN_UNRESOLVABLE against silent staleness.

    Each entry there records a human judgement that a spell's candidate set
    is genuinely, irreducibly ambiguous. KNOWN_UNRESOLVABLE routes straight
    to `blocked`, bypassing Ledger.resolve() entirely -- which means it also
    bypasses resolve()'s own StaleEntry check. If a future catalog change
    (e.g. todo item 22's rebuild of base_effects.json, which the spec
    specifically calls out as touching Muto Terram -- mute-3a/3b/3c is one
    of these four) narrows or changes the candidate set, this entry's
    reason silently stops applying and nothing else would notice.
    """

    def test_every_known_unresolvable_spell_is_still_genuinely_ambiguous(self):
        from scripts.spell_import import blocks, catalog as catalog_module, designline, sources

        lines = sources.read_lines(sources.resolve_book(sources.DE_TITLE))
        parsed, _ = blocks.parse_de(lines)
        cat = catalog_module.Catalog.load()
        by_id = {catalog_module.slug_id(b.technique, b.form, b.name): b for b in parsed}

        stale = []
        for spell_id in extract_spells.KNOWN_UNRESOLVABLE:
            block = by_id.get(spell_id)
            if block is None:
                stale.append((spell_id, "no longer a parsed spell at all"))
                continue
            design = designline.parse_design(block.design_line)
            candidates = cat.candidates(block.technique, block.form, design.base_level)
            if len(candidates) < 2:
                stale.append((spell_id, f"only {len(candidates)} candidate(s) now: {candidates}"))

        self.assertEqual(stale, [], msg=(
            "KNOWN_UNRESOLVABLE entries no longer genuinely ambiguous -- "
            "remove them from extract_spells.py and let the ledger (or a "
            "fresh resolutions.json entry) take over: "
        ) + str(stale))


GENERAL_BLOCKED = {
    "Aegis of the Hearth": "no design line; a Major Breakthrough outside the guidelines",
    "Wizard's Vigil": "no design line",
    "Sight of the True Form": "no design line",
    "Ward against Faeries of the Mountain": "no design line; a prose cross-reference to another spell",
    "Dispel the Phantom Image": "no Perdo Imaginem General row in the rulebook",
    "Lay to Rest the Haunting Spirit": "no Perdo Mentem General row in the rulebook",
    "Watching Ward": "design line token 'Duration is non-standard' — todo item 26",
    "Restore the Moved Image": "design line does not account for the stat line",
    "The Invisible Eye Revealed": "design line does not account for the stat line",
    "Wizard's Communion": "prose disclaims guideline arithmetic",
}


class GeneralBlockedStalenessTest(unittest.TestCase):
    """A blocker that quietly stops applying must fail, not pass silently."""

    def test_every_recorded_general_blocker_still_blocks(self):
        blocked_names = {name for name, _ in extract_spells.run(write=False).blocked}

        no_longer_blocked = sorted(set(GENERAL_BLOCKED) - blocked_names)

        self.assertEqual(
            no_longer_blocked, [],
            "these now import — remove them from GENERAL_BLOCKED and from the "
            "spec's blocked list rather than leaving a stale record")


class WriteGateTest(unittest.TestCase):
    """The gate is exercised through run()'s return value, not by writing.

    These must never call run(write=True) against the real asset — a test
    that rewrites committed data is a test that can destroy it.
    """

    def test_report_carries_the_source_identity(self):
        report = extract_spells.run(write=False)
        self.assertIsNotNone(report.identity.sha256)
        self.assertEqual(len(report.identity.sha256), 64)
        self.assertEqual(report.identity.spells_parsed, 360)

    def test_report_carries_a_design_line_per_imported_spell(self):
        report = extract_spells.run(write=False)
        for spell in report.spells:
            self.assertIn(spell["id"], report.design_lines, msg=spell["id"])

    def test_source_lock_exists(self):
        from scripts.spell_import import provenance
        # Existence gate only. The lock is diagnostic, not gating: drift is detected
        # by asset equivalence (RegenerationTest), not by source hash. A hash-equality
        # assertion would gate on every byte to the rulebook. See spec's "Rejected
        # alternatives" for why the lock does not constrain which source is read.
        lock = provenance.load()
        self.assertIsNotNone(lock, "source.lock is missing — run --write --accept-source")


class RegenerationMessageTest(unittest.TestCase):
    """The message must name the real cause, not the likeliest-looking one."""

    def test_names_the_source_when_the_lock_disagrees(self):
        from scripts.spell_import import provenance
        lock = provenance.SourceIdentity(
            book="B", path="reviewed/B.md", sha256="0" * 64,
            rulebook=provenance.RulebookRevision("aaaaaaa", "2026-01-01", "old"),
            spells_parsed=1, spells_imported=1,
        )
        current = dataclasses.replace(lock, sha256="1" * 64)
        message = extract_spells.regeneration_failure_message(lock, current)
        self.assertIn("rulebook source moved", message)
        self.assertNotIn("hand-edited", message)

    def test_blames_the_asset_when_the_lock_agrees(self):
        from scripts.spell_import import provenance
        lock = provenance.SourceIdentity(
            book="B", path="reviewed/B.md", sha256="0" * 64, rulebook=None,
            spells_parsed=1, spells_imported=1,
        )
        message = extract_spells.regeneration_failure_message(lock, lock)
        self.assertIn("hand-edited", message)
        self.assertNotIn("rulebook source moved", message)

    def test_names_the_absent_lock_when_lock_is_missing(self):
        from scripts.spell_import import provenance
        current = provenance.SourceIdentity(
            book="B", path="reviewed/B.md", sha256="1" * 64, rulebook=None,
            spells_parsed=1, spells_imported=1,
        )
        message = extract_spells.regeneration_failure_message(None, current)
        self.assertIn("no source.lock exists", message)
        self.assertIn("--accept-source", message)
        self.assertNotIn("hand-edited", message)
        self.assertNotIn("rulebook source moved", message)


class NumberedOverrideTest(unittest.TestCase):
    """The 4 spells item 28's design spec resolves via NUMBERED_OVERRIDES --
    see docs/superpowers/specs/2026-08-15-guideline-level-derivation-design.md.
    """

    @classmethod
    def setUpClass(cls):
        cls.report = extract_spells.run(write=False)

    def test_all_four_spells_now_import(self):
        names = {s["name"] for s in self.report.spells}
        for name in [
            "The Enigma's Gift",
            "Wizard's Icy Grip",
            "Fog of Confusion",
            "Infernal Smoke of Death",
        ]:
            self.assertIn(name, names)

    def test_infernal_smoke_of_death_carries_its_general_level(self):
        spell = next(s for s in self.report.spells if s["name"] == "Infernal Smoke of Death")
        self.assertEqual(spell["baseEffectId"], "muau-gen")
        self.assertEqual(spell["chosenBaseLevel"], 25)

    def test_the_enigmas_gift_carries_its_ladder_selection(self):
        spell = next(s for s in self.report.spells if s["name"] == "The Enigma's Gift")
        self.assertEqual(spell["baseEffectId"], "crvi-5a")
        self.assertEqual(
            spell["selectedModifiers"]["warping-point-burst"], ["warping-point-burst-4"]
        )
        self.assertNotIn("chosenBaseLevel", spell)

    def test_wizards_icy_grip_carries_its_ladder_selection(self):
        spell = next(s for s in self.report.spells if s["name"] == "Wizard's Icy Grip")
        self.assertEqual(spell["baseEffectId"], "peig-5b")
        self.assertEqual(spell["selectedModifiers"]["chill-damage"], ["chill-damage-20"])

    def test_fog_of_confusion_carries_its_discount(self):
        spell = next(s for s in self.report.spells if s["name"] == "Fog of Confusion")
        self.assertEqual(spell["baseEffectId"], "muau-3")
        self.assertEqual(
            spell["selectedModifiers"]["single-property-transformation"],
            ["single-property-transformation-yes"],
        )


class LevelNeedsRulesDecisionTest(unittest.TestCase):
    def test_sense_of_the_lingering_magic_blocks_with_a_specific_reason(self):
        report = extract_spells.run(write=False)
        reasons = dict(report.blocked)
        self.assertIn("Sense of the Lingering Magic", reasons)
        self.assertIn("needs a rules decision", reasons["Sense of the Lingering Magic"])


class HandDerivedAdjustmentTest(unittest.TestCase):
    """The one design line that names an adjustment but prints no magnitude.

    The magnitude in `extract_spells.HAND_DERIVED_ADJUSTMENT` is a literal with
    its arithmetic recorded beside it, never `printed - computed`. These tests
    pin the import and the emitted shape; the magnitude itself is checked by
    assertion 1 in test/data/published_spell_import_test.dart, which is only a
    real check because the value was not derived from that assertion.
    """

    @classmethod
    def setUpClass(cls):
        cls.report = extract_spells.run(write=False)

    def test_the_shadow_of_human_life_imports(self):
        self.assertIn("The Shadow of Human Life", {s["name"] for s in self.report.spells})

    def test_it_carries_the_hand_derived_adjustment(self):
        spell = next(s for s in self.report.spells if s["name"] == "The Shadow of Human Life")
        self.assertEqual(
            spell["adjustments"],
            [{"magnitude": 5, "note": "for a very elaborate effect"}],
        )

    def test_the_report_keeps_the_printed_design_line_not_the_patched_one(self):
        # import_report.md must show the rulebook's words, so the synthesised
        # "+5 " must not leak into the recorded design line.
        printed = self.report.design_lines["lib-crim-shadow-human-life"]
        self.assertIn("for a very elaborate effect", printed)
        self.assertNotIn("+5 for a very elaborate effect", printed)

    def test_mists_of_change_stays_blocked_on_its_two_durations(self):
        # D: Sun & Year -- two durations, which no adjustment can express.
        # (It blocks one token earlier, on the numberless "slightly nonstandard
        # effect"; both blockers are real and neither is derivable, so no
        # hand-derived magnitude is offered for it.)
        self.assertIn("Mists of Change", {name for name, _ in self.report.blocked})
