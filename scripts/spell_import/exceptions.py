"""Spells the rulebook itself says guideline arithmetic doesn't apply to.

Three shapes -- see
docs/superpowers/specs/2026-08-15-exception-spells-design.md for the
original two-shape investigation: the spell's own prose disclaims normal
Hermetic design ("rulebook-disclaimed"), or the spell's real shape doesn't
fit the Range/Duration/Target model at all regardless of what the prose says
("schema-mismatched"). Either way there is no arithmetic to recover -- these
spells never route through build_spell/build_template, and no future
tokenizer or ledger change should try to make them.

A third shape, added 2026-08-16: the guideline a General-kind spell's own
effect needs was never printed in that Technique/Form's own table at all --
confirmed by reading every printed row, not inferred from an absence alone --
and reconstructing one from the spell's own prose was already tried once
(base_effects.json's now-deleted `inco-gen`, this file's *Sight of the True
Form* entry) and reverted as inventing rulebook content the table doesn't
contain (test_general_catalog.GeneralCatalogTest.
test_general_entries_match_the_rulebook_bullet_for_bullet). Standard R/D/T
(unlike Watching Ward/Mists of Change's genuinely nonstandard shape) --
recorded as free text here purely because there is no base effect to attach
a resolved id to, the same reason `technique`/`form` are plain strings on
`ExceptionSpell` rather than looked up through one.

A closed, exact-name table, the same discipline as extract_spells.py's
HAND_DERIVED/KNOWN_UNRESOLVABLE/DESIGN_LINE_INCOMPLETE. Each value is the
citation-backed reason a human read off the spell's own printed text, quoted
or closely paraphrased -- never inferred from a shape or a heuristic.

Like those tables, this one is keyed by bare spell name across every book,
not per book id -- see the comment above extract_spells.HAND_DERIVED for why
that is safe today and what a third book's name collision would need.
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
    "Sight of the True Form": (
        'Design line prints "(Variable base)", a marker this importer does '
        "not tokenize -- the caster chooses the level, and Intellego "
        "Corpus's own guideline table prints no General row describing "
        "this spell's effect (\"can see through mundane masks and "
        'disguises at level 10, and can see through the effects of other '
        'spells that are equal to or lower than the level of this spell"). '
        "A matching row was built from this exact prose once (`inco-gen`, "
        "a targetSpellLevel guideline) and deliberately removed -- "
        "reconstructing rulebook content the table never printed, the same "
        "policy that also governs The Invisible Eye Revealed's own entry "
        "just above, and that routed Dispel the Phantom Image, Restore the "
        "Moved Image and Lay to Rest the Haunting Spirit to an existing "
        "Vim-level guideline instead (see "
        "docs/superpowers/specs/2026-08-16-analogy-unblock-blocked-spells-design.md)."
    ),
    "The Invisible Eye Revealed": (
        "Design line prints \"(Base effect)\", General-kind, no printed "
        "level. Intellego Vim's own guideline table prints exactly one "
        "General row, invi-G (\"detect the traces of magic of negative "
        "magnitude up to the magnitude of the guideline used - 2\") -- a "
        "residual-trace-decay formula, confirmed the wrong guideline by "
        "checking the arithmetic, not just the wording: at level 20 invi-G "
        "computes a magnitude of 2, while this spell's own text (\"detects "
        "the use of Intellego spells of up to double the level of this "
        "spell\") needs a level threshold of 40 -- different "
        "GeneralEffectKind families (spellTraceMagnitude vs. "
        "targetSpellLevel), not a close-enough match. No other Form's "
        "guideline can substitute by analogy either: this spell is already "
        "Intellego Vim, the top of the analogy chain (see "
        "docs/superpowers/specs/2026-08-16-analogy-unblock-blocked-spells-design.md). "
        "Same shape as Sight of the True Form: a matching InVi row was not "
        "attempted here for the identical reason -- "
        "test_general_entries_match_the_rulebook_bullet_for_bullet forbids it."
    ),
}
