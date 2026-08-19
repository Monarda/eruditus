import dataclasses
import json
import unittest

from scripts.spell_import import catalog as catalog_module
from scripts.spell_import import extract_spells
from scripts.spell_import import exceptions as exceptions_module
from scripts.spell_import import ledger as ledger_module
from scripts.spell_import import sources
from scripts.spell_import.sources import REPO_ROOT

LIBRARY = REPO_ROOT / "assets" / "data" / "spell_library.json"
EXCEPTIONS = REPO_ROOT / "assets" / "data" / "spell_exceptions.json"
TEMPLATES = REPO_ROOT / "assets" / "data" / "spell_templates.json"


class ContainerModesTest(unittest.TestCase):
    def setUp(self):
        self.catalog = catalog_module.Catalog.load()

    def _rows(self):
        return [
            {"id": "lib-a", "targetId": "target-circle"},
            {"id": "lib-b", "targetId": "target-group"},
        ]

    def test_stamps_the_mode_onto_the_row_it_names(self):
        rows = self._rows()
        extract_spells.apply_container_modes(
            rows, self.catalog, {"lib-a": {"mode": "dynamic", "rationale": "x"}}
        )
        self.assertEqual(rows[0]["containerMode"], "dynamic")

    def test_leaves_unnamed_rows_alone(self):
        rows = self._rows()
        extract_spells.apply_container_modes(
            rows, self.catalog, {"lib-a": {"mode": "dynamic", "rationale": "x"}}
        )
        self.assertNotIn("containerMode", rows[1])

    def test_raises_on_an_id_no_run_produced(self):
        with self.assertRaises(extract_spells.UnknownContainerModeSpell):
            extract_spells.apply_container_modes(
                self._rows(),
                self.catalog,
                {"lib-ghost": {"mode": "static", "rationale": "x"}},
            )

    def test_raises_when_the_target_is_not_a_container(self):
        with self.assertRaises(extract_spells.NotAContainerTarget):
            extract_spells.apply_container_modes(
                self._rows(),
                self.catalog,
                {"lib-b": {"mode": "dynamic", "rationale": "x"}},
            )

    def test_container_modes_are_not_checked_while_entries_are_unresolved(self):
        # A widened ledger entry leaves its spell unproduced, which would
        # otherwise trip the stale-entry guard -- and migrate_ledger.py, the
        # only thing that fixes a widening, calls run() and would hit the
        # same crash. The guard is meaningful only on a clean run.
        modes = {"lib-revi-circular-ward-against-demons": {"mode": "dynamic",
                                                             "rationale": "test"}}
        extract_spells.apply_container_modes([], self.catalog, modes, unresolved=True)

    def test_container_modes_are_still_checked_on_a_clean_run(self):
        modes = {"lib-nonesuch-spell": {"mode": "dynamic", "rationale": "test"}}
        with self.assertRaises(extract_spells.UnknownContainerModeSpell):
            extract_spells.apply_container_modes(
                [], self.catalog, modes, unresolved=False
            )


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
            self.assertEqual(len(spell["citations"]), 1)
            self.assertIn(spell["citations"][0]["bookId"],
                          {b.id for b in sources.BOOKS}, msg=spell["id"])

    def test_ids_are_unique(self):
        ids = [s["id"] for s in self.report.spells]
        self.assertEqual(len(ids), len(set(ids)))

    def test_no_page_numbers_are_invented(self):
        for spell in self.report.spells:
            for citation in spell["citations"]:
                self.assertNotIn("page", citation)

    def test_every_parsed_block_lands_in_exactly_one_bucket(self):
        # A bucket-conservation invariant: every design-line block the parser
        # finds must land in exactly one of these buckets. If a spell fell out
        # of the report entirely -- silently dropped rather than appearing in
        # report.blocked -- this sum would fall short of spells_parsed and
        # catch it. (Verified today: 336+29+8+0+3 = 376 = spells_parsed.)
        #
        # Hand-authored templates are subtracted back out because they were
        # never parsed: they come from a committed input, not from Chapter 9,
        # so counting them would make this sum exceed spells_parsed and mask
        # a genuine shortfall by exactly as many as there are of them.
        r = self.report
        carried_in = len(extract_spells.hand_authored_templates())
        parsed_total = sum(i.spells_parsed for i in r.identities.values())
        self.assertEqual(
            len(r.spells) + len(r.templates) - carried_in + len(r.exceptions)
            + len(r.blocked) + len(r.skipped) + len(r.unresolved),
            parsed_total,
            "a spell fell out of the report entirely -- it must appear in "
            "exactly one bucket, blocked and skipped included")

    def test_the_eight_circle_wards_carry_a_dynamic_container_mode(self):
        wards = {
            "lib-rean-circle-beast-warding",
            "tpl-rean-ward-against-beasts-legend",
            "tpl-reaq-ward-against-faeries-waters",
            "tpl-reau-ward-against-faeries-air",
            "tpl-rehe-ward-against-faeries-wood",
            "tpl-reme-ring-warding-against-spirits",
            "tpl-rete-ward-against-faeries-mountain",
            "tpl-revi-circular-ward-against-demons",
        }
        rows = {
            row["id"]: row
            for row in list(self.report.spells) + list(self.report.templates)
        }
        for ward in wards:
            self.assertEqual(rows[ward].get("containerMode"), "dynamic", ward)

    def test_restore_the_faded_threads_stays_unstated(self):
        # A Circle spell the Magical Wards rule does not decide, because it is
        # not a ward. Guessing at it is exactly what the backfill must not do.
        rows = {row["id"]: row for row in self.report.templates}
        self.assertNotIn(
            "containerMode", rows["tpl-crvi-restore-faded-threads"]
        )

    def test_every_skip_carries_a_reason(self):
        for name, reason in self.report.skipped:
            self.assertTrue(reason.strip(), msg=name)

    def test_the_supplement_spells_are_imported(self):
        by_id = {s["id"]: s for s in self.report.spells}
        for spell_id in ("lib-pean-revenge-bitten-toad",
                         "lib-crme-scent-predator",
                         "lib-muim-ball-abysmal-music",
                         "lib-peme-embrace-boethius"):
            self.assertIn(spell_id, by_id)
            self.assertEqual(by_id[spell_id]["citations"],
                             [{"bookId": "arm5-hohmc"}], msg=spell_id)

    def test_the_two_requisites_of_embrace_of_boethius_both_cost(self):
        # "+2 necessary requisites" against Req: Vim, Corpus -- +1 each.
        spell = next(s for s in self.report.spells
                     if s["id"] == "lib-peme-embrace-boethius")
        self.assertEqual(spell["requisites"], {"Vim": "adding", "Corpus": "adding"})

    def test_the_four_sensory_spells_state_no_container_mode(self):
        # Sound and Spectacle are TargetType.sensorium, not container: the
        # book withholds the static/dynamic choice rather than fixing it, so
        # nothing is owed and a stated mode would fail validation check 9.
        rows = {s["id"]: s for s in self.report.spells + self.report.templates}
        for spell_id in ("lib-mume-clarion-call-war-horse",
                         "tpl-pevi-roosters-crow",
                         "lib-crig-brilliance-eagles-plumage",
                         "lib-peme-closed-mouth-nightwalker"):
            self.assertNotIn("containerMode", rows[spell_id], spell_id)

    def test_the_three_unimportable_blocks_are_skipped_with_reasons(self):
        names = {name for name, _ in self.report.skipped}
        self.assertEqual(names, {
            "Perceive the Change",
            "Faerie Chains of the Familiar Slave",
            "Tie the Threads That Bind",
        })

    def test_the_hand_authored_automata_template_survives_a_run(self):
        by_id = {t["id"]: t for t in self.report.templates}
        template = by_id["tpl-revi-tie-threads-that-bind"]
        self.assertEqual(template["baseEffectId"], "revi-hohmc-G1")


