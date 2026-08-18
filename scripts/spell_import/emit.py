"""Build one assets/data/spell_library.json entry from a parsed spell block."""
from . import catalog as catalog_module
from . import designline

# The existing 36 entries all carry this fixed timestamp. Generated entries
# must too: a wall-clock value would make every run produce a diff, defeating
# the regeneration assertion.
FIXED_TIMESTAMP = "2026-01-01T00:00:00.000"

CORE_BOOK_ID = "arm5-core"

# Ritual-flagged spells whose own design line already carries a condition-6
# (storyguide-ruling, Core Rules line 12352 -- "too spectacular to be freely
# available") justification, rather than being a Momentary Creo spell
# creating a lasting thing (condition 5, `lastingCreation`). A closed,
# exact-name table, the same discipline as extract_spells.HAND_DERIVED and
# exceptions.EXCEPTION_SPELLS: every entry here is a citation-backed reading
# of the spell's own printed clause, not inferred from a shape or heuristic.
# See docs/superpowers/specs/2026-08-16-storyguide-ruling-ui-design.md and
# .superpowers/todo.md item 49.
STORYGUIDE_RULING_SPELLS: dict[str, str] = {
    "Curse of the Ravenous Swarm": (
        'Design line\'s trailing continuation reads "ritual because it has '
        'a really major effect" -- condition 6 verbatim, not a lasting '
        "creation (CrAn, Sun duration)."
    ),
    "Neptune's Wrath": (
        'Design line\'s trailing continuation reads "ritual for large '
        'effect" -- condition 6 verbatim, not a lasting creation (ReAq, '
        "Diameter duration)."
    ),
    "Breath of the Open Sky": (
        'Design line\'s trailing continuation reads "ritual because of '
        'spectacular effect" -- condition 6 verbatim, not a lasting '
        "creation (CrAu, Diameter duration)."
    ),
}


def _ritual_declaration(block) -> str:
    """The `RitualDeclaration` a Ritual-flagged block should carry.

    Defaults to `lastingCreation` (condition 5), the common case; a spell in
    STORYGUIDE_RULING_SPELLS overrides to `storyguideRuling` (condition 6).
    Only called when `block.stat.is_ritual` is already true.
    """
    if block.name in STORYGUIDE_RULING_SPELLS:
        return "storyguideRuling"
    return "lastingCreation"

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

# designline's `complexity` tokens carry the printed magnitude; this maps it to
# the modifiers.json option that already encodes that magnitude, the same
# discipline as _ELABORATE_OPTIONS above and for the same reason: a magnitude
# outside this map raises rather than defaulting.
_COMPLEXITY_OPTIONS = {
    0: "complexity-none",
    1: "complexity-slight",
    2: "complexity-considerable",
    3: "complexity-extensive",
    4: "complexity-intricate",
    5: "complexity-exceptional",
}

# Modifiers whose option is chosen by the design line's own magnitude rather
# than by its label -- the label names the mechanism, the magnitude names the
# rung. Both are storyguide judgement magnitudes with a degree ladder in
# modifiers.json and no printed table in the rulebook.
_MAGNITUDE_KEYED_MODIFIERS = {
    "elaborate": ("elaborate-effect", _ELABORATE_OPTIONS),
    "complexity": ("complexity", _COMPLEXITY_OPTIONS),
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
    # The still/silent-casting buyout (todo item 24's last two unmodelled
    # mechanisms). Both modifiers are globally scoped in modifiers.json
    # (technique/form both null) -- keyed here by their one corpus spell's
    # own Technique/Form anyway, the same way every other entry in this
    # table is, since nothing about the mechanism itself is Perdo/Corpus/
    # Mentem-specific.
    ("Perdo", "Corpus", "for no words"): ("no-words", "no-words-yes"),
    ("Perdo", "Mentem", "for not needing to gesture"): ("no-gestures", "no-gestures-yes"),
    # Reveals the Technique/Form of a detected magical effect -- Intellego
    # Vim-scoped, unlike the two above. Sight of the Active Magics.
    ("Intellego", "Vim", "Techniques and Forms"): (
        "invi-techniques-and-forms", "invi-techniques-and-forms-yes"
    ),
}


