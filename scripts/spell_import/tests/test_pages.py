import unittest

from scripts.spell_import import pages


class SlugifyTest(unittest.TestCase):
    def test_lowercases_and_hyphenates(self):
        self.assertEqual(pages.slugify("## Spell Guidelines"), "spell-guidelines")

    def test_strips_punctuation_but_keeps_hyphens(self):
        self.assertEqual(pages.slugify("### Bjornaer -- The Heartbeast"),
                         "bjornaer----the-heartbeast")

    def test_ignores_leading_hashes_and_whitespace(self):
        self.assertEqual(pages.slugify("   #   Creo Animal  "), "creo-animal")


class BuildIndexTest(unittest.TestCase):
    def test_duplicate_headings_get_numeric_suffixes_in_document_order(self):
        lines = ["# Alpha", "text", "# Alpha", "text", "# Alpha"]
        index = pages.build_index(lines)
        self.assertEqual(
            sorted(index.heading_lines), [1, 3, 5],
            "every duplicate heading must keep its own line, not collapse")
        self.assertIn("alpha", index.heading_slugs)
        self.assertIn("alpha-1", index.heading_slugs)
        self.assertIn("alpha-2", index.heading_slugs)

    def test_a_page_range_takes_its_first_page(self):
        lines = ["# Ability Types", "| Entry | [158-159](#ability-types) |"]
        index = pages.build_index(lines)
        self.assertEqual(index.anchor_pages["ability-types"], 158)

    def test_an_anchor_with_no_matching_heading_is_dropped_not_guessed(self):
        lines = ["# Real", "| x | [12](#not-a-heading) |"]
        index = pages.build_index(lines)
        self.assertNotIn("not-a-heading", index.anchor_pages)

    def test_a_heading_cited_with_two_different_pages_is_not_a_calibration_point(self):
        """Two index rows disagreeing on an anchor's page is the same kind of
        thin evidence the two guards already refuse to guess from."""
        lines = ["# Widget", "| a | [10](#widget) |", "| b | [11](#widget) |"]
        index = pages.build_index(lines)
        self.assertNotIn(1, dict(index.line_pages))
        self.assertIn("widget", index.anchor_pages, "still recorded, just not used to calibrate")

    def test_a_heading_cited_consistently_is_still_a_calibration_point(self):
        lines = ["# Widget", "| a | [10](#widget) |", "| b | [10](#widget) |"]
        index = pages.build_index(lines)
        self.assertEqual(dict(index.line_pages)[1], 10)


class PageForLineTest(unittest.TestCase):
    def _index(self):
        # Heading at line 1 = page 10; heading at line 100 = page 20.
        lines = ["# A"] + ["body"] * 98 + ["# B", "| x | [10](#a) | [20](#b) |"]
        return pages.build_index(lines)

    def test_returns_the_nearest_preceding_anchor(self):
        self.assertEqual(self._index().page_for_line(50 - 30), 10)

    def test_refuses_when_the_nearest_anchor_is_too_far(self):
        index = self._index()
        self.assertIsNone(
            index.page_for_line(1 + pages.MAX_ANCHOR_DISTANCE + 1),
            "a page inferred across a large gap is a guess, not a reading")

    def test_accepts_just_inside_the_distance_guard(self):
        index = self._index()
        self.assertEqual(index.page_for_line(1 + pages.MAX_ANCHOR_DISTANCE - 1), 10)

    def test_returns_none_before_the_first_anchor(self):
        self.assertIsNone(self._index().page_for_line(0))


class RealRulebookTest(unittest.TestCase):
    """Measured facts about the pinned rulebook. If one of these changes, the
    source moved -- check `source.lock` before changing the number."""

    @classmethod
    def setUpClass(cls):
        cls.index = pages.load_index()

    def test_resolves_about_sixteen_hundred_calibration_points(self):
        self.assertGreater(len(self.index.line_pages), 1500)

    def test_the_spells_index_covers_every_published_spell(self):
        self.assertEqual(len(self.index.spell_index_pages), 360)

    def test_pages_never_go_backwards_as_lines_advance(self):
        violations = self.index.monotonicity_violations()
        self.assertEqual(
            violations, [],
            "an anchor read out of its section poisons every line after it "
            "until the next anchor -- see the spec, section 3")

    def test_reference_guide_anchors_are_not_calibration_points(self):
        """The Reference Guide reproduces body content and cites the body's
        pages, so an anchor there points backwards. Using it as a calibration
        point would give every following line a page from a different chapter."""
        start, end = pages.REFERENCE_GUIDE_RANGE
        inside = [ln for ln, _ in self.index.line_pages if start <= ln <= end]
        self.assertEqual(inside, [])

    def test_spell_guidelines_index_headings_are_not_calibration_points(self):
        """The Spell Guidelines Index locates a section, not a guideline (see
        the design spec) -- its citation is a page ahead of the section's own
        first worked example, so none of its 50 rows are used to calibrate."""
        start, end = pages._SPELL_GUIDELINES_INDEX_RANGE
        calibrated = dict(self.index.line_pages)
        self.assertNotIn(13006, calibrated, "Rego Aquam Guidelines")
        self.assertNotIn(15105, calibrated, "Perdo Mentem Guidelines")
        self.assertGreater(end, start, "sanity: the range is non-empty")

    def test_isolated_uncorroborated_citations_are_not_calibration_points(self):
        """A handful of citations disagree with pages read independently on
        both sides of them, with no duplicate heading or conflicting anchor
        to explain why -- see the constant's own comment for the evidence."""
        calibrated = dict(self.index.line_pages)
        for line in pages._ISOLATED_UNRELIABLE_LINES:
            self.assertNotIn(line, calibrated)


if __name__ == "__main__":
    unittest.main()