class DuplicateSpellIdTest(unittest.TestCase):
    """Exercises the real guard, not a reimplementation of it -- see
    extract_spells._reject_duplicate_ids.
    """

    def test_two_rows_sharing_an_id_raise(self):
        rows = [{"id": "lib-muan-x", "name": "First"},
                {"id": "lib-muan-x", "name": "Second"}]
        with self.assertRaises(extract_spells.DuplicateSpellId):
            extract_spells._reject_duplicate_ids(rows)

    def test_distinct_ids_do_not_raise(self):
        rows = [{"id": "lib-muan-x", "name": "First"},
                {"id": "lib-muan-y", "name": "Second"}]
        extract_spells._reject_duplicate_ids(rows)  # must not raise


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
                provenance.load(), report.identities
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

    def test_committed_templates_match_a_fresh_run(self):
        """The third asset --write rewrites, and the last to get this check.

        Its absence hid a real divergence: when todo item 17's supplement
        guideline made three Creo Vim templates unresolvable, the committed
        file kept 28 entries while a fresh run produced 24, and nothing
        failed. Both other assets had this assertion; templates did not.
        """
        report = extract_spells.run(write=False)
        committed = json.loads(TEMPLATES.read_text(encoding="utf-8"))
        self.assertEqual(
            extract_spells.serialize(report.templates),
            extract_spells.serialize(committed),
        )

    def test_hand_authored_templates_survive_a_run(self):
        """A template the extractor cannot produce must still come out of it.

        `--write` rebuilds spell_templates.json from the run's own output, so
        anything only present in the committed asset is deleted by the next
        regeneration -- which is what would have happened to item 17's worked
        example. Pinned separately from the equality above because that one
        would go green again if somebody deleted the entry from *both* sides.
        """
        report = extract_spells.run(write=False)
        emitted = {t["id"] for t in report.templates}
        for template in extract_spells.hand_authored_templates():
            with self.subTest(template["id"]):
                self.assertIn(template["id"], emitted)


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
    """Conjuration of the Indubitable Cold: genuinely achieves all three
    base-4 Perdo Ignem guidelines at once -- chills an object, chills a
    person for a lost Fatigue level, and extinguishes a fire.
    `Spell.baseEffectId` can only record one -- see
    extract_spells.COMBINED_BASE_EFFECTS -- so the other two are recorded as
    magnitude-0 LevelAdjustments instead of silently dropped. The rulebook
    rule they rest on is the Requisites section's "the base Arts and level
    for the spell are those for the highest-level effect it has": with every
    effect at level 4, whichever is called primary sets the level and the
    rest are free.
    """

    def test_imports_at_its_printed_level_with_the_chosen_base_effect(self):
        report = extract_spells.run(write=False)
        spell = next(
            s for s in report.spells if s["name"] == "Conjuration of the Indubitable Cold"
        )
        self.assertEqual(spell["printedLevel"], 25)
        self.assertEqual(spell["baseEffectId"], "peig-4b")

    def test_the_other_two_effects_are_recorded_as_zero_magnitude_adjustments(self):
        report = extract_spells.run(write=False)
        spell = next(
            s for s in report.spells if s["name"] == "Conjuration of the Indubitable Cold"
        )
        self.assertIn("adjustments", spell)
        self.assertEqual(len(spell["adjustments"]), 2)
        for adjustment in spell["adjustments"]:
            self.assertEqual(adjustment["magnitude"], 0)
        notes = " ".join(a["note"] for a in spell["adjustments"])
        self.assertIn("peig-4c", notes)
        self.assertIn("peig-4a", notes)

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
            candidates = cat.candidates(
                block.technique, block.form, design.base_level,
                catalog_module.CORE_BOOK_ID,
            )
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

    def test_the_six_general_kind_exceptions_have_no_printed_level(self):
        by_name = {e["name"]: e for e in self.report.exceptions}
        for name in ("Wizard's Communion", "Wizard's Vigil",
                     "Aegis of the Hearth", "Watching Ward",
                     "Sight of the True Form", "The Invisible Eye Revealed"):
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
        self.assertEqual(
            by_name["The Invisible Eye Revealed"]["id"], "exc-invi-invisible-eye-revealed"
        )


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
            "ANALOGY_BASE_EFFECTS": set(extract_spells.ANALOGY_BASE_EFFECTS),
        }.items():
            overlap = exception_ids & ids
            self.assertEqual(overlap, set(), msg=f"also in {table_name}: {overlap}")


