import collections
import json
import re
import unittest

from scripts.spell_import import blocks, catalog as catalog_module, designline, extract_spells, sources

_TABLE_HEADER = re.compile(r"^\|\s*Level\s*\|\s*(\w+)\s+(\w+)\s+Guideline\s*\|")
_GENERAL_ROW = re.compile(r"^\|\s*General\s*\|\s*(.+?)\s*\|\s*$")


def _rulebook_general_bullets() -> dict[tuple[str, str], list[str]]:
    """Every `| General |` bullet in the printed guideline tables, by art.

    Deliberately a separate, dumber parser than `blocks.py`: this is the
    oracle the catalog is measured against, so it must not share code with
    the extractor that produced the catalog. If both had the same bug they
    would agree, and the test would pass while both were wrong.
    """
    path = sources.resolve_book(sources.DE_TITLE, sources.default_root())
    art: tuple[str, str] | None = None
    bullets: dict[tuple[str, str], list[str]] = {}

    for line in sources.read_lines(path):
        header = _TABLE_HEADER.match(line)
        if header:
            art = (header.group(1), header.group(2))
            continue
        if art is None:
            continue
        row = _GENERAL_ROW.match(line)
        if row:
            bullets[art] = [
                cell.strip().lstrip("•").strip()
                for cell in row.group(1).split("<br>")
                if cell.strip()
            ]
        elif line.strip() and not line.startswith("|"):
            # Out of the table. Without this the next art's rows would be
            # attributed to the previous art's header.
            art = None

    return bullets

VALID_KINDS = {
    "mightThreshold", "mightReduction", "damage",
    "targetSpellLevel", "visDestroyed", "spellTraceMagnitude",
    "castingTotalReduction",
}
VALID_MULTIPLIERS = {"half", "one", "two"}
VALID_UNITS = {"levels", "magnitudes"}

STANDARD_REFERENCE = {
    "rangeId": "range-personal",
    "durationId": "duration-momentary",
    "targetId": "target-individual",
}


