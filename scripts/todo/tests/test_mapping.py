import unittest
from scripts.todo.mapping import THEMES, TOMBSTONES, MISFILED, ALL_IDS, theme_for


class MappingTest(unittest.TestCase):
    def test_every_themed_id_is_a_real_id(self):
        # THEMES maps only the OPEN items -- a closed item's home is the
        # archive, which needs no entry here.
        self.assertTrue(THEMES.keys() <= ALL_IDS,
                        f"not real ids: {sorted(THEMES.keys() - ALL_IDS)}")
        self.assertEqual(len(THEMES), 36)

    def test_tombstones_have_no_theme(self):
        for item_id in TOMBSTONES:
            self.assertNotIn(item_id, THEMES)

    def test_theme_counts_match_the_spec_appendix(self):
        counts = {}
        for theme in THEMES.values():
            counts[theme] = counts.get(theme, 0) + 1
        self.assertEqual(counts, {
            "rules-fidelity.md": 12,
            "app.md": 10,
            "model.md": 7,
            "importer.md": 5,
            "multibook.md": 2,
        })

    def test_item_73_is_recorded_as_misfiled_under_completed(self):
        self.assertEqual(MISFILED["73"], "importer.md")

    def test_theme_for_raises_on_an_unknown_id(self):
        with self.assertRaises(KeyError):
            theme_for("999")


if __name__ == "__main__":
    unittest.main()