GENERAL_BLOCKED: dict[str, str] = {}
# Ward against Faeries of the Mountain, Aegis of the Hearth, Wizard's Vigil,
# Watching Ward, Wizard's Communion, Sight of the True Form, Dispel the
# Phantom Image, Lay to Rest the Haunting Spirit, Restore the Moved Image,
# and The Invisible Eye Revealed all WERE here at one point or another --
# each now imports (as a template, an exception spell, or via
# ANALOGY_BASE_EFFECTS). Currently empty; the mechanism stays for the next
# spell that turns out to need it.


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
        identity = report.identities["arm5-core"]
        self.assertIsNotNone(identity.sha256)
        self.assertEqual(len(identity.sha256), 64)
        self.assertEqual(identity.spells_parsed, 360)

    def test_report_carries_a_design_line_per_imported_spell(self):
        report = extract_spells.run(write=False)
        for spell in report.spells:
            self.assertIn(spell["id"], report.design_lines, msg=spell["id"])

    def test_the_committed_report_names_the_committed_lock_revision(self):
        """The change report and source.lock must not disagree.

        `--accept-source` writes the lock unconditionally but used to render
        the report only when the *asset* moved, so adopting a revision that
        changed nothing left the report still describing the previous
        adoption. That is the one outcome most worth recording -- "we looked,
        it was a no-op" -- and the committed pair silently contradicted each
        other. Static check on committed artifacts, so it costs no run.
        """
        from scripts.spell_import import provenance
        report = extract_spells.REPORT_PATH.read_text(encoding="utf-8")
        lock = provenance.load()
        for book_id, recorded in lock.items():
            if recorded.rulebook is None:
                continue
            heading = f"(`{book_id}`)"
            self.assertIn(heading, report, msg=f"{book_id} is locked but unreported")
            after = report.split(heading, 1)[1]
            source_line = next(
                line for line in after.splitlines() if line.startswith(("Source:", "Initial import"))
            )
            self.assertIn(
                recorded.rulebook.commit, source_line,
                msg=(f"import_report.md does not name {book_id}'s locked revision "
                     f"{recorded.rulebook.commit!r} -- re-run --write --accept-source"),
            )

    def test_source_lock_exists(self):
        from scripts.spell_import import provenance
        # Existence gate only. The lock is diagnostic, not gating: drift is detected
        # by asset equivalence (RegenerationTest), not by source hash. A hash-equality
        # assertion would gate on every byte to the rulebook. See spec's "Rejected
        # alternatives" for why the lock does not constrain which source is read.
        lock = provenance.load()
        self.assertIn("arm5-core", lock, "source.lock is missing — run --write --accept-source")