class GeneralCatalogTest(unittest.TestCase):
    def setUp(self):
        self.catalog = catalog_module.Catalog.load()
        self.general = [e for e in self.catalog.base_effects
                        if e["baseLevel"] is None]
        # Every test below that compares the catalog against the *rulebook's*
        # printed tables must compare only the rows that came from it. The
        # catalog gained its first supplement row in todo item 17, and
        # counting that against the core tables reports a surplus — which
        # this file's own failure messages read as "somebody invented a
        # guideline", the exact opposite of what happened. See todo item 55.
        self.core_general = [e for e in self.general
                             if catalog_module.cites(e, catalog_module.CORE_BOOK_ID)]
        self.parameter_ids = {p["id"] for p in self.catalog.parameters}

    def test_there_are_49_general_entries(self):
        # 47 when this test was written, plus the four the extractor had
        # silently dropped (todo item 34): rean-gen-2, muaq-gen-2, reme-G2
        # and mute-gen. Muto Terram had no General entry at all.
        #
        # Then minus two. Item 34 counted rulebook bullets the catalog was
        # missing; it never counted catalog rows the rulebook does not
        # contain. peme-G and inco-gen were both of the latter: neither the
        # Perdo Mentem table (levels 3-25) nor the Intellego Corpus table
        # (levels 3-35) prints a General row at all, and each entry's
        # description is its spell's own effect text read backwards into a
        # guideline. Removing them is what blocks Lay to Rest the Haunting
        # Spirit honestly rather than importing it against a row invented
        # to receive it.
        #
        # Counts core rows only. Supplement guidelines are real catalog rows
        # but are not part of what the core rulebook prints, so they belong
        # to neither side of this number (todo item 55).
        self.assertEqual(len(self.core_general), 49)

    def test_general_entries_match_the_rulebook_bullet_for_bullet(self):
        """Todo item 34 in both directions, derived from the rulebook.

        Item 34 counted the bullets the extractor had dropped and stopped
        there. It never counted the other direction, and there were two:
        peme-G and inco-gen, in arts whose guideline tables print no General
        row at all. Each described its spell's own effect text read backwards
        into a guideline, which is why no other test here could see them —
        a fabricated row has a well-formed id, a plausible description and a
        formula, and the spell that needed it imports cleanly.

        Counting per art rather than in total is what makes this bite: a
        dropped bullet in one art and an invented row in another cancel out
        in a single number, and that is very nearly what had happened.

        The expectation is parsed from the rulebook, not written down here,
        so it cannot drift out of date the way a hand-maintained constant
        does. That is also what keeps it honest: the catalog is checked
        against the source it was extracted from, never against itself.
        """
        book = _rulebook_general_bullets()
        catalog_counts = collections.Counter(
            (e["technique"], e["form"]) for e in self.core_general)
        book_counts = collections.Counter(
            {art: len(bullets) for art, bullets in book.items()})

        self.assertEqual(
            sorted(catalog_counts.items()), sorted(book_counts.items()),
            "the catalog's General rows no longer match the rulebook's "
            "General bullets art by art. A shortfall means the extractor "
            "dropped a bullet; a surplus means somebody invented a "
            "guideline. Fix the catalog, never this test.")

    def test_every_core_general_entry_has_a_formula(self):
        """Core rows only — a supplement row may legitimately have none.

        `crvi-hohmc-G1` is the first and so far only one: its Might
        threshold is measured against the spell's *total* computed level,
        not the `chosenBaseLevel` an `effectFormula` reads, and it prints no
        reference triple that would make those two coincide. Item 17 dropped
        the formula it was first authored with rather than state a
        relationship the rulebook does not. The cost is real and accepted —
        no derived effect sentence renders for that guideline — so this test
        stays exact for core rows instead of relaxing to "most rows".
        """
        missing = [e["id"] for e in self.core_general if not e.get("effectFormula")]
        self.assertEqual(missing, [])

    def test_no_ordinary_entry_has_a_formula(self):
        stray = [e["id"] for e in self.catalog.base_effects
                 if e["baseLevel"] is not None and e.get("effectFormula")]
        self.assertEqual(stray, [])

    def test_every_formula_field_is_in_range(self):
        # Every General row that *has* a formula, core or not: a row without
        # one is the test above's subject, and a supplement row that does
        # carry one is still held to the same value ranges.
        for effect in [e for e in self.general if e.get("effectFormula")]:
            formula = effect["effectFormula"]
            with self.subTest(effect["id"]):
                self.assertIn(formula["kind"], VALID_KINDS)
                self.assertIn(formula.get("multiplier", "one"), VALID_MULTIPLIERS)
                self.assertIn(formula.get("unit", "levels"), VALID_UNITS)
                self.assertIsInstance(formula.get("offsetMagnitudes", 0), int)

    def test_every_reference_names_real_parameters(self):
        for effect in self.catalog.base_effects:
            reference = effect.get("reference", STANDARD_REFERENCE)
            with self.subTest(effect["id"]):
                for key in ("rangeId", "durationId", "targetId"):
                    self.assertIn(reference[key], self.parameter_ids)

    def test_every_ward_is_priced_against_touch_ring_circle(self):
        # Every ward bullet in the rulebook ends "(Touch, Ring, Circle)", and
        # there are exactly 12 of them. The catalog held 10 until todo item 34
        # restored the two the extractor had dropped: rean-gen-2 (the circle
        # warding against animals, which the rulebook distinguishes from
        # beings associated with Animal) and reme-G2 (spirits of one realm,
        # which had been merged into reme-G's description).
        # Assert equality, not a lower bound — a bound would not notice a ward
        # losing its formula.
        #
        # Core rows only, and the count is the core rulebook's own 12. A
        # supplement ward would be a 13th real ward but not a 13th bullet in
        # the tables this number came from (todo item 55).
        wards = [e for e in self.core_general
                 if e.get("effectFormula", {}).get("kind") == "mightThreshold"]
        self.assertEqual(len(wards), 12)
        for effect in wards:
            with self.subTest(effect["id"]):
                self.assertEqual(effect["reference"], {
                    "rangeId": "range-touch",
                    "durationId": "duration-ring",
                    "targetId": "target-circle",
                })


