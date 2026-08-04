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


def _block(name: str, technique: str, form: str, level: int) -> blocks.SpellBlock:
    return blocks.SpellBlock(
        name=name,
        technique=technique,
        form=form,
        printed_level=level,
        stat=statline.StatLine(
            range_name="Touch", duration_name="Sun", target_name="Ind",
            is_ritual=False, requisite_arts=[], trailing="",
        ),
        prose="Test prose.",
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

    def test_a_printed_magnitude_the_option_does_not_carry_raises(self):
        # crim-intricate-design is magnitude 1. A "+2 intricacy" would import a
        # spell one magnitude short of its printed level; block it instead.
        design = designline.parse_design("(Base 2, +1 Touch, +2 intricacy)")
        with self.assertRaises(designline.UnknownToken):
            emit.build_spell(
                _block("Test Spell", "Creo", "Imaginem", 10), "crim-2", self.catalog, design
            )
