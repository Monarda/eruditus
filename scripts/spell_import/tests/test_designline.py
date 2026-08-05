import unittest

from scripts.spell_import import designline


class ParseDesignTest(unittest.TestCase):
    def test_plain_base_and_parameters(self):
        design = designline.parse_design("(Base 4, +1 Touch, +3 Moon)")
        self.assertEqual(design.base_level, 4)
        self.assertEqual([(t.magnitude, t.label) for t in design.tokens],
                         [(1, "Touch"), (3, "Moon")])

    def test_base_level_spelling(self):
        self.assertEqual(designline.parse_design("(Base level 15, +1 Touch)").base_level, 15)

    def test_base_colon_spelling(self):
        self.assertEqual(designline.parse_design("(Base: 15, +1 Touch, +2 Group)").base_level, 15)

    def test_general_spells_have_no_base_level(self):
        design = designline.parse_design("(Base effect, +1 Touch, +4 Boundary)")
        self.assertIsNone(design.base_level)

    def test_period_separator(self):
        design = designline.parse_design("(Base 5. +2 Sun)")
        self.assertEqual(design.base_level, 5)
        self.assertEqual(len(design.tokens), 1)

    def test_parenthesised_comment_is_ignored(self):
        design = designline.parse_design("(Base 4 (a very unnatural liquid), +1 Touch)")
        self.assertEqual(design.base_level, 4)
        self.assertEqual(len(design.tokens), 1)

    def test_requisite_tokens(self):
        design = designline.parse_design("(Base 5, +1 Touch, +1 Creo requisite)")
        requisite = design.tokens[-1]
        self.assertEqual(requisite.kind, "requisite")
        self.assertEqual(requisite.magnitude, 1)
        self.assertEqual(requisite.label, "Creo")

    def test_free_requisite_costs_nothing(self):
        design = designline.parse_design("(Base 4, +1 Touch, +3 Moon, requisite free)")
        self.assertEqual(design.tokens[-1].kind, "requisite")
        self.assertEqual(design.tokens[-1].magnitude, 0)

    def test_size_token_is_a_modifier(self):
        design = designline.parse_design("(Base 3, +2 Voice, +2 Sun, +1 size)")
        self.assertEqual(design.tokens[-1].kind, "modifier")
        self.assertEqual(design.tokens[-1].label, "size")

    def test_unknown_token_raises(self):
        # "+2 metal/gems" is a real, unmodelled mechanism (Stone to Falling
        # Dust). It must fail loudly so the spell is reported blocked, not
        # imported with a silently dropped magnitude. This example used to be
        # "+1 fancy effect", which ElaborateEffectTest below now recognises.
        with self.assertRaises(designline.UnknownToken):
            designline.parse_design("(Base 10, +1 Touch, +2 metal/gems)")


