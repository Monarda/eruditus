import dataclasses
import json
import unittest

from scripts.spell_import import extract_spells
from scripts.spell_import import exceptions as exceptions_module
from scripts.spell_import import ledger as ledger_module
from scripts.spell_import.sources import REPO_ROOT

LIBRARY = REPO_ROOT / "assets" / "data" / "spell_library.json"
EXCEPTIONS = REPO_ROOT / "assets" / "data" / "spell_exceptions.json"


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

    def test_committed_exceptions_match_a_fresh_run(self):
        report = extract_spells.run(write=False)
        committed = json.loads(EXCEPTIONS.read_text(encoding="utf-8"))
        self.assertEqual(
            extract_spells.serialize(report.exceptions),
            extract_spells.serialize(committed),
        )


class HandDerivedTest(unittest.TestCase):
    """Of the 3 spells with no printed design line, 2 have a legitimate
    hand-derivation. The third, Whispering Winds, was investigated and found
    genuinely non-derivable -- see git history for that reasoning -- and now
    imports as an exception spell instead (ExceptionSpellsTest in this file),
    not as a blocked spell. See HAND_DERIVED's module docstring in
    extract_spells.py for the two derivable spells' per-spell reasoning.
    """

    def test_the_derivable_spell_is_imported(self):
        report = extract_spells.run(write=False)
        names = {s["name"] for s in report.spells}
        self.assertIn("Enchantment of the Scrying Pool", names)

    def test_hermes_portal_is_now_derivable(self):
        # Item 45: the tokenizer gap that made this permanently blocked is
        # closed. rete-4's own guideline note ("add magnitudes for
        # distance/Arcane Connection") plus the rego-transport-distance
        # modifier's top rung is the derivation -- see HAND_DERIVED's
        # comment for the full magnitude arithmetic.
        report = extract_spells.run(write=False)
        spell = next(s for s in report.spells if s["name"] == "Hermes' Portal")
        self.assertEqual(spell["printedLevel"], 75)
        self.assertEqual(spell["baseEffectId"], "rete-4")


class BountifulFeastTypoTest(unittest.TestCase):
    """The Bountiful Feast's printed design line is missing its outer closing
    paren (a rulebook transcription defect, not a splitter bug -- see
    DESIGN_LINE_TYPOS). Confirms the fix, not just that parsing succeeds.
    """

    def test_the_bountiful_feast_imports_at_its_printed_level(self):
        report = extract_spells.run(write=False)
        spell = next(s for s in report.spells if s["name"] == "The Bountiful Feast")
        self.assertEqual(spell["printedLevel"], 35)
        self.assertEqual(spell["baseEffectId"], "crhe-1a")
        self.assertEqual(spell["targetId"], "target-boundary")


class CombinedBaseEffectsTest(unittest.TestCase):
    """Conjuration of the Indubitable Cold: genuinely achieves two base-4
    Perdo Ignem guidelines at once (chills an object, chills a person for a
    lost Fatigue level). `Spell.baseEffectId` can only record one -- see
    extract_spells.COMBINED_BASE_EFFECTS -- so the other is recorded as a
    magnitude-0 LevelAdjustment instead of silently dropped.
    """

    def test_imports_at_its_printed_level_with_the_chosen_base_effect(self):
        report = extract_spells.run(write=False)
        spell = next(
            s for s in report.spells if s["name"] == "Conjuration of the Indubitable Cold"
        )
        self.assertEqual(spell["printedLevel"], 25)
        self.assertEqual(spell["baseEffectId"], "peig-4b")

    def test_the_second_effect_is_recorded_as_a_zero_magnitude_adjustment(self):
        report = extract_spells.run(write=False)
        spell = next(
            s for s in report.spells if s["name"] == "Conjuration of the Indubitable Cold"
        )
        self.assertIn("adjustments", spell)
        self.assertEqual(len(spell["adjustments"]), 1)
        self.assertEqual(spell["adjustments"][0]["magnitude"], 0)
        self.assertIn("peig-4c", spell["adjustments"][0]["note"])

    def test_no_longer_appears_in_known_unresolvable(self):
        self.assertNotIn(
            "lib-peig-conjuration-indubitable-cold", extract_spells.KNOWN_UNRESOLVABLE
        )


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


