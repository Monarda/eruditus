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
        ("Perdo", "Imaginem", "changing image",
         "peim-complexity", "peim-changing-image", 1),
        ("Rego", "Imaginem", "moved image matches changes",
         "reim-complexity", "reim-moved-image-matches", 1),
        ("Rego", "Imaginem", "additional senses",
         "reim-complexity", "reim-additional-senses", 1),
        ("Rego", "Imaginem", "additional sense",
         "reim-complexity", "reim-additional-senses", 1),
        ("Rego", "Imaginem", "moving image", "reim-complexity", "reim-changing-image", 1),
        ("Rego", "Imaginem", "changing image",
         "reim-complexity", "reim-changing-image", 1),
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
        # "changing image" is wired for Perdo and Rego Imaginem (see
        # IMAGINEM_LABELS above), but the table is keyed on (Technique, Form).
        # Creo Imaginem has no confirmed "changing image" mapping, so it must
        # keep blocking rather than being absorbed by proximity to the
        # Perdo/Rego entries that share the same label.
        design = designline.parse_design("(Base 2, +1 Touch, +1 changing image)")
        with self.assertRaises(designline.UnknownToken):
            emit.build_spell(
                _block("Test Spell", "Creo", "Imaginem", 10), "crim-2", self.catalog, design
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


class TransportDistanceEmissionTest(unittest.TestCase):
    """Regression coverage for backlog item 43: emit.py's rego-transport-distance
    table used the wrong option-id prefix (rego-transport-distance-* instead of
    the catalog's actual rego-distance-*), so _option_exists always failed and
    any spell selecting a transport-distance token would raise UnknownToken.

    Built from Token/Design objects directly rather than designline.parse_design:
    the design-line tokenizer's MODIFIER_LABELS allow-list does not yet
    recognize these labels ("distance", "50 paces", etc.) as modifier-kind
    tokens at all -- a separate, larger gap (see backlog item 45) that this
    fix does not attempt to close. This test exercises emit.py's mapping
    table directly, independent of that gap.
    """

    @classmethod
    def setUpClass(cls):
        cls.catalog = catalog_module.Catalog.load()

    DISTANCE_LABELS = [
        ("5 paces", "rego-distance-5-paces", 0),
        ("50 paces", "rego-distance-50-paces", 1),
        ("500 paces", "rego-distance-500-paces", 2),
        ("1 league", "rego-distance-1-league", 3),
        ("7 leagues", "rego-distance-7-leagues", 4),
        ("arcane connection", "rego-distance-arcane", 5),
    ]

    def test_each_distance_label_selects_its_option_at_its_printed_magnitude(self):
        for label, option_id, magnitude in self.DISTANCE_LABELS:
            with self.subTest(label=label):
                design = designline.Design(
                    base_level=3,
                    tokens=[designline.Token(magnitude=magnitude, label=label, kind="modifier")],
                )
                spell = emit.build_spell(
                    _block("Test Spell", "Rego", "Herbam", 10), "rehe-10b", self.catalog, design
                )
                self.assertEqual(spell["selectedModifiers"]["rego-transport-distance"], [option_id])

    def test_an_unmapped_distance_label_still_raises(self):
        # "distance" is in the emit.py block's label-matching tuple (so it
        # enters this code path) but was never given a real table entry --
        # it should still raise, not silently pick a default rung.
        design = designline.Design(
            base_level=3,
            tokens=[designline.Token(magnitude=1, label="distance", kind="modifier")],
        )
        with self.assertRaises(designline.UnknownToken):
            emit.build_spell(
                _block("Test Spell", "Rego", "Herbam", 10), "rehe-10b", self.catalog, design
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


class GeneralTemplateEmissionTest(unittest.TestCase):
    """`build_template` is `build_spell`'s General-branch counterpart.

    A General spell block carries `printed_level=None` and a design line
    whose base is a General marker ("Base spell", "Base effect", "As ward
    guideline") rather than a number, so `design.base_level` is also `None`.
    `build_spell` cannot handle that shape at all -- it raises on the missing
    printed level -- so `build_template` has to be a distinct function, not a
    branch inside `build_spell`.
    """

    @classmethod
    def setUpClass(cls):
        cls.catalog = catalog_module.Catalog.load()

    def _build(self, design_text: str = "(Base spell, +1 Touch, +2 Sun)") -> dict:
        design = designline.parse_design(design_text)
        block = _block("Demon's Eternal Oblivion", "Perdo", "Vim", None)
        return emit.build_template(block, "pevi-G3", self.catalog, design)

    def test_build_template_omits_every_level_field(self):
        template = self._build()

        self.assertNotIn("chosenBaseLevel", template)
        self.assertNotIn("printedLevel", template)
        self.assertTrue(template["id"].startswith("tpl-"))

    def test_the_template_id_is_the_slug_id_with_tpl_in_place_of_lib(self):
        # "Derive one from the other; do not introduce a second slug
        # function" -- pin the actual relationship, not just the prefix.
        template = self._build()
        slug = catalog_module.slug_id("Perdo", "Vim", "Demon's Eternal Oblivion")
        self.assertEqual(template["id"], "tpl-" + slug.removeprefix("lib-"))

    def test_a_general_block_does_not_raise_despite_no_printed_level(self):
        # build_spell raises ValueError on this exact block shape; build_template
        # is the routing path that guard exists to protect, so it must not.
        try:
            self._build()
        except ValueError as error:
            self.fail(f"build_template raised on a printed_level=None block: {error}")

    def test_the_summary_does_not_print_a_none_level(self):
        # _summary appends "Level {block.printed_level}." -- naively reusing
        # it here would emit the literal string "Level None." into the asset.
        template = self._build()
        self.assertNotIn("None", template["summary"])

    def test_the_base_effect_id_passed_in_is_carried_through_unchanged(self):
        template = self._build()
        self.assertEqual(template["baseEffectId"], "pevi-G3")

    def test_required_fields_are_present(self):
        template = self._build()
        for field in ("id", "name", "baseEffectId", "rangeId", "durationId",
                      "targetId", "source", "summary", "citations", "requisites",
                      "selectedModifiers"):
            self.assertIn(field, template, msg=field)
        self.assertEqual(template["source"], "published")
        self.assertEqual(template["citations"], [{"bookId": "arm5-core"}])


class OpenSlotEmissionTest(unittest.TestCase):
    """`chosenSlots["realm"]` is set from `REALM_BY_SPELL_ID`, never scanned
    from prose -- see extract_spells.py's `REALM_BY_SPELL_ID` comment for why.
    """

    @classmethod
    def setUpClass(cls):
        cls.catalog = catalog_module.Catalog.load()

    def test_build_template_sets_chosenSlots_when_the_table_has_an_entry(self):
        design = designline.parse_design("(As ward guideline, +1 Touch, +1 Ring)")
        block = _block("Circular Ward against Demons", "Rego", "Vim", None)
        template = emit.build_template(
            block, "revi-G1", self.catalog, design,
            realm_by_spell_id={"lib-revi-circular-ward-against-demons": "Infernal"},
        )
        self.assertEqual(template["chosenSlots"], {"realm": "Infernal"})

    def test_build_template_omits_chosenSlots_when_the_table_has_no_entry(self):
        design = designline.parse_design("(Base effect, +2 Voice, +2 Room)")
        block = _block("Wind of Mundane Silence", "Perdo", "Vim", None)
        template = emit.build_template(
            block, "pevi-G5", self.catalog, design, realm_by_spell_id={},
        )
        self.assertNotIn("chosenSlots", template)

    def test_build_template_omits_chosenSlots_when_the_effect_declares_no_open_slot(self):
        # pevi-G3 has no openSlots at all -- a table entry, if one existed,
        # must not leak onto a guideline that never declared anything open.
        design = designline.parse_design("(Base spell, +1 Touch, +2 Sun)")
        block = _block("Demon's Eternal Oblivion", "Perdo", "Vim", None)
        template = emit.build_template(
            block, "pevi-G3", self.catalog, design,
            realm_by_spell_id={"lib-pevi-demons-eternal-oblivion": "Infernal"},
        )
        self.assertNotIn("chosenSlots", template)

    def test_realm_by_spell_id_defaults_to_empty_when_omitted(self):
        design = designline.parse_design("(As ward guideline, +1 Touch, +1 Ring)")
        block = _block("Circular Ward against Demons", "Rego", "Vim", None)
        template = emit.build_template(block, "revi-G1", self.catalog, design)
        self.assertNotIn("chosenSlots", template)


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


class NumberedOverrideEmissionTest(unittest.TestCase):
    """`build_spell`'s chosen_base_level/override_modifiers parameters --
    the wiring NUMBERED_OVERRIDES (extract_spells.py) uses to resolve a
    design line whose numeric base has no exact catalog match. See this
    file's own docs/superpowers/specs/2026-08-15-guideline-level-derivation-design.md
    for why these are needed.
    """

    @classmethod
    def setUpClass(cls):
        cls.catalog = catalog_module.Catalog.load()

    def test_chosen_base_level_is_emitted_only_when_provided(self):
        design = designline.parse_design("(Base 25, +2 Voice, +1 Conc)")
        block = _block("Infernal Smoke of Death", "Muto", "Auram", 40)
        spell = emit.build_spell(
            block, "muau-gen", self.catalog, design, chosen_base_level=25,
        )
        self.assertEqual(spell["chosenBaseLevel"], 25)

    def test_chosen_base_level_is_omitted_when_not_provided(self):
        design = designline.parse_design("(Base 3, +1 Touch, +1 Dia)")
        block = _block("Taint Something", "Creo", "Vim", 3)
        spell = emit.build_spell(block, "crvi-3", self.catalog, design)
        self.assertNotIn("chosenBaseLevel", spell)

    def test_override_modifiers_are_merged_into_selectedModifiers(self):
        design = designline.parse_design("(Base 20, +2 Voice)")
        block = _block("The Enigma's Gift", "Creo", "Vim", 30)
        spell = emit.build_spell(
            block, "crvi-5a", self.catalog, design,
            override_modifiers={"warping-point-burst": ["warping-point-burst-4"]},
        )
        self.assertEqual(
            spell["selectedModifiers"]["warping-point-burst"],
            ["warping-point-burst-4"],
        )

    def test_override_modifiers_default_to_no_change_when_not_provided(self):
        design = designline.parse_design("(Base 3, +1 Touch, +1 Dia)")
        block = _block("Taint Something", "Creo", "Vim", 3)
        spell = emit.build_spell(block, "crvi-3", self.catalog, design)
        self.assertEqual(spell["selectedModifiers"], {})

    def test_override_modifiers_with_an_unknown_option_id_raises(self):
        design = designline.parse_design("(Base 20, +2 Voice)")
        block = _block("The Enigma's Gift", "Creo", "Vim", 30)
        with self.assertRaises(designline.UnknownToken):
            emit.build_spell(
                block, "crvi-5a", self.catalog, design,
                override_modifiers={"warping-point-burst": ["warping-point-burst-does-not-exist"]},
            )

    def test_override_modifiers_with_an_unknown_modifier_id_raises(self):
        design = designline.parse_design("(Base 20, +2 Voice)")
        block = _block("The Enigma's Gift", "Creo", "Vim", 30)
        with self.assertRaises(designline.UnknownToken):
            emit.build_spell(
                block, "crvi-5a", self.catalog, design,
                override_modifiers={"no-such-modifier": ["whatever"]},
            )


class RequisiteEmissionTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog = catalog_module.Catalog.load()

    def test_requisites_serialize_as_a_dict_keyed_by_art(self):
        design = designline.parse_design("(Base 5, +1 Touch, +1 Rego requisite)")
        block = blocks.SpellBlock(
            name="Test Spell", technique="Creo", form="Ignem", printed_level=10,
            stat=statline.StatLine(
                range_name="Touch", duration_name="Sun", target_name="Ind",
                is_ritual=False, requisite_arts=[], trailing="",
            ),
            prose="Test prose.", design_line=None, line_no=1,
        )
        spell = emit.build_spell(block, "test-effect", self.catalog, design)
        self.assertEqual(spell["requisites"], {"Rego": "adding"})

    def test_a_bare_requisite_token_resolves_against_the_sole_stat_line_art(self):
        # The Eye of the Sage: "+1 requisite" (no art in the design line) +
        # "Req: Imaginem" (one art in the stat line) -> resolves to Imaginem.
        design = designline.parse_design("(Base 4, +4 Arc, +1 Conc, +1 requisite)")
        block = blocks.SpellBlock(
            name="Test Spell", technique="Intellego", form="Imaginem", printed_level=10,
            stat=statline.StatLine(
                range_name="Arcane Connection", duration_name="Concentration",
                target_name="Ind", is_ritual=False, requisite_arts=["Imaginem"],
                trailing="",
            ),
            prose="Test prose.", design_line=None, line_no=1,
        )
        spell = emit.build_spell(block, "test-effect", self.catalog, design)
        self.assertEqual(spell["requisites"], {"Imaginem": "adding"})

    def test_a_bare_requisite_token_with_no_stat_line_art_raises(self):
        design = designline.parse_design("(Base 4, +4 Arc, +1 Conc, +1 requisite)")
        block = blocks.SpellBlock(
            name="Test Spell", technique="Intellego", form="Imaginem", printed_level=10,
            stat=statline.StatLine(
                range_name="Arcane Connection", duration_name="Concentration",
                target_name="Ind", is_ritual=False, requisite_arts=[], trailing="",
            ),
            prose="Test prose.", design_line=None, line_no=1,
        )
        with self.assertRaises(designline.UnknownToken):
            emit.build_spell(block, "test-effect", self.catalog, design)

    def test_a_bare_requisite_token_with_two_stat_line_arts_raises(self):
        # Ambiguous which art the magnitude belongs to -- must not guess.
        design = designline.parse_design("(Base 4, +4 Arc, +1 Conc, +1 requisite)")
        block = blocks.SpellBlock(
            name="Test Spell", technique="Intellego", form="Imaginem", printed_level=10,
            stat=statline.StatLine(
                range_name="Arcane Connection", duration_name="Concentration",
                target_name="Ind", is_ritual=False,
                requisite_arts=["Imaginem", "Mentem"], trailing="",
            ),
            prose="Test prose.", design_line=None, line_no=1,
        )
        with self.assertRaises(designline.UnknownToken):
            emit.build_spell(block, "test-effect", self.catalog, design)

    def test_a_design_line_requisite_is_not_overwritten_by_the_stat_lines_free_default(self):
        """setdefault, not assignment: the design line is more specific than
        the bare Req: stat line, so it must win when both name the same art.
        A spell whose design line prints "+1 Rego requisite" alongside a
        "Req: Rego" stat line must keep the adding cost, not silently drop to
        free."""
        design = designline.parse_design("(Base 5, +1 Touch, +1 Rego requisite)")
        block = blocks.SpellBlock(
            name="Test Spell", technique="Creo", form="Ignem", printed_level=10,
            stat=statline.StatLine(
                range_name="Touch", duration_name="Sun", target_name="Ind",
                is_ritual=False, requisite_arts=["Rego"], trailing="",
            ),
            prose="Test prose.", design_line=None, line_no=1,
        )
        spell = emit.build_spell(block, "test-effect", self.catalog, design)
        self.assertEqual(spell["requisites"], {"Rego": "adding"})