def _resolve_requisite_arts(token, block) -> list[str]:
    """The arts a `kind="requisite"` token belongs to.

    Usually just `[token.label]` -- designline.py already resolved it from
    the design line's own text. The exception is a bare requisite token, e.g.
    "+N requisite" or "+N necessary requisites"
    (designline._BARE_REQUISITE_LABELS), which carries an empty label because
    designline.py never sees the Req: line and so cannot know which art the
    magnitude belongs to.

    Resolving it here, against `block.stat`, is safe in exactly two shapes.
    One declared art takes the whole magnitude. Several declared arts take it
    only when the magnitude equals how many there are, which makes +1 each
    the book's own arithmetic rather than an inference -- Embrace of Boethius
    declares Req: Vim, Corpus and charges "+2 necessary requisites". Any
    other ratio raises, the same discipline as every other closed-allow-list
    decision in this pipeline: a distribution the design line does not state
    is not one this importer may guess at.
    """
    if token.label:
        return [token.label]
    arts = block.stat.requisite_arts
    if len(arts) == 1:
        return list(arts)
    if arts and token.magnitude == len(arts):
        return list(arts)
    raise designline.UnknownToken(
        f"{block.name}: a bare requisite token of magnitude {token.magnitude} "
        f"needs either exactly one Req: art or as many arts as magnitudes, "
        f"found {arts!r}"
    )


