"""Direct pins for emit.py's adjustment and elaborate-effect handling.

These paths were previously exercised only indirectly, through the six real
spells that RunTest happens to import. That is not enough: the option-id table
in `emit._ELABORATE_OPTIONS` is hand-written, the `adjustments` key is only set
when non-empty, and both facts are load-bearing for the committed asset's
shape. A failure here should name the mapping, not surface as a 250-entry
serialization diff.

The catalog is the real one. Pinning `elaborate-effect-minor` against a stub
would prove only that the stub agrees with itself; the point is that the ids
in emit.py are the ids in assets/data/modifiers.json.
"""
import unittest

from scripts.spell_import import blocks, catalog as catalog_module, designline, emit
from scripts.spell_import import statline


def _block(
    name: str, technique: str, form: str, level: int, prose: str = "Test prose."
) -> blocks.SpellBlock:
    return blocks.SpellBlock(
        name=name,
        technique=technique,
        form=form,
        printed_level=level,
        stat=statline.StatLine(
            range_name="Touch", duration_name="Sun", target_name="Ind",
            is_ritual=False, requisite_arts=[], trailing="",
        ),
        prose=prose,
        design_line=None,
        line_no=1,
    )


class AdjustmentEmissionTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog = catalog_module.Catalog.load()

    def _build(self, design_text: str) -> dict:
        design = designline.parse_design(design_text)
        return emit.build_spell(
            _block("Test Spell", "Rego", "Aquam", 10), "reaq-3", self.catalog, design
        )

    def test_an_adjustment_token_becomes_an_adjustments_entry(self):
        spell = self._build("(Base 1, +1 Touch, +2 Sun, +1 for slightly unnatural control)")
        self.assertEqual(
            spell["adjustments"],
            [{"magnitude": 1, "note": "for slightly unnatural control"}],
        )

    def test_the_note_keeps_the_bracketed_text(self):
        # The bracket is the content for this token, not decoration — see
        # designline._split_parts.
        spell = self._build("(Base 1, +1 Touch, +2 Special (based on Concentration))")
        self.assertEqual(
            spell["adjustments"],
            [{"magnitude": 2, "note": "Special (based on Concentration)"}],
        )

    def test_a_negative_adjustment_keeps_its_sign(self):
        spell = self._build("(Base 1, +1 Touch, -1 because the old limb is needed)")
        self.assertEqual(spell["adjustments"][0]["magnitude"], -1)

    def test_a_spell_with_no_adjustments_does_not_gain_the_key(self):
        # This is what keeps the existing 250 entries byte-identical: an empty
        # list would change every one of their serialized shapes.
        spell = self._build("(Base 1, +1 Touch, +2 Sun)")
        self.assertNotIn("adjustments", spell)


class ElaborateEffectEmissionTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog = catalog_module.Catalog.load()

    def _selected(self, design_text: str) -> dict:
        design = designline.parse_design(design_text)
        spell = emit.build_spell(
            _block("Test Spell", "Rego", "Terram", 10), "rete-3", self.catalog, design
        )
        return spell["selectedModifiers"]

    def test_each_magnitude_selects_its_option_id(self):
        for magnitude, option_id in [
            (1, "elaborate-effect-minor"),
            (2, "elaborate-effect-considerable"),
            (3, "elaborate-effect-extensive"),
        ]:
            with self.subTest(magnitude=magnitude):
                selected = self._selected(f"(Base 1, +1 Touch, +{magnitude} fancy effect)")
                self.assertEqual(selected["elaborate-effect"], [option_id])

    def test_a_spell_with_no_elaborate_token_does_not_select_the_modifier(self):
        self.assertNotIn("elaborate-effect", self._selected("(Base 1, +1 Touch)"))

    def test_two_elaborate_tokens_raise_rather_than_selecting_two_options(self):
        # elaborate-effect is selectionMode "single" in modifiers.json, so two
        # option ids under it is an asset the app's own validateSpellDraft
        # rejects. No corpus spell prints two elaborate tokens; blocking is the
        # correct outcome if one ever appears.
        with self.assertRaises(designline.UnknownToken):
            self._selected("(Base 1, +1 Touch, +1 fancy effect, +2 complex effect)")

    def test_elaborate_effect_is_a_single_selection_modifier_in_the_catalog(self):
        # The reason the check above exists. If this ever became "multi", the
        # raise would be wrong rather than merely unreachable.
        modifier = next(
            m for m in self.catalog.modifiers if m["id"] == "elaborate-effect"
        )
        self.assertEqual(modifier["selectionMode"], "single")

    def test_a_magnitude_outside_the_table_raises_rather_than_defaulting(self):
        # 4 is not a real elaborate-effect option. Blocking the spell is the
        # correct outcome; silently clamping to -extensive would import it with
        # a level that no longer matches the printed one.
        with self.assertRaises(designline.UnknownToken):
            self._selected("(Base 1, +1 Touch, +4 fancy effect)")

    def test_every_table_entry_names_a_real_option_at_that_magnitude(self):
        # Guards the hand-written id table against a typo or a rename in
        # modifiers.json, which nothing else in the Python suite would catch.
        modifier = next(
            m for m in self.catalog.modifiers if m["id"] == "elaborate-effect"
        )
        options = {o["id"]: o["magnitude"] for o in modifier["options"]}
        for magnitude, option_id in emit._ELABORATE_OPTIONS.items():
            with self.subTest(option_id=option_id):
                self.assertIn(option_id, options)
                self.assertEqual(options[option_id], magnitude)


