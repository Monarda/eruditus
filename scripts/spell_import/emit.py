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

# Design-line modifier labels that resolve to one named modifiers.json option,
# keyed by (Technique, Form, label) because the Imaginem complexity modifiers
# are Technique/Form-scoped and the same label can mean different options under
# different Arts. The magnitude is checked against the catalog by
# `_option_exists`, so a printed magnitude the option does not carry blocks the
# spell instead of importing it at the wrong level.
#
# Every entry here is a label whose mapping designline.MODIFIER_LABELS's comment
# records as confirmed against the spell(s) that print it, at the magnitude the
# catalog option carries. That comment is the authority for the mapping; this is
# the same knowledge as data. An entry is only added once its option id and
# magnitude have been checked against assets/data/modifiers.json -- see
# tests/test_emit.py's ModifierOptionTableTest, which re-checks all of them
# against the real catalog on every run.
#
# Still deliberately not a census of every modifier label the tokenizer knows.
# "metal" is absent because its mapping is ambiguous (see `_selected_modifiers`'s
# docstring). "unnatural" is now included for Creo Auram, verified against the
# rulebook's Creo Auram preamble.
#
# See .superpowers/todo.md item 27 for tracked follow-up on these and other tokens.
_MODIFIER_OPTIONS = {
    ("Creo", "Imaginem", "intricacy"): ("crim-complexity", "crim-intricate-design"),
    # "Image moves or makes noise at your direction as you concentrate",
    # magnitude 2. Both wordings occur: Phantasmal Animal prints "under",
    # Phantasm of the Human Form and Haunt of the Living Ghost print "at".
    ("Creo", "Imaginem", "move at your command"): ("crim-complexity", "crim-directed-image"),
    ("Creo", "Imaginem", "move under your command"): ("crim-complexity", "crim-directed-image"),
    # "Increasing Sensory Complexity" -- clear words instead of noise, magnitude
    # 1. Phantasm of the Talking Head.
    ("Creo", "Imaginem", "intelligible speech"): ("crim-complexity", "crim-sensory-complexity"),
    # "Destroying or dulling an image that changes, rather than a static
    # one", magnitude 1. Perdo Imaginem's preamble states the rule directly:
    # "Destroying changing images is more difficult -- add one level of
    # magnitude to spells that do so." Veil of Invisibility, Silence of the
    # Smothered Sound.
    ("Perdo", "Imaginem", "changing image"): ("peim-complexity", "peim-changing-image"),
    # "The moved image continues to match changes in the original", magnitude 1.
    # Wizard's Sidestep.
    ("Rego", "Imaginem", "moved image matches changes"): (
        "reim-complexity", "reim-moved-image-matches"
    ),
    # "Add one magnitude per additional sense beyond the guideline's default",
    # magnitude 1. Both spellings occur: Confusion of the Insane Vibrations
    # prints the plural, Image from the Wizard Torn the singular.
    ("Rego", "Imaginem", "additional senses"): ("reim-complexity", "reim-additional-senses"),
    ("Rego", "Imaginem", "additional sense"): ("reim-complexity", "reim-additional-senses"),
    # "Moving an image that changes, rather than a static one", magnitude 1.
    # Image from the Wizard Torn prints this as "moving image".
    ("Rego", "Imaginem", "moving image"): ("reim-complexity", "reim-changing-image"),
    # Same option, this time reached via the literal "changing image" label
    # (rather than "moving image" above). Rego Imaginem's preamble: "it is
    # slightly harder to affect changing images. Add one level of magnitude
    # to spells that do so." The Captive Voice, Wizard's Sidestep (which also
    # prints "moved image matches changes", wired separately above).
    ("Rego", "Imaginem", "changing image"): ("reim-complexity", "reim-changing-image"),
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
    }

    description = _description(block)
    if description:
        spell["description"] = description

    if block.printed_level is None:
        # A spell without a printed level should never reach emission --
        # blocks.SpellBlock.printed_level is None only for "#### GENERAL"
        # entries, and extract_spells.py routes those to `blocked` before
        # build_spell is ever called. Raising here, rather than emitting a
        # null or omitting the key, turns a routing bug into a loud failure
        # instead of a silently un-checkable spell.
        raise ValueError(f"{block.name}: no printed level to emit")
    spell["printedLevel"] = block.printed_level

    spell["citations"] = [{"bookId": CORE_BOOK_ID}]

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


def build_template(
    block,
    base_effect_id: str,
    catalog: catalog_module.Catalog,
    design: designline.Design,
) -> dict:
    """Build a `SpellTemplate.fromMap`-shaped entry for a General spell.

    Mirrors `build_spell`, minus `printedLevel` and the level arithmetic that
    field requires: a General block's `printed_level` is always `None`
    (that's what routes it here instead of to `build_spell`), so this
    function never reads it.
    """
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

    # The `lib-` slug is the ledger key (resolutions.json, KNOWN_UNRESOLVABLE);
    # the template's own id is that same slug with `tpl-` in place of `lib-`.
    # Derived from slug_id rather than a second slug function.
    slug = catalog_module.slug_id(block.technique, block.form, block.name)
    template_id = "tpl-" + slug.removeprefix("lib-")

    template = {
        "id": template_id,
        "name": block.name,
        "requisites": requisites,
        "source": "published",
        "selectedModifiers": _selected_modifiers(design, block, catalog),
        "baseEffectId": base_effect_id,
        "rangeId": range_id,
        "durationId": duration_id,
        "targetId": target_id,
        "summary": _template_summary(block),
    }

    description = _description(block)
    if description:
        template["description"] = description

    template["citations"] = [{"bookId": CORE_BOOK_ID}]

    adjustments = [
        {"magnitude": token.magnitude, "note": token.note}
        for token in design.tokens
        if token.kind == "adjustment"
    ]
    if adjustments:
        template["adjustments"] = adjustments

    if block.stat.is_ritual:
        template["ritualDeclaration"] = "lastingCreation"

    return template