class ExceptionSpellsTest(unittest.TestCase):
    """The spells the rulebook itself says guideline arithmetic doesn't apply
    to -- see docs/superpowers/specs/2026-08-15-exception-spells-design.md
    for the original six, and exceptions.EXCEPTION_SPELLS's module docstring
    for the third shape (Sight of the True Form, added 2026-08-16) that spec
    didn't anticipate.
    """

    @classmethod
    def setUpClass(cls):
        cls.report = extract_spells.run(write=False)

    def test_every_listed_spell_imports_as_an_exception_not_blocked(self):
        names = {e["name"] for e in self.report.exceptions}
        blocked_names = {name for name, _ in self.report.blocked}
        for name in exceptions_module.EXCEPTION_SPELLS:
            self.assertIn(name, names, msg=name)
            self.assertNotIn(name, blocked_names, msg=name)

    def test_the_five_general_kind_exceptions_have_no_printed_level(self):
        by_name = {e["name"]: e for e in self.report.exceptions}
        for name in ("Wizard's Communion", "Wizard's Vigil",
                     "Aegis of the Hearth", "Watching Ward",
                     "Sight of the True Form"):
            self.assertNotIn("printedLevel", by_name[name], msg=name)

    def test_the_two_fixed_level_exceptions_carry_their_printed_level(self):
        by_name = {e["name"]: e for e in self.report.exceptions}
        self.assertEqual(by_name["Whispering Winds"]["printedLevel"], 15)
        self.assertEqual(by_name["Mists of Change"]["printedLevel"], 60)

    def test_every_exception_carries_a_rationale(self):
        for exception in self.report.exceptions:
            self.assertTrue(exception["rationale"], msg=exception["name"])

    def test_ids_use_the_exc_prefix(self):
        by_name = {e["name"]: e for e in self.report.exceptions}
        self.assertEqual(by_name["Whispering Winds"]["id"], "exc-inau-whispering-winds")
        self.assertEqual(by_name["Wizard's Communion"]["id"], "exc-muvi-wizards-communion")


class ExceptionSpellsStalenessTest(unittest.TestCase):
    """Guards EXCEPTION_SPELLS against a name that stops existing in the
    corpus. Mirrors KnownUnresolvableStalenessTest's shape.
    """

    def test_every_exception_name_is_still_a_real_parsed_spell(self):
        from scripts.spell_import import blocks, sources

        lines = sources.read_lines(sources.resolve_book(sources.DE_TITLE))
        parsed, _ = blocks.parse_de(lines)
        parsed_names = {b.name for b in parsed}
        stale = [name for name in exceptions_module.EXCEPTION_SPELLS
                 if name not in parsed_names]
        self.assertEqual(stale, [], msg=f"no longer a parsed spell at all: {stale}")


class ExceptionSpellsDisjointnessTest(unittest.TestCase):
    """Each blocked/excepted spell has exactly one home. A name in
    EXCEPTION_SPELLS that also appears in another closed table would be
    ambiguous about which mechanism actually handles it.
    """

    def test_no_exception_spell_appears_in_another_name_keyed_table(self):
        exception_names = set(exceptions_module.EXCEPTION_SPELLS)
        other_tables = {
            "HAND_DERIVED": set(extract_spells.HAND_DERIVED),
            "DESIGN_LINE_TYPOS": set(extract_spells.DESIGN_LINE_TYPOS),
            "HAND_DERIVED_ADJUSTMENT": set(extract_spells.HAND_DERIVED_ADJUSTMENT),
        }
        for table_name, names in other_tables.items():
            overlap = exception_names & names
            self.assertEqual(overlap, set(), msg=f"also in {table_name}: {overlap}")

    def test_no_exception_spell_appears_in_another_slug_keyed_table(self):
        # DESIGN_LINE_INCOMPLETE, KNOWN_UNRESOLVABLE and
        # LEVEL_NEEDS_RULES_DECISION are keyed by spell_id (technique+form+
        # name slug), not bare name -- compare against the slug form instead.
        from scripts.spell_import import blocks, catalog as catalog_module, sources

        lines = sources.read_lines(sources.resolve_book(sources.DE_TITLE))
        parsed, _ = blocks.parse_de(lines)
        by_name = {b.name: b for b in parsed}
        exception_ids = {
            catalog_module.slug_id(by_name[name].technique, by_name[name].form, name)
            for name in exceptions_module.EXCEPTION_SPELLS if name in by_name
        }
        for table_name, ids in {
            "DESIGN_LINE_INCOMPLETE": set(extract_spells.DESIGN_LINE_INCOMPLETE),
            "KNOWN_UNRESOLVABLE": set(extract_spells.KNOWN_UNRESOLVABLE),
            "LEVEL_NEEDS_RULES_DECISION": set(extract_spells.LEVEL_NEEDS_RULES_DECISION),
        }.items():
            overlap = exception_ids & ids
            self.assertEqual(overlap, set(), msg=f"also in {table_name}: {overlap}")