class ModifierOptionTableTest(unittest.TestCase):
    """`emit._MODIFIER_OPTIONS` is hand-written; the catalog is the authority."""

    @classmethod
    def setUpClass(cls):
        cls.catalog = catalog_module.Catalog.load()

    def test_every_entry_names_a_real_option_under_a_real_modifier(self):
        for (technique, form, label), (modifier_id, option_id) in emit._MODIFIER_OPTIONS.items():
            with self.subTest(label=label):
                modifier = next(
                    (m for m in self.catalog.modifiers if m["id"] == modifier_id), None
                )
                self.assertIsNotNone(modifier, msg=modifier_id)
                self.assertIn(option_id, {o["id"] for o in modifier["options"]})
                scope = modifier["scope"]
                for key, value in (("technique", technique), ("form", form)):
                    if scope.get(key) is not None:
                        self.assertEqual(scope[key], value, msg=f"{modifier_id}.{key}")

    def test_a_mapped_label_selects_its_option(self):
        design = designline.parse_design("(Base 2, +1 Touch, +1 intricacy)")
        spell = emit.build_spell(
            _block("Test Spell", "Creo", "Imaginem", 10), "crim-2", self.catalog, design
        )
        self.assertEqual(spell["selectedModifiers"]["crim-complexity"], ["crim-intricate-design"])

    # The Imaginem complexity factors, each pinned at the magnitude its corpus
    # spell prints. The magnitude is half the pin: an option id that exists but
    # carries a different magnitude would import a real mechanism at the wrong
    # level, and the printed-vs-computed level check only catches that when the
    # error does not happen to cancel against another one.
    IMAGINEM_LABELS = [
        ("Creo", "Imaginem", "intricacy", "crim-complexity", "crim-intricate-design", 1),
        ("Creo", "Imaginem", "move at your command",
         "crim-complexity", "crim-directed-image", 2),
        ("Creo", "Imaginem", "move under your command",
         "crim-complexity", "crim-directed-image", 2),
        ("Creo", "Imaginem", "intelligible speech",
         "crim-complexity", "crim-sensory-complexity", 1),
        ("Rego", "Imaginem", "moved image matches changes",
         "reim-complexity", "reim-moved-image-matches", 1),
        ("Rego", "Imaginem", "additional senses",
         "reim-complexity", "reim-additional-senses", 1),
        ("Rego", "Imaginem", "additional sense",
         "reim-complexity", "reim-additional-senses", 1),
        ("Rego", "Imaginem", "moving image", "reim-complexity", "reim-changing-image", 1),
    ]

    def test_the_table_is_exactly_these_entries(self):
        # A new entry must be added here deliberately, with its verified
        # magnitude, rather than slipping in unpinned.
        self.assertEqual(
            emit._MODIFIER_OPTIONS,
            {
                (technique, form, label): (modifier_id, option_id)
                for technique, form, label, modifier_id, option_id, _ in self.IMAGINEM_LABELS
            },
        )

    def test_each_label_selects_its_option_at_its_printed_magnitude(self):
        for technique, form, label, modifier_id, option_id, magnitude in self.IMAGINEM_LABELS:
            with self.subTest(label=label):
                design = designline.parse_design(
                    f"(Base 2, +1 Touch, +{magnitude} {label})"
                )
                spell = emit.build_spell(
                    _block("Test Spell", technique, form, 10),
                    f"{modifier_id[:4]}-2",
                    self.catalog,
                    design,
                )
                self.assertEqual(spell["selectedModifiers"][modifier_id], [option_id])

    def test_a_label_the_table_does_not_map_still_raises(self):
        # "changing image" is a MODIFIER_LABELS token with a plausible-looking
        # catalog option (reim-changing-image, magnitude 1) that this table
        # deliberately does not wire, because its per-spell mapping was never
        # confirmed. It must keep blocking its four spells rather than being
        # absorbed by proximity to the entries that were confirmed.
        design = designline.parse_design("(Base 2, +1 Touch, +1 changing image)")
        with self.assertRaises(designline.UnknownToken):
            emit.build_spell(
                _block("Test Spell", "Rego", "Imaginem", 10), "reim-2", self.catalog, design
            )

    def test_a_mapped_label_under_the_wrong_art_raises(self):
        # The table is keyed on (Technique, Form) for a reason: "additional
        # sense" is a Rego Imaginem factor, and a Creo Imaginem spell printing
        # it has no verified meaning.
        design = designline.parse_design("(Base 2, +1 Touch, +1 additional sense)")
        with self.assertRaises(designline.UnknownToken):
            emit.build_spell(
                _block("Test Spell", "Creo", "Imaginem", 10), "crim-2", self.catalog, design
            )

    def test_a_printed_magnitude_the_option_does_not_carry_raises(self):
        # crim-intricate-design is magnitude 1. A "+2 intricacy" would import a
        # spell one magnitude short of its printed level; block it instead.
        design = designline.parse_design("(Base 2, +1 Touch, +2 intricacy)")
        with self.assertRaises(designline.UnknownToken):
            emit.build_spell(
                _block("Test Spell", "Creo", "Imaginem", 10), "crim-2", self.catalog, design
            )


