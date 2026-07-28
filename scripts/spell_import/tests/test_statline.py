import unittest

from scripts.spell_import import statline


class DetectTest(unittest.TestCase):
    def test_plain_line(self):
        self.assertTrue(statline.is_statline("R: Touch, D: Mom, T: Ind"))

    def test_bold_markup_between_fields(self):
        # Against the Dark writes every stat line this way. A pattern anchored
        # at the start of the line rejects the whole book.
        self.assertTrue(statline.is_statline("**R:** Voice, **D:** Diameter, **T:** Part"))

    def test_blockquote_sidebar(self):
        self.assertTrue(statline.is_statline("> R: Per, D: Diam, T: Flavor"))

    def test_period_separators(self):
        self.assertTrue(statline.is_statline("R: Personal. D: Conc. T: Touch"))

    def test_description_run_onto_the_line(self):
        self.assertTrue(
            statline.is_statline("R: Touch, D: Mom, T: Boundary, Ritual Causes a roll")
        )

    def test_prose_is_not_a_statline(self):
        self.assertFalse(statline.is_statline("The caster must touch the target."))

    def test_damaged_lines_are_detected_not_parsed(self):
        for line in [
            "R: Arc, D: Conc, R: Ind",        # T mistyped as R
            "R: Voice, D Mom, T: Group",      # colon dropped after D
            "R: Touch, T: Ring, D: Circle",   # D and T transposed
        ]:
            self.assertFalse(statline.is_statline(line), line)
            self.assertTrue(statline.is_damaged_statline(line), line)


class ParseTest(unittest.TestCase):
    def test_parses_the_three_fields(self):
        parsed = statline.parse_statline("R: Touch, D: Sun, T: Ind")
        self.assertEqual(parsed.range_name, "Touch")
        self.assertEqual(parsed.duration_name, "Sun")
        self.assertEqual(parsed.target_name, "Ind")
        self.assertFalse(parsed.is_ritual)
        self.assertEqual(parsed.requisite_arts, [])

    def test_detects_the_ritual_flag(self):
        parsed = statline.parse_statline("R: Touch, D: Mom, T: Ind, Ritual")
        self.assertTrue(parsed.is_ritual)
        self.assertEqual(parsed.target_name, "Ind")

    def test_reads_requisites(self):
        parsed = statline.parse_statline("R: Touch, D: Mom, T: Part, Ritual Req: Vim, Corpus")
        self.assertTrue(parsed.is_ritual)
        self.assertEqual(parsed.requisite_arts, ["Vim", "Corpus"])

    def test_strips_trailing_br_tags(self):
        parsed = statline.parse_statline("R: Touch, D: Moon, T: Ind<br>")
        self.assertEqual(parsed.target_name, "Ind")

    def test_damaged_line_raises(self):
        with self.assertRaises(ValueError):
            statline.parse_statline("R: Touch, T: Ring, D: Circle")
