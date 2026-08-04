"""Build one assets/data/spell_library.json entry from a parsed spell block."""
from . import catalog as catalog_module
from . import designline

# The existing 36 entries all carry this fixed timestamp. Generated entries
# must too: a wall-clock value would make every run produce a diff, defeating
# the regeneration assertion.
FIXED_TIMESTAMP = "2026-01-01T00:00:00.000"

CORE_BOOK_ID = "arm5-core"

# designline's `elaborate` tokens carry the printed magnitude; this maps it to
# the modifiers.json option that already encodes that magnitude. A magnitude
# outside this map raises rather than defaulting, so an unexpected value
# blocks its spell instead of importing one with the wrong option selected.
_ELABORATE_OPTIONS = {
    0: "elaborate-effect-none",
    1: "elaborate-effect-minor",
    2: "elaborate-effect-considerable",
    3: "elaborate-effect-extensive",
}


def build_spell(
    block,
    base_effect_id: str,
    catalog: catalog_module.Catalog,
    design: designline.Design,
) -> dict:
    range_id = catalog.parameter_id("Range", _parameter_name(design, "range", block))
    duration_id = catalog.parameter_id("Duration", _parameter_name(design, "duration", block))
    target_id = catalog.parameter_id("Target", _parameter_name(design, "target", block))

    requisites = [
        {"art": token.label, "kind": "adding" if token.magnitude else "free"}
        for token in design.tokens
        if token.kind == "requisite" and token.label != "free"
    ]
    for art in block.stat.requisite_arts:
        if not any(r["art"] == art for r in requisites):
            requisites.append({"art": art, "kind": "free"})

    spell = {
        "id": catalog_module.slug_id(block.technique, block.form, block.name),
        "name": block.name,
        "requisites": requisites,
        "source": "published",
        "createdAt": FIXED_TIMESTAMP,
        "updatedAt": FIXED_TIMESTAMP,
        "selectedModifiers": _selected_modifiers(design, block, catalog),
        "baseEffectId": base_effect_id,
        "rangeId": range_id,
        "durationId": duration_id,
        "targetId": target_id,
        "summary": _summary(block),
        "citations": [{"bookId": CORE_BOOK_ID}],
    }

    adjustments = [
        {"magnitude": token.magnitude, "note": token.note}
        for token in design.tokens
        if token.kind == "adjustment"
    ]
    if adjustments:
        spell["adjustments"] = adjustments

    if block.stat.is_ritual:
        spell["ritualDeclaration"] = "lastingCreation"

    return spell


def _selected_modifiers(
    design: designline.Design, block, catalog: catalog_module.Catalog
) -> dict[str, list[str]]:
    """Map design-line modifier tokens onto modifiers.json option ids.

    Only "size" is wired up here — it is the one modifier-kind token whose
    value translates mechanically (magnitude N -> the Form's
    `size-<form>-N` option, verified to exist for every case actually in
    the corpus except Mentem, which has no size modifier at all, and three
    spells whose printed magnitude (5) exceeds every size modifier's top
    option (4)).

    Everything else raises here rather than guessing, which is what routes
    those spells to `blocked` in extract_spells.py instead of importing
    them with a silently wrong level. But "no verified mapping" is not
    equally true of every one of them:

    - The Imaginem complexity-factor labels ("move at/under your command",
      "intelligible speech", "moved image matches changes", "additional
      sense(s)", "moving image") DO already have a verified, per-spell
      mapping — it lives as prose in designline.MODIFIER_LABELS's comment,
      confirmed against every spell that uses each label. It just isn't
      wired into this function as data yet. Turning that comment into a
      real `label -> (modifier_id, option_id)` table here would unblock
      those ~10 spells; the mapping itself is not the missing piece.
    - "unnatural" genuinely has no mapping for most of its spells:
      `creo-auram-unnatural` only covers Creo Auram, and most "unnatural"
      tokens are on Muto/Rego Auram spells it doesn't scope to.
    - "metal" is genuinely ambiguous: the design line's "+2 metal" doesn't
      say whether that means `muto-terram-material`'s base-metal or
      precious-metal option (different ids, and here the same magnitude).

    See .superpowers/todo.md item 27 for the tracked follow-up.
    """
    selected: dict[str, list[str]] = {}
    for token in design.tokens:
        if token.kind == "elaborate":
            option_id = _ELABORATE_OPTIONS.get(token.magnitude)
            if option_id is None:
                raise designline.UnknownToken(
                    f"{block.name}: no elaborate-effect option at magnitude "
                    f"{token.magnitude}"
                )
            if not _option_exists(catalog, "elaborate-effect", option_id, token.magnitude):
                raise designline.UnknownToken(
                    f"{block.name}: modifiers.json has no 'elaborate-effect' option "
                    f"{option_id!r} at magnitude {token.magnitude}"
                )
            selected.setdefault("elaborate-effect", []).append(option_id)
            continue
        if token.kind != "modifier":
            continue
        if token.label.lower() != "size":
            raise designline.UnknownToken(
                f"{block.name}: no modifiers.json mapping for modifier token {token.label!r}"
            )
        modifier_id = f"size-{block.form.lower()}"
        modifier = next((m for m in catalog.modifiers if m["id"] == modifier_id), None)
        if modifier is None:
            raise designline.UnknownToken(f"{block.name}: no {modifier_id!r} modifier exists")
        option = next(
            (o for o in modifier["options"] if o["magnitude"] == token.magnitude), None
        )
        if option is None:
            raise designline.UnknownToken(
                f"{block.name}: {modifier_id!r} has no option at magnitude {token.magnitude}"
            )
        selected.setdefault(modifier_id, []).append(option["id"])
    return selected


def _option_exists(
    catalog: catalog_module.Catalog, modifier_id: str, option_id: str, magnitude: int
) -> bool:
    """Is `option_id` really a `modifier_id` option carrying `magnitude`?

    _ELABORATE_OPTIONS is a hand-written id table, so a typo in it — or a
    renamed option in modifiers.json — would otherwise put a dangling id
    into the asset with no Python test to catch it. Checking the magnitude
    too means the table cannot drift out of step with the catalog silently.
    """
    modifier = next((m for m in catalog.modifiers if m["id"] == modifier_id), None)
    if modifier is None:
        return False
    return any(
        o["id"] == option_id and o["magnitude"] == magnitude
        for o in modifier["options"]
    )


def _parameter_name(design: designline.Design, slot: str, block) -> str:
    """Resolve a slot from the stat line, expanded to its full catalog name."""
    raw = {
        "range": block.stat.range_name,
        "duration": block.stat.duration_name,
        "target": block.stat.target_name,
    }[slot]
    if raw not in designline.PARAMETER_LABELS:
        raise designline.UnknownToken(f"{block.name}: unknown {slot} {raw!r}")
    return designline.PARAMETER_LABELS[raw]


def _summary(block) -> str:
    """Prose plus the printed level, which the level-equality test reads back.

    The existing 36 entries end their summary with "Level N." and
    asset_data_loader_test.dart parses exactly that. Keep the shape.
    """
    prose = " ".join(block.prose.split())
    if len(prose) > 400:
        prose = prose[:397].rstrip() + "..."
    return f"{prose} Level {block.printed_level}."
