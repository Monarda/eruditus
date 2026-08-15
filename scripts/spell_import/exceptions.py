"""Spells the rulebook itself says guideline arithmetic doesn't apply to.

Two shapes -- see docs/superpowers/specs/2026-08-15-exception-spells-design.md
for the full investigation: the spell's own prose disclaims normal Hermetic
design ("rulebook-disclaimed"), or the spell's real shape doesn't fit the
Range/Duration/Target model at all regardless of what the prose says
("schema-mismatched"). Either way there is no arithmetic to recover -- these
spells never route through build_spell/build_template, and no future
tokenizer or ledger change should try to make them.

A closed, exact-name table, the same discipline as extract_spells.py's
HAND_DERIVED/KNOWN_UNRESOLVABLE/DESIGN_LINE_INCOMPLETE. Each value is the
citation-backed reason a human read off the spell's own printed text, quoted
or closely paraphrased -- never inferred from a shape or a heuristic.
"""

EXCEPTION_SPELLS: dict[str, str] = {
    "Wizard's Communion": (
        'Design line prints "(Base effect)" but the spell\'s own prose '
        'disclaims it: "Communion is a remnant of Mercurian rituals, so it '
        'does not perfectly fit into the guidelines of Hermetic theory."'
    ),
    "Wizard's Vigil": (
        "No design line at all -- defined purely relative to Wizard's "
        'Communion ("treat it as a Wizard\'s Communion of two magnitudes '
        'lower"), itself an exception.'
    ),
    "Aegis of the Hearth": (
        "No design-line marker of any kind. The rulebook's own text says "
        'why: a Major Breakthrough combining Mercurian ritual with Hermetic '
        'theory, "more powerful than it ought to be, and has no Perdo '
        'requisite."'
    ),
    "Whispering Winds": (
        'Design line is "(Unique spell)", not a variant of "(Base effect)". '
        'Prose: "fits poorly into the normal framework of Hermetic magic."'
    ),
    "Watching Ward": (
        'Duration is event-triggered ("until the conditions you specify '
        'come to pass") -- not a missing catalog value, a missing concept. '
        'Confirmed General-kind (no printed level) independently by another '
        'spell\'s own cross-reference: Suppressing the Wizard\'s Handiwork '
        'calls it "a Watching Ward [ReVi Gen]" in passing.'
    ),
    "Mists of Change": (
        'Prints two Durations in one stat line ("D: Sun & Year") plus its '
        'own "slightly nonstandard effect" clause -- the R/D/T model has '
        "exactly one Duration slot."
    ),
}