def build_spell(
    block,
    base_effect_id: str,
    catalog: catalog_module.Catalog,
    design: designline.Design,
    realm_by_spell_id: dict[str, str] | None = None,
    chosen_base_level: int | None = None,
    override_modifiers: dict[str, list[str]] | None = None,
    extra_adjustment: tuple[int, str] | None = None,
    analogy_rationale: str | None = None,
    *,
    book_id: str,
) -> dict:
    range_id = catalog.parameter_id("Range", _parameter_name(design, "range", block))
    duration_id = catalog.parameter_id("Duration", _parameter_name(design, "duration", block))
    target_id = catalog.parameter_id("Target", _parameter_name(design, "target", block))

    requisites: dict[str, str] = {}
    for token in design.tokens:
        if token.kind == "requisite" and token.label != "free":
            for art in _resolve_requisite_arts(token, block):
                requisites.setdefault(art, "adding" if token.magnitude else "free")
    for art in block.stat.requisite_arts:
        requisites.setdefault(art, "free")

    spell = {
        "id": catalog_module.slug_id(block.technique, block.form, block.name),
        "name": block.name,
        "technique": block.technique,
        "form": block.form,
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
    slug = spell["id"]

    if override_modifiers:
        _validate_override_modifiers(override_modifiers, catalog, block)
        # Replace whole key on collision, not merge lists: override_modifiers
        # comes from NUMBERED_OVERRIDES, a hand-verified final answer for
        # exactly which option(s) a modifier should carry. If a future
        # override ever named a modifier _selected_modifiers also populated
        # from the design line, the override is meant to *replace* that
        # design-line guess outright -- not be appended to it -- which is
        # exactly what dict-merge-by-key already does here. No corpus spell
        # collides today; this is deliberate future-proofing, not dead code.
        spell["selectedModifiers"] = {**spell["selectedModifiers"], **override_modifiers}

    realm_by_spell_id = realm_by_spell_id or {}
    chosen_slots: dict[str, str] = {}
    realm = realm_by_spell_id.get(slug)
    if realm is not None and "realm" in catalog.open_slots(base_effect_id):
        chosen_slots["realm"] = realm

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

    spell["citations"] = [{"bookId": book_id}]

    # Build parameter magnitude lookup table for adjustment reduction
    parameter_magnitudes = {p["id"]: p["magnitude"] for p in catalog.parameters}

    adjustments = []
    for token in design.tokens:
        if token.kind == "adjustment":
            magnitude = token.magnitude
            # If this adjustment token's note is one that resolved a Special
            # Range/Duration/Target parameter, reduce the adjustment magnitude
            # by that parameter's own catalog magnitude, so the combined
            # contribution (parameter magnitude + adjustment magnitude) equals
            # the token's original design-line magnitude.
            if token.note in SPECIAL_PARAMETER_BASIS:
                parameter_name = SPECIAL_PARAMETER_BASIS[token.note]
                # Determine which slot (range/duration/target) contains "Spec"/"Special"
                for slot in ["range", "duration", "target"]:
                    raw = {"range": block.stat.range_name, "duration": block.stat.duration_name,
                           "target": block.stat.target_name}[slot]
                    if raw in _SPECIAL_STAT_MARKERS:
                        # This is the slot that was resolved -- get its parameter id
                        parameter_id = catalog.parameter_id(
                            {"range": "Range", "duration": "Duration", "target": "Target"}[slot],
                            parameter_name
                        )
                        magnitude = token.magnitude - parameter_magnitudes.get(parameter_id, 0)
                        break
            adjustments.append({"magnitude": magnitude, "note": token.note})

    if extra_adjustment is not None:
        # A hand-authored adjustment with no design-line token behind it --
        # unlike every other entry above, which is derived from one. Exists
        # for a spell that genuinely achieves a second base-effect guideline
        # at the same level as its chosen one, so combining them is free
        # (magnitude 0): the schema has only one `baseEffectId`, and a
        # magnitude-0 LevelAdjustment is the one honest, UI-visible place to
        # record the second effect rather than silently dropping it. See
        # extract_spells.COMBINED_BASE_EFFECTS.
        magnitude, note = extra_adjustment
        adjustments.append({"magnitude": magnitude, "note": note})

    if adjustments:
        spell["adjustments"] = adjustments

    if block.stat.is_ritual:
        spell["ritualDeclaration"] = _ritual_declaration(block)

    if chosen_slots:
        spell["chosenSlots"] = chosen_slots

    if chosen_base_level is not None:
        spell["chosenBaseLevel"] = chosen_base_level

    if analogy_rationale is not None:
        spell["analogyRationale"] = analogy_rationale

    return spell


def build_template(
    block,
    base_effect_id: str,
    catalog: catalog_module.Catalog,
    design: designline.Design,
    realm_by_spell_id: dict[str, str] | None = None,
    analogy_rationale: str | None = None,
    chosen_slots: dict[str, str] | None = None,
    *,
    book_id: str,
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

    requisites: dict[str, str] = {}
    for token in design.tokens:
        if token.kind == "requisite" and token.label != "free":
            for art in _resolve_requisite_arts(token, block):
                requisites.setdefault(art, "adding" if token.magnitude else "free")
    for art in block.stat.requisite_arts:
        requisites.setdefault(art, "free")

    # The `lib-` slug is the ledger key (resolutions.json, KNOWN_UNRESOLVABLE);
    # the template's own id is that same slug with `tpl-` in place of `lib-`.
    # Derived from slug_id rather than a second slug function.
    slug = catalog_module.slug_id(block.technique, block.form, block.name)
    template_id = "tpl-" + slug.removeprefix("lib-")

    realm_by_spell_id = realm_by_spell_id or {}
    resolved_slots: dict[str, str] = {}
    realm = realm_by_spell_id.get(slug)
    if realm is not None and "realm" in catalog.open_slots(base_effect_id):
        resolved_slots["realm"] = realm
    # A caller-supplied override (e.g. extract_spells.ANALOGY_BASE_EFFECTS's
    # own "chosen_slots" entries) for a slot kind other than realm --
    # guarded the same way, against this base effect's own declared open
    # slots, so a stray kind is silently dropped rather than producing a
    # chosenSlots key validateSpellAgainstCatalog's check 7 would reject.
    if chosen_slots:
        open_kinds = catalog.open_slots(base_effect_id)
        for kind, value in chosen_slots.items():
            if kind in open_kinds:
                resolved_slots[kind] = value

    template = {
        "id": template_id,
        "name": block.name,
        "technique": block.technique,
        "form": block.form,
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

    template["citations"] = [{"bookId": book_id}]

    adjustments = [
        {"magnitude": token.magnitude, "note": token.note}
        for token in design.tokens
        if token.kind == "adjustment"
    ]
    if adjustments:
        template["adjustments"] = adjustments

    if block.stat.is_ritual:
        template["ritualDeclaration"] = _ritual_declaration(block)

    if resolved_slots:
        template["chosenSlots"] = resolved_slots

    if analogy_rationale is not None:
        template["analogyRationale"] = analogy_rationale

    return template


def _handle_magnitude_dependent_modifier(
    token, block, catalog, selected
) -> bool:
    """Handle modifiers where the option depends on magnitude or label.

    Returns True if the token was handled, False otherwise (caller should
    continue checking other modifiers).
    """
    # Creo Auram "unnatural" modifiers: magnitude determines which option.
    # "highly unnatural" (Wings of the Soaring Wind) is the design lines'
    # one alternate wording for the magnitude-2 tier the guideline's own
    # Notes row calls "very unnatural" -- the lookup below is keyed on
    # magnitude, not label text, so recognising the extra wording here is
    # enough to route it to the same option.
    if (
        block.technique == "Creo"
        and block.form == "Auram"
        and token.label.lower()
        in (
            "unnatural",
            "slightly unnatural",
            "very unnatural",
            "highly unnatural",
            "wholly divorced",
        )
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
        return True

    # Aquam base-individual: liquid type affects base Individual size
    # All options at magnitude 0; type is determined by design-line label
    if (
        block.form == "Aquam"
        and token.label.lower()
        in ("water", "naturally-occurring", "processed", "dangerous", "poison")
    ):
        modifier_id = "aquam-base-individual"
        liquid_type_options = {
            "water": "aquam-base-water",
            "naturally-occurring": "aquam-base-natural",
            "processed": "aquam-base-processed",
            "dangerous": "aquam-base-dangerous",
            "poison": "aquam-base-poison",
        }
        option_id = liquid_type_options.get(token.label.lower())
        if option_id is None:
            raise designline.UnknownToken(
                f"{block.name}: aquam-base-individual has no option for liquid "
                f"type {token.label!r}"
            )
        if not _option_exists(catalog, modifier_id, option_id, 0):
            raise designline.UnknownToken(
                f"{block.name}: modifiers.json has no {modifier_id!r} option "
                f"{option_id!r}"
            )
        selected.setdefault(modifier_id, []).append(option_id)
        return True

    # Terram material: sand/mud/clay at base, stone/glass +1, metal/gemstone +2
    if (
        block.form == "Terram"
        and block.technique in ("Muto", "Perdo")
        and token.label.lower()
        in ("material", "stone", "glass", "metal", "gemstone", "metal/gems")
    ):
        modifier_id = f"{block.technique.lower()}-terram-material"
        technique_prefix = block.technique.lower()
        material_options = {
            (0, "dirt"): f"{technique_prefix}-terram-material-dirt",
            (0, "sand"): f"{technique_prefix}-terram-material-dirt",
            (0, "mud"): f"{technique_prefix}-terram-material-dirt",
            (0, "clay"): f"{technique_prefix}-terram-material-dirt",
            (1, "stone"): f"{technique_prefix}-terram-material-stone",
            (1, "glass"): f"{technique_prefix}-terram-material-stone",
            (2, "metal"): f"{technique_prefix}-terram-material-base-metal",
            (2, "gemstone"): f"{technique_prefix}-terram-material-gemstone",
            # "metal/gems" (Stone to Falling Dust) names both magnitude-2
            # options at once, cost-equal, rather than choosing between
            # them -- not itself in the table above, so it falls through to
            # the by_magnitude default below like bare "metal" already does.
        }
        option_id = material_options.get((token.magnitude, token.label.lower()))
        if option_id is None:
            # Also the default for a bare, technique-ambiguous "metal" -- see
            # this function's docstring. Level correctness never depends on
            # the choice (every magnitude-2 option costs the same); this only
            # picks which one gets displayed.
            by_magnitude = {
                0: f"{technique_prefix}-terram-material-dirt",
                1: f"{technique_prefix}-terram-material-stone",
                2: f"{technique_prefix}-terram-material-base-metal",
            }
            option_id = by_magnitude.get(token.magnitude)
        if option_id is None:
            raise designline.UnknownToken(
                f"{block.name}: {modifier_id} has no option at magnitude "
                f"{token.magnitude} with label {token.label!r}"
            )
        if not _option_exists(catalog, modifier_id, option_id, token.magnitude):
            raise designline.UnknownToken(
                f"{block.name}: modifiers.json has no {modifier_id!r} option "
                f"{option_id!r} at magnitude {token.magnitude}"
            )
        selected.setdefault(modifier_id, []).append(option_id)
        return True

    # Rego Ignem fire-intensity ward: how much fire damage the ward stops.
    # Ward against Heat and Flames is the only corpus spell that prints this
    # shape ("+2 for up to +15 damage"); the exact magnitude/threshold pair
    # already matches rego-ignem-fire-intensity-15 (magnitude 2) in
    # modifiers.json -- that modifier's scope already includes reig-4 (this
    # spell's sole base-4 candidate), it was simply never wired to this
    # phrasing. A closed check on the exact printed text, not a general
    # "for up to +N damage" parser: only one spell needs this today.
    if (
        block.technique == "Rego"
        and block.form == "Ignem"
        and token.label.lower() == "for up to +15 damage"
    ):
        modifier_id = "rego-ignem-fire-intensity"
        option_id = f"{modifier_id}-15"
        if not _option_exists(catalog, modifier_id, option_id, token.magnitude):
            raise designline.UnknownToken(
                f"{block.name}: modifiers.json has no {modifier_id!r} option "
                f"{option_id!r} at magnitude {token.magnitude}"
            )
        selected.setdefault(modifier_id, []).append(option_id)
        return True

    # Rego transport distance: magnitude ladder for moving things at distance
    # Applies to base effects: rehe-10b, reig-3c, rete-4, rean-10b, reaq-4b
    if (
        block.technique == "Rego"
        and token.label.lower()
        in ("distance", "arcane connection", "5 paces", "50 paces", "500 paces",
            "1 league", "7 leagues")
    ):
        modifier_id = "rego-transport-distance"
        distance_options = {
            "5 paces": "rego-distance-5-paces",
            "50 paces": "rego-distance-50-paces",
            "500 paces": "rego-distance-500-paces",
            "1 league": "rego-distance-1-league",
            "7 leagues": "rego-distance-7-leagues",
            "arcane connection": "rego-distance-arcane",
        }
        option_id = distance_options.get(token.label.lower())
        if option_id is None:
            raise designline.UnknownToken(
                f"{block.name}: rego-transport-distance has no option for distance "
                f"{token.label!r}"
            )
        if not _option_exists(catalog, modifier_id, option_id, token.magnitude):
            raise designline.UnknownToken(
                f"{block.name}: modifiers.json has no {modifier_id!r} option "
                f"{option_id!r}"
            )
        selected.setdefault(modifier_id, []).append(option_id)
        return True

    return False


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
        if token.kind in _MAGNITUDE_KEYED_MODIFIERS:
            modifier_id, options = _MAGNITUDE_KEYED_MODIFIERS[token.kind]
            option_id = options.get(token.magnitude)
            if option_id is None:
                raise designline.UnknownToken(
                    f"{block.name}: no {modifier_id} option at magnitude "
                    f"{token.magnitude}"
                )
            if not _option_exists(catalog, modifier_id, option_id, token.magnitude):
                raise designline.UnknownToken(
                    f"{block.name}: modifiers.json has no {modifier_id!r} option "
                    f"{option_id!r} at magnitude {token.magnitude}"
                )
            if modifier_id in selected:
                # Both elaborate-effect and complexity are selectionMode
                # "single". Two tokens of the same magnitude-keyed kind on one
                # design line would put two option ids under it, producing an
                # asset the app's own validateSpellDraft rejects. No corpus
                # spell does this today and nothing else in the pipeline
                # would notice if one appeared.
                raise designline.UnknownToken(
                    f"{block.name}: two {token.kind} tokens, but {modifier_id!r} "
                    f"is a single-selection modifier"
                )
            selected[modifier_id] = [option_id]
            continue
        if token.kind != "modifier":
            continue

        # Try magnitude-dependent modifiers (Creo Auram unnatural, Aquam liquid type,
        # Terram material hierarchy)
        if _handle_magnitude_dependent_modifier(token, block, catalog, selected):
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


def _validate_override_modifiers(
    override_modifiers: dict[str, list[str]], catalog: catalog_module.Catalog, block
) -> None:
    """Check every id in a NUMBERED_OVERRIDES `modifiers` value against the
    real catalog, the same way every other modifier-selection path in this
    file does via `_option_exists` -- an override is still a hand-typed id,
    and a typo or a renamed modifiers.json option should block the spell
    the same way an unmapped design-line token would, not write a dangling
    id into the emitted asset silently.

    Unlike `_option_exists`, there is no design-line token magnitude to
    check an override's option against -- NUMBERED_OVERRIDES names the
    option id directly, already having picked the right ladder rung by
    hand -- so this checks only that `modifier_id` and each `option_id`
    are real.
    """
    for modifier_id, option_ids in override_modifiers.items():
        modifier = next((m for m in catalog.modifiers if m["id"] == modifier_id), None)
        if modifier is None:
            raise designline.UnknownToken(
                f"{block.name}: modifiers.json has no {modifier_id!r} modifier"
            )
        known_option_ids = {o["id"] for o in modifier["options"]}
        for option_id in option_ids:
            if option_id not in known_option_ids:
                raise designline.UnknownToken(
                    f"{block.name}: modifiers.json has no {modifier_id!r} option "
                    f"{option_id!r}"
                )


def _option_exists(
    catalog: catalog_module.Catalog, modifier_id: str, option_id: str, magnitude: int
) -> bool:
    """Is `option_id` really a `modifier_id` option carrying `magnitude`?

    _ELABORATE_OPTIONS and _COMPLEXITY_OPTIONS are hand-written id tables, so
    a typo in one of them — or a renamed option in modifiers.json — would
    otherwise put a dangling id into the asset with no Python test to catch
    it. Checking the magnitude too means the table cannot drift out of step
    with the catalog silently.
    """
    modifier = next((m for m in catalog.modifiers if m["id"] == modifier_id), None)
    if modifier is None:
        return False
    return any(
        o["id"] == option_id and o["magnitude"] == magnitude
        for o in modifier["options"]
    )


# A "Spec"/"Special" Range, Duration or Target has no parameters.json entry
# of its own -- todo item 26's decision was that this is shorthand for a
# real parameter, not a fifth catalog value, resolved by reading what the
# spell's own adjustment clause says it's "based on"/"equivalent to". A
# closed table, not a parser: each key is a designline.ADJUSTMENT_LABELS
# entry verified against the one spell that prints it. Watching Ward also
# prints a Special Duration ("Duration is non-standard") but names no basis
# for it at all -- deliberately absent here. It now imports as an exception
# spell instead (scripts/spell_import/exceptions.py), not through this
# table at all -- see todo item 26 and
# docs/superpowers/specs/2026-08-15-exception-spells-design.md.
SPECIAL_PARAMETER_BASIS: dict[str, str] = {
    "Special (based on Concentration)": "Concentration",
    "Special based on Mom": "Momentary",
    "Special (equivalent to Boundary)": "Boundary",
}

_SPECIAL_STAT_MARKERS = frozenset({"Spec", "Special"})


def _parameter_name(design: designline.Design, slot: str, block) -> str:
    """Resolve a slot from the stat line, expanded to its full catalog name."""
    raw = {
        "range": block.stat.range_name,
        "duration": block.stat.duration_name,
        "target": block.stat.target_name,
    }[slot]
    if raw in _SPECIAL_STAT_MARKERS:
        for token in design.tokens:
            if token.kind == "adjustment" and token.note in SPECIAL_PARAMETER_BASIS:
                return SPECIAL_PARAMETER_BASIS[token.note]
        raise designline.UnknownToken(
            f"{block.name}: {slot} is {raw!r} but no adjustment token names "
            "what it's based on"
        )
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


def build_exception_spell(block, rationale: str, *, book_id: str) -> dict:
    """Build an `ExceptionSpell.fromMap`-shaped entry for a spell the
    rulebook itself says guideline arithmetic doesn't apply to.

    No design-line tokenization is attempted -- there is nothing in
    exceptions.EXCEPTION_SPELLS this function could tokenize correctly, by
    construction (that's what routes a spell here instead of build_spell/
    build_template). Reuses SpellBlock's already-parsed prose/stat-line
    fields untouched. See
    docs/superpowers/specs/2026-08-15-exception-spells-design.md.
    """
    slug = catalog_module.slug_id(block.technique, block.form, block.name)
    exception = {
        "id": "exc-" + slug.removeprefix("lib-"),
        "name": block.name,
        "technique": block.technique,
        "form": block.form,
        "range": block.stat.range_name,
        "duration": block.stat.duration_name,
        "target": block.stat.target_name,
        "isRitual": block.stat.is_ritual,
        "source": "published",
        "summary": _template_summary(block),
        "rationale": rationale,
        "citations": [{"bookId": book_id}],
    }
    if block.printed_level is not None:
        exception["printedLevel"] = block.printed_level
    description = _description(block)
    if description:
        exception["description"] = description
    return exception
