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
        # "+1 fancy effect" is an ad-hoc per-spell magnitude (todo item 24).
        # It must fail loudly so the spell is reported blocked, not imported
        # with a silently dropped magnitude.
        with self.assertRaises(designline.UnknownToken):
            designline.parse_design("(Base 10, +1 Touch, +1 fancy effect)")


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