GENERAL_BLOCKED = {
    # Ward against Faeries of the Mountain: WAS here ("no design line; a prose
    # cross-reference to another spell") until 2026-08-15, when that same
    # cross-reference ("As Ward Against Faeries of the Waters (ReAq Gen)...")
    # turned out to be a complete specification, not just a description --
    # see extract_spells.HAND_DERIVED's comment. It now imports as a
    # template. This is exactly the staleness this test class exists to
    # catch, and it caught it.
    #
    # Aegis of the Hearth, Wizard's Vigil, Watching Ward and Wizard's
    # Communion: WERE here until 2026-08-16, when they moved to
    # ExceptionSpellsTest instead -- each now imports as an exception spell
    # (scripts/spell_import/exceptions.py), not blocked at all. This is the
    # same staleness this test class exists to catch.
    #
    # Sight of the True Form: WAS here ("no design line") until 2026-08-16,
    # when it moved to ExceptionSpellsTest too -- see
    # exceptions.EXCEPTION_SPELLS's entry.
    "Dispel the Phantom Image": "no Perdo Imaginem General row in the rulebook",
    "Lay to Rest the Haunting Spirit": "no Perdo Mentem General row in the rulebook",
    "Restore the Moved Image": "design line does not account for the stat line",
    "The Invisible Eye Revealed": "design line does not account for the stat line",
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


class NumberedOverrideLedgerAgreementTest(unittest.TestCase):
    """NUMBERED_OVERRIDES's resolution path `continue`s before `Ledger.resolve()`
    is ever called, so nothing in the normal import path checks that a ledger
    entry recorded for one of these spells (resolutions.json) still agrees
    with what NUMBERED_OVERRIDES resolves it to. Not every NUMBERED_OVERRIDES
    id has a ledger entry -- e.g. muau-3/Fog of Confusion genuinely has none,
    since it isn't ambiguous -- so this only checks the ones that do.
    """

    def test_ledger_entries_agree_with_numbered_overrides(self):
        ledger = ledger_module.Ledger.load()
        for spell_id, override in extract_spells.NUMBERED_OVERRIDES.items():
            entry = ledger.entries.get(spell_id)
            if entry is None:
                continue
            self.assertEqual(
                entry.base_effect_id, override["base_effect_id"],
                msg=f"{spell_id}: ledger recorded {entry.base_effect_id!r} but "
                    f"NUMBERED_OVERRIDES resolves it to {override['base_effect_id']!r}",
            )

    def test_the_check_above_actually_catches_a_disagreement(self):
        """Prove test_ledger_entries_agree_with_numbered_overrides can fail:
        mutate a loaded ledger's recorded base effect id in memory (never
        touching resolutions.json on disk) and confirm the same comparison
        it makes then fails, before reverting.
        """
        ledger = ledger_module.Ledger.load()
        spell_id = next(
            sid for sid in extract_spells.NUMBERED_OVERRIDES if sid in ledger.entries
        )
        original = ledger.entries[spell_id]
        try:
            ledger.entries[spell_id] = dataclasses.replace(
                original, base_effect_id=original.base_effect_id + "-mutated"
            )
            with self.assertRaises(AssertionError):
                self.assertEqual(
                    ledger.entries[spell_id].base_effect_id,
                    extract_spells.NUMBERED_OVERRIDES[spell_id]["base_effect_id"],
                )
        finally:
            ledger.entries[spell_id] = original


class SenseOfTheLingeringMagicTest(unittest.TestCase):
    """Sense of the Lingering Magic: WAS in LEVEL_NEEDS_RULES_DECISION until
    2026-08-16, when it turned out to be an ordinary NUMBERED_OVERRIDES case
    (built on invi-G at chosen level 10) rather than a genuine rules gap --
    see NUMBERED_OVERRIDES's comment for the derivation. LEVEL_NEEDS_RULES_
    DECISION is now empty; this class replaces the old blocked-reason pin.
    """

    @classmethod
    def setUpClass(cls):
        cls.report = extract_spells.run(write=False)

    def test_imports_at_its_printed_level(self):
        spell = next(
            s for s in self.report.spells if s["name"] == "Sense of the Lingering Magic"
        )
        self.assertEqual(spell["printedLevel"], 30)
        self.assertEqual(spell["baseEffectId"], "invi-G")
        self.assertEqual(spell["chosenBaseLevel"], 10)

    def test_no_longer_needs_a_rules_decision(self):
        self.assertNotIn(
            "lib-invi-sense-lingering-magic", extract_spells.LEVEL_NEEDS_RULES_DECISION
        )


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

    def test_mists_of_change_is_an_exception_not_blocked(self):
        # D: Sun & Year -- two durations, which no adjustment or ledger fix
        # can express; it now imports as an exception spell instead of
        # staying blocked. See ExceptionSpellsTest for the full shape.
        exception_names = {e["name"] for e in extract_spells.run(write=False).exceptions}
        self.assertIn("Mists of Change", exception_names)
        self.assertNotIn("Mists of Change", {name for name, _ in self.report.blocked})