class VocabularyAdditionsTest(unittest.TestCase):
    """Direct pins for the vocabulary added beyond the original brief
    (commit a95bcd7): each entry was hand-verified against a real DE spell,
    but VocabularyCoverageTest below only asserts parsing doesn't raise, so
    none of them had a test asserting the actual kind/label/magnitude. These
    are synthetic minimal design lines, not corpus lookups, so a future typo
    in the mapping (e.g. "Str" resolving to the wrong parameter, or
    _REQUISITE_EFFECT producing kind="modifier") fails fast and locally.
    """

    def test_str_is_the_structure_parameter(self):
        design = designline.parse_design("(Base 5, +1 Touch, +3 Str)")
        token = design.tokens[-1]
        self.assertEqual(token.kind, "parameter")
        self.assertEqual(token.label, "Structure")
        self.assertEqual(token.magnitude, 3)

    def test_eve_is_the_eye_parameter(self):
        design = designline.parse_design("(Base 5, +1 Eve)")
        token = design.tokens[-1]
        self.assertEqual(token.kind, "parameter")
        self.assertEqual(token.label, "Eye")
        self.assertEqual(token.magnitude, 1)

    def test_dia_is_the_diameter_parameter(self):
        design = designline.parse_design("(Base 5, +1 Dia)")
        token = design.tokens[-1]
        self.assertEqual(token.kind, "parameter")
        self.assertEqual(token.label, "Diameter")
        self.assertEqual(token.magnitude, 1)

    def test_technique_effect_phrasing_is_a_requisite_not_a_modifier(self):
        # "<Technique> effect" (_REQUISITE_EFFECT) is an alternate spelling of
        # "<Technique> requisite" used alongside a "Req: <Technique>" stat
        # line (e.g. Circling Winds of Protection). Must come out as
        # kind="requisite" with the technique as the label, not "modifier".
        design = designline.parse_design("(Base 5, +1 Touch, +1 Rego effect)")
        token = design.tokens[-1]
        self.assertEqual(token.kind, "requisite")
        self.assertEqual(token.label, "Rego")
        self.assertEqual(token.magnitude, 1)

    def test_free_requisite_no_increase_phrasing(self):
        design = designline.parse_design("(Base 5, +1 Touch, no increase for requisite)")
        token = design.tokens[-1]
        self.assertEqual(token.kind, "requisite")
        self.assertEqual(token.magnitude, 0)

    def test_free_requisite_is_free_phrasing(self):
        design = designline.parse_design("(Base 5, +1 Touch, requisite is free)")
        token = design.tokens[-1]
        self.assertEqual(token.kind, "requisite")
        self.assertEqual(token.magnitude, 0)

    def test_free_requisite_no_cost_for_technique_effect_phrasing(self):
        design = designline.parse_design("(Base 5, +1 Touch, no cost for Rego effect)")
        token = design.tokens[-1]
        self.assertEqual(token.kind, "requisite")
        self.assertEqual(token.magnitude, 0)

    def test_crim_directed_image_move_at_your_command(self):
        design = designline.parse_design("(Base 5, +2 move at your command)")
        token = design.tokens[-1]
        self.assertEqual(token.kind, "modifier")
        self.assertEqual(token.label, "move at your command")
        self.assertEqual(token.magnitude, 2)

    def test_crim_directed_image_move_under_your_command(self):
        design = designline.parse_design("(Base 5, +2 move under your command)")
        token = design.tokens[-1]
        self.assertEqual(token.kind, "modifier")
        self.assertEqual(token.label, "move under your command")
        self.assertEqual(token.magnitude, 2)

    def test_crim_sensory_complexity_intelligible_speech(self):
        design = designline.parse_design("(Base 5, +1 intelligible speech)")
        token = design.tokens[-1]
        self.assertEqual(token.kind, "modifier")
        self.assertEqual(token.label, "intelligible speech")
        self.assertEqual(token.magnitude, 1)

    def test_reim_moved_image_matches_changes(self):
        design = designline.parse_design("(Base 5, +1 moved image matches changes)")
        token = design.tokens[-1]
        self.assertEqual(token.kind, "modifier")
        self.assertEqual(token.label, "moved image matches changes")
        self.assertEqual(token.magnitude, 1)

    def test_reim_additional_senses_plural(self):
        design = designline.parse_design("(Base 5, +1 additional senses)")
        token = design.tokens[-1]
        self.assertEqual(token.kind, "modifier")
        self.assertEqual(token.label, "additional senses")
        self.assertEqual(token.magnitude, 1)

    def test_reim_additional_sense_singular(self):
        design = designline.parse_design("(Base 5, +1 additional sense)")
        token = design.tokens[-1]
        self.assertEqual(token.kind, "modifier")
        self.assertEqual(token.label, "additional sense")
        self.assertEqual(token.magnitude, 1)

    def test_reim_moving_image(self):
        design = designline.parse_design("(Base 5, +1 moving image)")
        token = design.tokens[-1]
        self.assertEqual(token.kind, "modifier")
        self.assertEqual(token.label, "moving image")
        self.assertEqual(token.magnitude, 1)


class SplittingTest(unittest.TestCase):
    def test_a_comma_inside_parentheses_does_not_split_a_token(self):
        design = designline.parse_design(
            "(Base 1, +1 Touch, +4 Year, +1 Size (for a total of +4 Size, including "
            "the +3 from the guideline))"
        )
        labels = [t.label for t in design.tokens]
        self.assertIn("Size", labels)
        self.assertNotIn("including the +3 from the guideline", labels)

    def test_split_parts_keeps_a_nested_aside_whole(self):
        """The case that actually distinguishes the two splitters.

        The test above passes under the old strip-then-split code too: with a
        singly-nested aside, removing it wholesale before splitting also
        happens to leave the right tokens. The discriminating shape is a
        *nested* aside, because `_PARENTHETICAL` is not nesting-aware -- its
        `[^)]*` stops at the inner ")", so the old code removed only
        "(a total of (x)" and the comma that aside was protecting became a
        top-level one, splitting the token in two.
        """
        parts = designline._split_parts(
            "Base 5, +1 Size (a total of (x) +4 Size, including the +3), +1 Touch"
        )
        self.assertEqual([raw for raw, _ in parts], [
            "Base 5",
            "+1 Size (a total of (x) +4 Size, including the +3)",
            "+1 Touch",
        ])
        # The old code split this into "+1 Size  +4 Size" and a second bogus
        # part "including the +3)".
        self.assertEqual(parts[1][1], "+1 Size  +4 Size, including the +3)")

    def test_a_nested_aside_still_blocks_its_spell(self):
        # Keeping the aside whole does not make it parseable — it makes the
        # blocked token honest about what it contains.
        with self.assertRaises(designline.UnknownToken):
            designline.parse_design(
                "(Base 5, +1 Size (a total of (x) +4 Size, including the +3), +1 Touch)"
            )


