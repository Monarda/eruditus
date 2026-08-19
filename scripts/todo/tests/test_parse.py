import unittest
from scripts.todo.parse import parse_items, section_of

SAMPLE = """# Title

## C. Not on the Critical Path

### 7. Spell Export/Backup Validation
- [ ] Validate imported spells
- [x] Something already done
- [ ] A third thing

### 4b. Intensity/Damage Modifiers
Prose only, no bullets.

## Completed

### 35 / 37. Open Guideline Slots — DONE
Two ids in one heading; 35 owns this body.

### 65. HoH:MC Spell Extraction
- **Not a checkbox bullet.**

### Base Effect Extraction
Unnumbered summary, no id at all.
""".split("\n")


class ParseItemsTest(unittest.TestCase):
    def test_finds_every_item_including_letter_suffixed_ids(self):
        self.assertEqual([i.id for i in parse_items(SAMPLE)],
                         ["7", "4b", "35", "65"])

    def test_a_compound_heading_is_owned_by_its_first_id(self):
        item = [i for i in parse_items(SAMPLE) if i.id == "35"][0]
        self.assertEqual(item.title, "Open Guideline Slots — DONE")

    def test_the_raw_heading_is_kept_verbatim(self):
        # migration re-emits this line rather than rebuilding it, so the
        # "/ 37" cross-link survives the move to the archive
        item = [i for i in parse_items(SAMPLE) if i.id == "35"][0]
        self.assertEqual(item.heading, "### 35 / 37. Open Guideline Slots — DONE")

    def test_an_unnumbered_heading_is_not_an_item(self):
        self.assertNotIn("Base Effect Extraction",
                         [i.title for i in parse_items(SAMPLE)])

    def test_an_unnumbered_heading_still_ends_the_previous_body(self):
        # otherwise item 65 swallows it, and the migrator emits it twice:
        # once inside 65's body and once as an unclaimed block.
        item = [i for i in parse_items(SAMPLE) if i.id == "65"][0]
        self.assertNotIn("Unnumbered summary, no id at all.", item.body)

    def test_counts_open_and_done_bullets_separately(self):
        item = parse_items(SAMPLE)[0]
        self.assertEqual((item.open_bullets, item.done_bullets), (2, 1))
        self.assertEqual(item.total_bullets, 3)

    def test_a_prose_item_has_no_bullets(self):
        self.assertEqual(parse_items(SAMPLE)[1].total_bullets, 0)

    def test_a_non_checkbox_bullet_is_not_counted(self):
        self.assertEqual(parse_items(SAMPLE)[3].total_bullets, 0)

    def test_body_stops_at_the_next_section_not_the_next_item(self):
        # 4b is the last item of section C; its body must not swallow
        # the "## Completed" heading that follows it.
        body = parse_items(SAMPLE)[1].body
        self.assertIn("Prose only, no bullets.", body)
        self.assertNotIn("## Completed", body)

    def test_section_of_reports_the_enclosing_section(self):
        items = parse_items(SAMPLE)
        self.assertEqual(section_of(SAMPLE, items[0].start), "C. Not on the Critical Path")
        self.assertEqual(section_of(SAMPLE, items[3].start), "Completed")

    def test_titles_drop_the_id_prefix(self):
        self.assertEqual(parse_items(SAMPLE)[0].title, "Spell Export/Backup Validation")


if __name__ == "__main__":
    unittest.main()