class RegenerationMessageTest(unittest.TestCase):
    """The message must name the real cause, not the likeliest-looking one."""

    def test_names_the_source_when_the_lock_disagrees(self):
        from scripts.spell_import import provenance
        recorded = provenance.SourceIdentity(
            book_id="test-book", book="B", path="reviewed/B.md", sha256="0" * 64,
            rulebook=provenance.RulebookRevision("aaaaaaa", "2026-01-01", "old"),
            spells_parsed=1, spells_imported=1,
        )
        current = dataclasses.replace(recorded, sha256="1" * 64)
        message = extract_spells.regeneration_failure_message(
            {recorded.book_id: recorded}, {current.book_id: current})
        self.assertIn("moved", message)
        self.assertNotIn("hand-edited", message)

    def test_blames_the_asset_when_the_lock_agrees(self):
        from scripts.spell_import import provenance
        recorded = provenance.SourceIdentity(
            book_id="test-book", book="B", path="reviewed/B.md", sha256="0" * 64, rulebook=None,
            spells_parsed=1, spells_imported=1,
        )
        message = extract_spells.regeneration_failure_message(
            {recorded.book_id: recorded}, {recorded.book_id: recorded})
        self.assertIn("hand-edited", message)
        self.assertNotIn("moved", message)

    def test_names_the_absent_lock_when_lock_is_missing(self):
        from scripts.spell_import import provenance
        current = provenance.SourceIdentity(
            book_id="test-book", book="B", path="reviewed/B.md", sha256="1" * 64, rulebook=None,
            spells_parsed=1, spells_imported=1,
        )
        message = extract_spells.regeneration_failure_message({}, {current.book_id: current})
        self.assertIn("has no record of", message)
        self.assertIn("--accept-source", message)
        self.assertNotIn("moved", message)

    def test_names_a_non_core_book_that_moved_rather_than_blaming_the_asset(self):
        """The exact misdiagnosis this finding fixes.

        Hard-wiring the check to arm5-core meant a moved HoH:MC was invisible
        to this function: it would report "hand-edited" even though a
        registered, non-core book had moved. Every identity must be checked.
        """
        from scripts.spell_import import provenance
        core = provenance.SourceIdentity(
            book_id="arm5-core", book="Core", path="reviewed/Core.md", sha256="c" * 64,
            rulebook=None, spells_parsed=1, spells_imported=1,
        )
        hohmc_recorded = provenance.SourceIdentity(
            book_id="arm5-hohmc", book="HoH:MC", path="reviewed/HoHMC.md", sha256="0" * 64,
            rulebook=provenance.RulebookRevision("aaaaaaa", "2026-01-01", "old"),
            spells_parsed=1, spells_imported=1,
        )
        hohmc_current = dataclasses.replace(hohmc_recorded, sha256="1" * 64)
        message = extract_spells.regeneration_failure_message(
            {core.book_id: core, hohmc_recorded.book_id: hohmc_recorded},
            {core.book_id: core, hohmc_current.book_id: hohmc_current},
        )
        self.assertIn("arm5-hohmc", message)
        self.assertIn("moved", message)
        self.assertNotIn("hand-edited", message)