class ReferenceOracleTest(unittest.TestCase):
    """Assertion 6 — the only automated check a General spell can have.

    Assertion 1 ("every spell computes to its printed level") discriminates
    nothing here: there is no printed level, and every candidate shares the
    same absent base level, so a wrong ledger pick computes identically to a
    right one. This is todo item 32's hazard at full strength, on 22 spells.

    The check is non-circular only because references are authored from the
    guideline row's printed parenthetical, never inferred from the design
    lines this test compares them against.
    """

    def setUp(self):
        self.catalog = catalog_module.Catalog.load()
        self.magnitudes = {p["id"]: p["magnitude"] for p in self.catalog.parameters}
        path = catalog_module.DATA_DIR / "spell_templates.json"
        self.templates = json.loads(path.read_text(encoding="utf-8"))
        book = sources.resolve_book(sources.DE_TITLE)
        parsed, _ = blocks.parse_de(sources.read_lines(book))
        self.blocks_by_name = {b.name: b for b in parsed}

    def test_design_line_tokens_equal_actual_cost_minus_reference_cost(self):
        for template in self.templates:
            if not catalog_module.cites(template, catalog_module.CORE_BOOK_ID):
                # This oracle reads the core rulebook's own parsed blocks, so
                # it has nothing to say about a template printed in a
                # supplement -- there is no block to compare against. Keyed
                # on the template's own citation rather than a name list, so
                # a *core* template vanishing from the blocks still raises
                # KeyError below instead of being quietly skipped.
                continue
            block = self.blocks_by_name[template["name"]]
            # `HAND_DERIVED` checked before `block.design_line`, exactly the
            # precedence `extract_spells.run()` itself uses (see its own
            # dispatch comment) -- a spell whose printed design line is real
            # but incomplete (e.g. Dispel the Phantom Image's bare "(Base
            # effect)", missing the "+2 Voice" token every literal sibling
            # spell in the same guideline family prints) must be checked
            # against the *corrected* text `extract_spells.run()` actually
            # emitted the template from, not a second, independent parse of
            # the raw rulebook string -- otherwise this oracle would be
            # checking stale input, not a genuinely different calculation.
            # `SpellBlock.design_line` is `str | None`. A spell with neither
            # a `HAND_DERIVED` entry nor a printed design line has no
            # magnitudes to compare, so there is nothing for this oracle to
            # say about it — skip rather than crash. Task 12's review
            # confirms how many are skipped; if that number is not small,
            # the ledger is importing spells this assertion cannot actually
            # vouch for.
            design_text = extract_spells.HAND_DERIVED.get(template["name"]) or block.design_line
            if design_text is None:
                continue
            design = designline.parse_design(design_text)

            actual = sum(self.magnitudes[template[key]] for key in
                         ("rangeId", "durationId", "targetId"))
            reference = self.catalog.reference_cost(template["baseEffectId"])
            printed = sum(token.magnitude for token in design.tokens
                          if token.label in designline.PARAMETER_LABELS)

            with self.subTest(template["id"]):
                self.assertEqual(
                    printed, actual - reference,
                    f"{template['name']}: the rulebook prints {printed} magnitudes "
                    f"of Range/Duration/Target, but its stat line costs {actual} "
                    f"against a guideline reference of {reference}. Either the "
                    f"ledger picked the wrong guideline, or "
                    f"{template['baseEffectId']}'s reference is mis-authored. "
                    f"Do NOT adjust the reference to make this pass.")


class FormulaRenderingTest(unittest.TestCase):
    """Assertion 7 — every emitted effect sentence is generated, not copied."""

    def test_every_general_entry_a_template_uses_has_a_formula(self):
        catalog = catalog_module.Catalog.load()
        by_id = {e["id"]: e for e in catalog.base_effects}
        path = catalog_module.DATA_DIR / "spell_templates.json"

        for template in json.loads(path.read_text(encoding="utf-8")):
            effect = by_id[template["baseEffectId"]]
            with self.subTest(template["id"]):
                # Holds for every template, core or not: a template exists
                # precisely because its level is the caster's to choose.
                self.assertIsNone(effect["baseLevel"],
                                  "a template must point at a General guideline")
                if not catalog_module.cites(effect, catalog_module.CORE_BOOK_ID):
                    # A supplement guideline may legitimately carry no
                    # formula (see test_every_core_general_entry_has_a_formula
                    # for why crvi-hohmc-G1 does not). The consequence is that
                    # this template renders no derived effect sentence --
                    # accepted by item 17, not an oversight.
                    continue
                self.assertIsNotNone(effect.get("effectFormula"))