class ElaborateEffectTest(unittest.TestCase):
    def test_each_known_wording_becomes_an_elaborate_token(self):
        for text, magnitude in [
            ("(Base 3, +1 Touch, +1 fancy effect)", 1),
            ("(Base 3, +1 Touch, +2 fancy effect)", 2),
            ("(Base 4, +1 Eye, +1 complex effect)", 1),
            ("(Base 25, +3 Moon, +1 for special effect)", 1),
            ("(Base 5, +1 Touch, +1 additional effect)", 1),
            ("(Base 10, +1 Touch, +3 elaborate design)", 3),
        ]:
            with self.subTest(text=text):
                tokens = [t for t in designline.parse_design(text).tokens
                          if t.kind == "elaborate"]
                self.assertEqual(len(tokens), 1)
                self.assertEqual(tokens[0].magnitude, magnitude)


class AdjustmentTest(unittest.TestCase):
    def test_an_allow_listed_token_becomes_an_adjustment(self):
        design = designline.parse_design(
            "(Base 25, +1 Touch, -1 because the old limb is needed)"
        )
        adj = [t for t in design.tokens if t.kind == "adjustment"]
        self.assertEqual(len(adj), 1)
        self.assertEqual(adj[0].magnitude, -1)
        self.assertEqual(adj[0].note, "because the old limb is needed")

    def test_the_note_keeps_text_that_parenthetical_stripping_would_remove(self):
        design = designline.parse_design(
            "(Base 2, +1 Touch, +2 Special (based on Concentration))"
        )
        adj = [t for t in design.tokens if t.kind == "adjustment"]
        self.assertEqual(adj[0].note, "Special (based on Concentration)")

    def test_a_special_token_matches_on_its_bracket_not_the_bare_word(self):
        """"Special" alone would be a partial catch-all.

        The word carries none of the mechanism; the bracket carries all of it,
        and the corpus hides two different mechanisms behind the same word --
        "(based on Concentration)" is a nonstandard Duration, "(equivalent to
        Boundary)" a nonstandard Target. Matching the bare label would absorb
        any "+N Special (<anything>)", including a future rulebook's third
        mechanism, silently. The spec's table lists these tokens with their
        brackets and requires them "matched exactly".
        """
        with self.assertRaises(designline.UnknownToken):
            designline.parse_design("(Base 2, +1 Touch, +2 Special (invented mechanism))")
        # A bare "+2 Special" with no bracket at all is equally unlisted.
        with self.assertRaises(designline.UnknownToken):
            designline.parse_design("(Base 2, +1 Touch, +2 Special)")

    def test_an_unlisted_token_still_raises(self):
        # The allow-list is closed on purpose: absorbing unknown tokens would
        # import real mechanisms as free text, with a correct level and wrong
        # modelling. See the spec's "an allow-list, never a catch-all".
        with self.assertRaises(designline.UnknownToken):
            designline.parse_design("(Base 4, +2 for up to +15 damage)")
        with self.assertRaises(designline.UnknownToken):
            designline.parse_design("(Base 5, +2 metal/gems)")


class VocabularyCoverageTest(unittest.TestCase):
    def test_every_de_design_line_either_parses_or_names_its_blocker(self):
        from scripts.spell_import import blocks, sources
        lines = sources.read_lines(sources.resolve_book(sources.DE_TITLE))
        parsed, _ = blocks.parse_de(lines)

        unknown = []
        for block in parsed:
            if block.design_line is None:
                continue
            try:
                designline.parse_design(block.design_line)
            except designline.UnknownToken as error:
                unknown.append((block.name, str(error)))

        # Blocked spells are expected to fail here — that is the mechanism.
        # What must not happen is a silent success on a token we do not model.
        self.assertLess(len(unknown), 90,
                        msg=f"far more unparsed than the audit's 74 blocked: {unknown[:10]}")
