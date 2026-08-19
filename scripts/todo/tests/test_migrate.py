import unittest
from scripts.todo.migrate import split, add_sub_ids

SAMPLE = """# Eruditus Todo List

## C. Not on the Critical Path

### 4. Conditional Wards
- [ ] Add a ward type field

### 7. Spell Export/Backup Validation
- [ ] Validate imported spells
- [x] Already done

### 59. The Level Should Compute Live
Redirect only — see `## Completed ✅`.

## Completed ✅

### 4. Resolve Out-of-Scope Base Effects
The archived predecessor of an id that is still open.

### 59. The Spell Level Computes Live
The real closed body, which must survive.

### 65. HoH:MC Spell Extraction
Closed, with a binding constraint inside.

### 73. Deferred Minor Findings
- [ ] Something still open

### Base Effect Extraction
Unnumbered, but real closed-work summary.
""".split("\n")


class AddSubIdsTest(unittest.TestCase):
    def test_numbers_bullets_in_source_order_from_one(self):
        out = add_sub_ids(["- [ ] first", "- [x] second", "- [ ] third"], "38")
        self.assertEqual(out, [
            "- [ ] **38.1** first",
            "- [x] **38.2** second",
            "- [ ] **38.3** third",
        ])

    def test_a_ticked_bullet_still_consumes_its_number(self):
        # so ticking one never renumbers a sibling
        out = add_sub_ids(["- [x] done", "- [ ] open"], "9")
        self.assertTrue(out[1].startswith("- [ ] **9.2**"))

    def test_indented_continuation_lines_are_untouched(self):
        out = add_sub_ids(["- [ ] first", "      continued here"], "7")
        self.assertEqual(out[1], "      continued here")

    def test_non_checkbox_bullets_are_untouched(self):
        out = add_sub_ids(["- **See also:** item 65"], "72")
        self.assertEqual(out, ["- **See also:** item 65"])


SAMPLE_IDS = frozenset({"4", "7", "59", "65", "73"})


class SplitTest(unittest.TestCase):
    def setUp(self):
        self.out = split(SAMPLE, SAMPLE_IDS)

    def test_a_file_the_mapping_does_not_match_is_refused(self):
        with self.assertRaises(ValueError) as caught:
            split(SAMPLE, SAMPLE_IDS | {"999"})
        self.assertIn("999", str(caught.exception))

    def test_open_items_land_in_their_theme_file(self):
        self.assertIn("### 7. Spell Export/Backup Validation",
                      self.out["themes/app.md"])

    def test_closed_items_land_in_the_archive(self):
        self.assertIn("### 65. HoH:MC Spell Extraction", self.out["ARCHIVE.md"])

    def test_a_misfiled_item_goes_to_its_theme_not_the_archive(self):
        self.assertIn("### 73. Deferred Minor Findings",
                      self.out["themes/importer.md"])
        self.assertNotIn("### 73.", self.out["ARCHIVE.md"])

    def test_a_tombstone_stub_is_dropped_but_its_real_item_survives(self):
        # 59 appears twice: a redirect stub in a band section, and the real
        # closed item under Completed. Filtering on bare id destroys both.
        joined = "".join(self.out.values())
        self.assertNotIn("Redirect only", joined)
        self.assertIn("The real closed body, which must survive.",
                      self.out["ARCHIVE.md"])

    def test_an_id_with_an_open_and_an_archived_body_gets_one_row(self):
        # item 4's archived predecessor is history, not a second home, so it
        # must not claim its own index row.
        index = self.out["todo.md"]
        self.assertEqual(index.count("| 4 |"), 1)
        self.assertIn("| 4 |  | open", index)
        self.assertIn("The archived predecessor", self.out["ARCHIVE.md"])

    def test_the_index_lists_every_surviving_item_once(self):
        index = self.out["todo.md"]
        for item_id in ("7", "65", "73"):
            self.assertEqual(index.count(f"| {item_id} "), 1)

    def test_the_index_records_sub_bullet_counts(self):
        self.assertIn("open 1/2", self.out["todo.md"])

    def test_an_unnumbered_block_still_reaches_the_archive(self):
        self.assertIn("### Base Effect Extraction", self.out["ARCHIVE.md"])

    def test_bodies_are_carried_verbatim_apart_from_sub_ids(self):
        self.assertIn("Closed, with a binding constraint inside.",
                      self.out["ARCHIVE.md"])


if __name__ == "__main__":
    unittest.main()