def _selected_modifiers(
    design: designline.Design, block, catalog: catalog_module.Catalog
) -> dict[str, list[str]]:
    """Map design-line modifier tokens onto modifiers.json option ids.

    "size" is the one modifier-kind token whose value translates
    mechanically (magnitude N -> the Form's `size-<form>-N` option, verified
    to exist for every case actually in the corpus except Mentem, which has
    no size modifier at all, and three spells whose printed magnitude (5)
    exceeds every size modifier's top option (4)). Everything else must be
    named explicitly in `_MODIFIER_OPTIONS`.

    Everything else raises here rather than guessing, which is what routes
    those spells to `blocked` in extract_spells.py instead of importing
    them with a silently wrong level. But "no verified mapping" is not
    equally true of every one of them:

    - The Imaginem complexity-factor labels ("move at/under your command",
      "intelligible speech", "moved image matches changes", "additional
      sense(s)", "moving image", "changing image") are now in
      `_MODIFIER_OPTIONS`: their per-spell mapping was already recorded as
      prose in designline.MODIFIER_LABELS's comment, and each id and
      magnitude was checked against the catalog before being wired. That
      unblocked ten spells, the last four of them on "changing image" --
      Veil of Invisibility and Silence of the Smothered Sound (Perdo
      Imaginem), The Captive Voice and Wizard's Sidestep (Rego Imaginem).
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
            if "elaborate-effect" in selected:
                # elaborate-effect is selectionMode "single". Two elaborate
                # tokens on one design line would put two option ids under it,
                # producing an asset the app's own validateSpellDraft rejects.
                # No corpus spell does this today and nothing else in the
                # pipeline would notice if one appeared.
                raise designline.UnknownToken(
                    f"{block.name}: two elaborate tokens, but 'elaborate-effect' "
                    f"is a single-selection modifier"
                )
            selected["elaborate-effect"] = [option_id]
            continue
        if token.kind != "modifier":
            continue

        # Creo Auram "unnatural" modifiers: magnitude determines which option
        if (
            block.technique == "Creo"
            and block.form == "Auram"
            and token.label.lower() in ("unnatural", "slightly unnatural", "very unnatural", "wholly divorced")
        ):
            modifier_id = "creo-auram-unnatural"
            unnatural_options = {
                1: "creo-auram-unnatural-slight",
                2: "creo-auram-unnatural-very",
                4: "creo-auram-unnatural-divorced",
            }
            option_id = unnatural_options.get(token.magnitude)
            if option_id is None:
                raise designline.UnknownToken(
                    f"{block.name}: creo-auram-unnatural has no option at magnitude "
                    f"{token.magnitude}"
                )
            if not _option_exists(catalog, modifier_id, option_id, token.magnitude):
                raise designline.UnknownToken(
                    f"{block.name}: modifiers.json has no {modifier_id!r} option "
                    f"{option_id!r} at magnitude {token.magnitude}"
                )
            selected.setdefault(modifier_id, []).append(option_id)
            continue

        mapped = _MODIFIER_OPTIONS.get((block.technique, block.form, token.label))
        if mapped is not None:
            modifier_id, option_id = mapped
            if not _option_exists(catalog, modifier_id, option_id, token.magnitude):
                raise designline.UnknownToken(
                    f"{block.name}: modifiers.json has no {modifier_id!r} option "
                    f"{option_id!r} at magnitude {token.magnitude}"
                )
            selected.setdefault(modifier_id, []).append(option_id)
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


def _truncated_prose(block) -> str:
    """Whitespace-collapsed prose, capped at 400 characters."""
    prose = " ".join(block.prose.split())
    if len(prose) > 400:
        prose = prose[:397].rstrip() + "..."
    return prose


def _summary(block) -> str:
    """Prose plus the printed level, kept as a trailing "Level N." phrase.

    The suffix is now vestigial: no test parses it back out. Both readers
    that used to -- asset_data_loader_test.dart and, as the oracle for the
    import harness's assertion 1, published_spell_import_test.dart -- were
    moved onto the `printedLevel` field build_spell also emits. It is kept
    here only because dropping it would rewrite all 263 summaries in
    assets/data/spell_library.json, which .superpowers/todo.md item 31 owns
    along with the rest of the summary rework.
    """
    return f"{_truncated_prose(block)} Level {block.printed_level}."


def _template_summary(block) -> str:
    """`_summary` without the "Level N." suffix.

    A General block's `printed_level` is always `None` -- naively reusing
    `_summary` here would emit the literal string "Level None." into the
    template asset.
    """
    return _truncated_prose(block)


def _description(block) -> str:
    """The full, untruncated verbatim rulebook prose, whitespace-collapsed.

    Unlike _summary, this carries no truncation and no "Level N." suffix --
    that suffix belongs to the paraphrase field alone. Empty prose yields an
    empty string here, and build_spell omits the key entirely in that case,
    the same way it omits "adjustments" when there are none.
    """
    return " ".join(block.prose.split())