class MatchedLockUpdatesTest(unittest.TestCase):
    """The drift branch's write must not launder an unaccepted source move.

    `run()`'s drift branch fires without --accept-source when a *matched*
    book's advisory counts alone have drifted. It must write only that
    book's refreshed entry, merged over the loaded lock -- never a moved
    book's new identity, which only --accept-source may adopt.
    """

    def test_a_moved_but_unaccepted_book_keeps_its_recorded_identity(self):
        from scripts.spell_import import provenance

        core_recorded = provenance.SourceIdentity(
            book_id="arm5-core", book="Core", path="reviewed/Core.md", sha256="c" * 64,
            rulebook=None, spells_parsed=294, spells_imported=294,
        )
        # arm5-core matched (same sha256) but this run's advisory counts
        # disagree with what's recorded -- the scenario the drift branch
        # exists for.
        core_current = dataclasses.replace(core_recorded, spells_parsed=325, spells_imported=325)

        # HoH:MC's markdown moved (different sha256) but was never accepted.
        hohmc_recorded = provenance.SourceIdentity(
            book_id="arm5-hohmc", book="HoH:MC", path="reviewed/HoHMC.md", sha256="0" * 64,
            rulebook=provenance.RulebookRevision("aaaaaaa", "2026-01-01", "old"),
            spells_parsed=16, spells_imported=14,
        )
        hohmc_current = dataclasses.replace(hohmc_recorded, sha256="1" * 64)

        lock = {core_recorded.book_id: core_recorded, hohmc_recorded.book_id: hohmc_recorded}
        identities = {core_current.book_id: core_current, hohmc_current.book_id: hohmc_current}

        updated = extract_spells._matched_lock_updates(lock, identities)

        # The matched book's advisory counts are refreshed...
        self.assertEqual(updated["arm5-core"].spells_parsed, 325)
        # ...but the moved, unaccepted book's sha256 survives unchanged --
        # not laundered in by this write of a different book.
        self.assertEqual(updated["arm5-hohmc"].sha256, "0" * 64)
        self.assertEqual(updated["arm5-hohmc"], hohmc_recorded)


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


class AnalogyBaseEffectsTest(unittest.TestCase):
    """3 of item 25's 4 permanently-blocked spells resolve by pointing at an
    existing Vim-level General base effect instead of a (nonexistent or
    wrong) row in their own Form's table -- see
    docs/superpowers/specs/2026-08-16-analogy-unblock-blocked-spells-design.md.
    """

    @classmethod
    def setUpClass(cls):
        cls.report = extract_spells.run(write=False)

    def _template(self, name: str) -> dict:
        return next(t for t in self.report.templates if t["name"] == name)

    def test_all_three_now_import_as_templates_not_blocked(self):
        names = {t["name"] for t in self.report.templates}
        blocked_names = {name for name, _ in self.report.blocked}
        for name in ("Dispel the Phantom Image", "Restore the Moved Image",
                     "Lay to Rest the Haunting Spirit"):
            self.assertIn(name, names, msg=name)
            self.assertNotIn(name, blocked_names, msg=name)

    def test_dispel_the_phantom_image_points_at_pevi_g2(self):
        template = self._template("Dispel the Phantom Image")
        self.assertEqual(template["baseEffectId"], "pevi-G2")
        self.assertEqual(template["technique"], "Perdo")
        self.assertEqual(template["form"], "Imaginem")
        self.assertTrue(template["analogyRationale"])
        self.assertEqual(template["chosenSlots"], {"specificType": "Creo Imaginem"})

    def test_restore_the_moved_image_points_at_revi_g2(self):
        template = self._template("Restore the Moved Image")
        self.assertEqual(template["baseEffectId"], "revi-G2")
        self.assertEqual(template["technique"], "Rego")
        self.assertEqual(template["form"], "Imaginem")
        self.assertTrue(template["analogyRationale"])
        self.assertNotIn("chosenSlots", template)

    def test_lay_to_rest_the_haunting_spirit_points_at_pevi_g3(self):
        template = self._template("Lay to Rest the Haunting Spirit")
        self.assertEqual(template["baseEffectId"], "pevi-G3")
        self.assertEqual(template["technique"], "Perdo")
        self.assertEqual(template["form"], "Mentem")
        self.assertTrue(template["analogyRationale"])
        self.assertNotIn("chosenSlots", template)


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


