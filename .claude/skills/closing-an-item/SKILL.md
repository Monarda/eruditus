---
name: closing-an-item
description: Use when an item in .superpowers/ closes, or when a merge lands that closed one - extracts still-binding constraints into DECISIONS.md before the body is archived
---

# Closing an Item

Lifecycle rule 3: **constraints come out before the body goes in.** An item's
body is about to stop being read. Anything in it that still binds must move to
`DECISIONS.md` first, or it is lost.

## Steps

1. **Identify what closed.** Name the item numbers the merge closed. A merge may
   close several items, or none — "none" is a valid answer and ends this
   procedure after step 5.
2. **Re-read each closing item's body in full**, in its theme file.
3. **Extract every still-binding statement into `DECISIONS.md`**, topic-headed,
   citing the item. A statement qualifies only if a future session could violate
   it by accident: a naming rule with its reason, an invariant later code must
   preserve, a rejected approach and why, a gotcha that bit someone. Not: what
   the work was, which commits did it, counts, dates, test names.
4. **Move the body verbatim to `ARCHIVE.md`** and flip its index row to
   `closed <MM-DD>`, home `ARCHIVE.md`, `Kind` `—`.
5. **Record the merge as reviewed:**

   ```bash
   git rev-list --merges -1 HEAD > .superpowers/.last-reviewed-merge
   ```

6. **Verify:** `uv run --no-project python -m scripts.todo.check` must print
   `0 problem(s)`.
7. **Commit** `.superpowers/` together, so the extraction and the archival land
   in one commit.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "The body is in git, nothing is lost" | Git is not read at session start. Unextracted means unread. |
| "It's all obvious from the code" | If it were, the item would not have needed a reason written down. |
| "This merge closed nothing, skip the whole thing" | Still run step 5, or the gate asks again tomorrow. |
| "I'll extract it when someone needs it" | That is exactly how the 1007-line Completed section happened. |