class DescriptionEmissionTest(unittest.TestCase):
    """`description` is the full verbatim prose; `summary` stays untouched.

    emit._summary truncates block.prose to 400 characters and appends
    "Level N.". Nothing parses that suffix back out anymore: both Dart
    readers — asset_data_loader_test.dart and published_spell_import_test's
    assertion-1 oracle — now read the `printedLevel` field instead (see
    PrintedLevelEmissionTest below). The suffix survives only because
    removing it would rewrite all 263 summaries in the asset, which
    .superpowers/todo.md item 31 owns. description exists so the
    untruncated rulebook text is available too.
    """

    @classmethod
    def setUpClass(cls):
        cls.catalog = catalog_module.Catalog.load()

    def _build(self, prose: str, design_text: str = "(Base 1, +1 Touch, +2 Sun)") -> dict:
        design = designline.parse_design(design_text)
        block = _block("Test Spell", "Rego", "Aquam", 10, prose=prose)
        return emit.build_spell(block, "reaq-3", self.catalog, design)

    def test_description_is_the_full_prose_and_longer_than_the_truncated_summary(self):
        long_prose = "This is a very long sentence about magical effects. " * 20
        self.assertGreater(len(long_prose), 400)
        spell = self._build(long_prose)
        expected = " ".join(long_prose.split())
        self.assertEqual(spell["description"], expected)
        self.assertGreater(len(spell["description"]), len(spell["summary"]))

    def test_description_carries_no_level_suffix(self):
        spell = self._build("Some prose about the spell's effect.")
        self.assertNotRegex(spell["description"], r"Level \d+\.$")

    def test_description_whitespace_is_collapsed(self):
        spell = self._build("Some prose\nwith a  newline and  double  spaces.")
        self.assertNotIn("\n", spell["description"])
        self.assertNotIn("  ", spell["description"])

    def test_empty_prose_omits_the_description_key(self):
        spell = self._build("")
        self.assertNotIn("description", spell)


class PrintedLevelEmissionTest(unittest.TestCase):
    """`printedLevel` is the rulebook's printed level, emitted as its own field.

    asset_data_loader_test.dart reads this directly rather than
    regex-scraping the "Level N." phrase out of `summary` -- see
    scripts/spell_import/emit.py's build_spell. block.printed_level is
    int | None; every spell that actually reaches build_spell has one (a
    spell without one is routed to `blocked` before emission), so None here
    is a bug, not a valid input, and build_spell raises rather than emitting
    a null or omitting the key.
    """

    @classmethod
    def setUpClass(cls):
        cls.catalog = catalog_module.Catalog.load()

    def _build(self, level: int | None, design_text: str = "(Base 1, +1 Touch, +2 Sun)") -> dict:
        design = designline.parse_design(design_text)
        block = _block("Test Spell", "Rego", "Aquam", level)
        return emit.build_spell(block, "reaq-3", self.catalog, design)

    def test_printed_level_is_emitted_and_matches_the_block(self):
        spell = self._build(10)
        self.assertEqual(spell["printedLevel"], 10)

    def test_a_different_level_is_emitted_faithfully(self):
        spell = self._build(35)
        self.assertEqual(spell["printedLevel"], 35)

    def test_a_missing_printed_level_raises_rather_than_emitting_null(self):
        with self.assertRaises(ValueError):
            self._build(None)