class TechniqueFormRegenerationTest(unittest.TestCase):
    """Every emitted spell and template must carry its own technique/form --
    the whole reason this plan exists. No spell should ever emit without
    them (a missing key here would mean a code path in extract_spells.py
    forgot to thread block.technique/block.form through).
    """

    def test_every_spell_and_template_has_technique_and_form(self):
        report = extract_spells.run(write=False)
        for spell in report.spells:
            self.assertIn("technique", spell, msg=spell["name"])
            self.assertIn("form", spell, msg=spell["name"])
        for template in report.templates:
            self.assertIn("technique", template, msg=template["name"])
            self.assertIn("form", template, msg=template["name"])

    # test_no_spell_carries_an_analogy_rationale_yet: WAS here until
    # 2026-08-16, pinning the base-effect-analogy plan's Global Constraint
    # that the capability was wired through but unused. That constraint no
    # longer holds -- ANALOGY_BASE_EFFECTS (extract_spells.py) now routes 3
    # templates through it on purpose; see AnalogyBaseEffectsTest and
    # docs/superpowers/specs/2026-08-16-analogy-unblock-blocked-spells-design.md.


class NameKeyedTableCollisionTest(unittest.TestCase):
    """The guard item 73.7 asked for, standing in for the per-book re-key.

    HAND_DERIVED, HAND_DERIVED_ADJUSTMENT, DESIGN_LINE_TYPOS,
    SPELL_NAME_TYPOS and exceptions.EXCEPTION_SPELLS are keyed by bare spell
    name across every book, unlike SKIPPED_BLOCKS which is keyed per book id.
    A third book printing a spell whose exact name already appears in one of
    them would silently have that entry applied to it.

    `_reject_duplicate_ids` cannot catch that, as the comment above
    HAND_DERIVED explains: these tables are consulted while a book is still
    being parsed, and a name-keyed misfire changes the name and therefore the
    id, so no duplicate ever materialises for it to reject. This test can,
    because it asks the question at the level the tables are keyed at.

    Re-keying by (book_id, name) was deliberately deferred rather than done:
    18 entries across 5 tables, all core-book today, and item 71 measured the
    third book as distant (Covenants and Societates tokenize zero blocks).
    This test is what makes deferring safe -- it turns a silent misapplication
    into a red suite the moment a colliding book registers. When one does,
    re-key the tables; `registered.id` is already in scope at all six lookup
    sites in run().
    """

    def _names_by_book(self):
        from scripts.spell_import import blocks

        by_book = {}
        for book in sources.BOOKS:
            parsed, _ = blocks.PARSERS[book.parser](
                sources.read_lines(sources.resolve_book(book.title)))
            # Skipped blocks are excluded: run() checks SKIPPED_BLOCKS first
            # and continues, so a skipped name never reaches these tables and
            # cannot misfire. Counting it would be a false alarm.
            skips = extract_spells.SKIPPED_BLOCKS.get(book.id, {})
            by_book[book.id] = {
                extract_spells.SPELL_NAME_TYPOS.get(b.name, b.name)
                for b in parsed if b.name not in skips
            }
        return by_book

    def test_every_name_keyed_entry_matches_exactly_one_book(self):
        tables = {
            "HAND_DERIVED": extract_spells.HAND_DERIVED,
            "HAND_DERIVED_ADJUSTMENT": extract_spells.HAND_DERIVED_ADJUSTMENT,
            "DESIGN_LINE_TYPOS": extract_spells.DESIGN_LINE_TYPOS,
            "SPELL_NAME_TYPOS": extract_spells.SPELL_NAME_TYPOS,
            "EXCEPTION_SPELLS": exceptions_module.EXCEPTION_SPELLS,
        }
        by_book = self._names_by_book()
        for table_name, table in tables.items():
            for key in table:
                # SPELL_NAME_TYPOS is keyed by the misprint and corrected
                # before the other four are consulted, so compare on the
                # corrected name the same way run() does.
                probe = extract_spells.SPELL_NAME_TYPOS.get(key, key)
                with self.subTest(table=table_name, name=key):
                    hits = sorted(book_id for book_id, names in by_book.items()
                                  if probe in names)
                    # Two hits: a collision -- re-key this table by
                    # (book_id, name). Zero: the entry is stale.
                    self.assertEqual(len(hits), 1, msg=f"matched {hits}")
