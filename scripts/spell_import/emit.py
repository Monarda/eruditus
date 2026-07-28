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
        "selectedModifiers": {},
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
