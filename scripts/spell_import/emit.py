"""Build one assets/data/spell_library.json entry from a parsed spell block."""
from . import catalog as catalog_module
from . import designline

# The existing 36 entries all carry this fixed timestamp. Generated entries
# must too: a wall-clock value would make every run produce a diff, defeating
# the regeneration assertion.
FIXED_TIMESTAMP = "2026-01-01T00:00:00.000"

CORE_BOOK_ID = "arm5-core"


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

    if block.stat.is_ritual:
        spell["ritualDeclaration"] = "lastingCreation"

    return spell


def _selected_modifiers(
    design: designline.Design, block, catalog: catalog_module.Catalog
) -> dict[str, list[str]]:
    """Map design-line modifier tokens onto modifiers.json option ids.

    Only "size" is mapped — it is the one modifier-kind token whose value
    translates mechanically (magnitude N -> the Form's `size-<form>-N`
    option, verified to exist for every case actually in the corpus except
    Mentem, which has no size modifier at all, and three spells whose
    printed magnitude (5) exceeds every size modifier's top option (4)).
    Everything else (unnatural, stone/metal material, Imaginem complexity
    factors) is a smaller, less mechanical set with no verified mapping yet
    — raising here, not guessing, is what routes those spells to `blocked`
    in extract_spells.py rather than importing them with a silently wrong
    level. See .superpowers/todo.md item 27.
    """
    selected: dict[str, list[str]] = {}
    for token in design.tokens:
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
