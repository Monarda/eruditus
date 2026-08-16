"""Extract published spells from the rulebook into assets/data/spell_library.json.

Maintained and re-runnable, unlike scripts/flag_ritual_effects.py. Running it
against an unchanged ledger and unchanged catalogs produces byte-identical
output; `test_extract.py` asserts exactly that.

    python -m scripts.spell_import.extract_spells          # report only
    python -m scripts.spell_import.extract_spells --write  # rewrite the asset
"""
import argparse
import dataclasses
import json
import sys

from . import blocks, catalog as catalog_module, designline, ledger as ledger_module
from . import emit, exceptions as exceptions_module, provenance, report as report_module, sources

LIBRARY_PATH = catalog_module.DATA_DIR / "spell_library.json"
TEMPLATES_PATH = catalog_module.DATA_DIR / "spell_templates.json"
EXCEPTIONS_PATH = catalog_module.DATA_DIR / "spell_exceptions.json"
PROPOSALS_PATH = ledger_module.LEDGER_PATH.with_name("resolutions.proposed.json")
REPORT_PATH = ledger_module.LEDGER_PATH.with_name("import_report.md")


class SourceMoved(Exception):
    """The rulebook changed since the committed asset was generated."""


# Spells that genuinely cannot be resolved by a ledger entry: the rulebook's
# own text supports two or more candidates about equally, with no textual
# signal for which is primary (checked twice — a first pass resolved these,
# a review pass found the rationale was picking the most general-sounding
# candidate rather than a textually forced one, and pulled them). Recorded
# here rather than left as `unresolved` because "unresolved" means "add a
# ledger entry" — these don't have one to add. See .superpowers/todo.md
# item 27. Remove an entry once a rules decision actually resolves it.
#
# 2026-08-15 (item 39): re-read all 4 against the discipline above. Three
# had a forced discriminator after all and moved to resolutions.json —
# *Tracks of the Faerie Glow* and *Sense the Feet that Thread the Earth*
# both use "no seeing is involved" (the same test already governing
# lib-inte-eyes-eons's inte-4a pick: one makes tracks glow for normal
# eyesight, the other is explicitly "feel", neither is sight-based); *The
# Crystal Dart* turns solid stone into a solid crystal dart, the only
# level-3 Muto Terram guideline built for a solid-to-solid earth-family
# change, and the design line's arithmetic has no room for the material
# surcharge a *different* material pair would need.
#
# *Conjuration of the Indubitable Cold* moved out too, 2026-08-16 — see
# COMBINED_BASE_EFFECTS below. It was never actually a "which one is right"
# ambiguity: peig-4b and peig-4c are both level 4, so either pick computes
# the identical printed level. What made it look unresolvable was a model
# gap, not a rules one -- the spell's own text matches both guidelines at
# once ("all nonliving things are chilled thoroughly" / "all living things
# ... lose one Fatigue level"), and `Spell.baseEffectId` can only record one
# ("peig-4a"'s "extinguish" is still excluded, contradicted by the spell's
# own text for anything bigger than a campfire -- that's the *level 3*
# guideline, not level 4). Currently empty; the mechanism stays for the next
# spell that turns out to be a genuine, no-forced-discriminator tie.
KNOWN_UNRESOLVABLE: dict[str, str] = {}


# Spells that legitimately achieve more than one same-level base-effect
# guideline at once, where `Spell.baseEffectId` (a single required field)
# can only record one. The chosen id goes through the normal ledger
# (resolutions.json) like any other multi-candidate spell; the *other*
# effect is recorded here as a magnitude-0 LevelAdjustment, so it is real,
# UI-visible data (a breakdown line with a note) instead of silently
# dropped. Magnitude 0 because both guidelines share the same base level --
# see the Requisites section's "base Arts and level ... are those for the
# highest-level effect" for the closest the rulebook comes to stating this
# principle outright (written for an added Art, not a same-Technique/Form
# guideline, but the same "does not raise the cost" logic applies).
COMBINED_BASE_EFFECTS: dict[str, tuple[int, str]] = {
    "lib-peig-conjuration-indubitable-cold": (
        0,
        "Also chills a person, causing a lost Fatigue level (peig-4c), at "
        "the same base level as the chosen guideline (peig-4b, chilling an "
        "object) -- both are printed at level 4, so combining them adds "
        "nothing to the spell's cost.",
    ),
}


# Realm for every corpus spell built on a guideline whose `openSlots` includes
# "realm" -- verified once against the rulebook's own prose (Decision 7/9/10,
# docs/superpowers/specs/2026-08-10-open-guideline-slots-design.md), never
# inferred at build time. A prose scan was tried first and rejected: two of
# these spells ("Ward against Faeries of the Air"/"...of the Wood") restate
# their realm only by cross-referencing "Ward against Faeries of the Waters"
# by name, and Wind of Mundane Silence's only "Magic" occurrences are "Magic
# Resistance"/"Magical things" -- neither a realm commitment, which is exactly
# why it has no entry here (its template imports with chosenSlots: {} and the
# caster fills the realm in later, same as any case-2 spell).
REALM_BY_SPELL_ID = {
    "lib-revi-circular-ward-against-demons": "Infernal",
    "lib-rean-ward-against-beasts-legend": "Magic",
    "lib-reaq-ward-against-faeries-waters": "Faerie",
    "lib-reau-ward-against-faeries-air": "Faerie",
    "lib-rehe-ward-against-faeries-wood": "Faerie",
    "lib-rete-ward-against-faeries-mountain": "Faerie",
    "lib-reme-ring-warding-against-spirits": "Magic",
}


# General spells whose printed design line cannot be reconciled with their
# stat line. Not a wrong ledger pick and not an ambiguity between candidates
# -- KNOWN_UNRESOLVABLE means "two candidates fit equally", which is a
# different thing. Deliberately a hand-maintained list and NOT an inline
# assertion-6 check: ReferenceOracleTest exists to catch a template that
# violates assertion 6, and a filter that removes exactly what the test
# looks for would make the test unable to fail.
#
# Both entries below have exactly one general_candidates() hit -- reim-G,
# invi-G -- so without this table they would auto-resolve and silently import
# against the wrong guideline. Confirmed 2026-08-16 (re-derived from
# docs/superpowers/plans/2026-08-05-general-base-effects.md, which found this
# first): reim-G/invi-G are each their art's *ward* guideline (Touch, Ring,
# Circle), and neither Restore the Moved Image (cancels a moved-image spell)
# nor The Invisible Eye Revealed (feels being magically spied on) is a ward.
# The Rego Imaginem and Intellego Vim guideline tables print no second
# General bullet that actually describes either spell's own effect -- the
# same shape as `peme-G`/`inco-gen` below, and just as permanently
# unresolvable without inventing rulebook content the table does not print.
# See test_general_catalog.ReferenceOracleTest's docstring for the assertion
# this table exists to keep out of reach.
#
# Restore the Moved Image's own wording ("as long as you can match the
# spell's level on a stress die + the level of your spell") is close to
# verbatim identical to Dispel the Phantom Image's ("whose level you match
# or exceed on a stress die + the level of your spell", Perdo Imaginem, see
# the `general_candidates` empty-branch comment below) -- not a coincidence,
# but two different Technique pairings sharing one mechanical shape, not the
# same pattern twice:
#   - Dispel the Phantom Image is Perdo Imaginem dispelling a *Creo*
#     Imaginem spell -- Perdo opposing Creo, scoped to one Form. This is the
#     Imaginem-scoped echo of Perdo Vim's own "dispel" guideline (Wind of
#     Mundane Silence's paradigm: "cancel the effects of any spell if...
#     you can double the level of the spell on a stress die + the level of
#     your spell") -- same mechanic, scoped to one Form instead of "any
#     realm/type", and without the doubling.
#   - Restore the Moved Image is Rego Imaginem undoing a *Rego* Imaginem
#     spell -- same Technique and Form, "control undoing control", matching
#     Rego Vim's "sustain or suppress" pattern instead.
# Both are a recurring per-Form counter-magic mechanic (match/exceed a
# target spell's level, no magnitude offset) that the Definitive Edition
# uses as spell-level flavor text without ever generalizing it into that
# Form's own guideline table; only the Vim-level versions carry a magnitude
# offset the Form-level ones don't. The Invisible Eye Revealed fits the same
# family too ("detects... up to double the level of this spell", no stress
# die but the same target-spell-level shape, and cross-Form -- it detects
# Intellego spells of any Form, not just Vim), and Intellego Vim's own table
# doesn't tabulate that either.
#
# Lay to Rest the Haunting Spirit (see the `general_candidates` empty-branch
# comment below) is a fourth instance, not a fifth unrelated one: "loses a
# number of points from its Might equal to the level of this spell" is Perdo
# Vim's own generic pevi-G3 ("Reduce target's Might Score by spell level +2
# magnitudes"), Form-narrowed to ghosts/spirits and, as with the others,
# without the Vim-level's magnitude offset. Checked 2026-08-16 against a
# tempting but wrong analogy: most Perdo Forms *do* carry a "reduce an
# elemental's Might Score by the level of the spell +2 magnitudes" General
# row (peaq-gen, peau-gen, peig-gen, pete-G), but Elementals (Core Rules,
# "Elementals") are a specific creature category restricted to exactly the
# four physical Forms (Earth/Water/Air/Fire = Terram/Aquam/Auram/Ignem) --
# there is no such thing as a Mentem elemental, so Perdo Mentem's table
# lacking that specific row is expected, not a gap. Also checked against
# `wip/Ars Magica 5e - Core Rules.md` (a pre-Definitive-Edition source,
# distinct from the reviewed text): same table, same absence -- not an
# editing drop either.
# Reconstructing a Rego-Imaginem-, Intellego-Vim- or Perdo-Mentem-scoped row
# "by analogy" to the Vim guidelines would still be inventing content none
# of those three tables print -- confirmed 2026-08-16, does not change the
# classification above.
DESIGN_LINE_INCOMPLETE = {
    "lib-reim-restore-moved-image":
        "prints (Base effect) but the stat line costs 2 magnitudes",
    "lib-invi-invisible-eye-revealed":
        "prints (Base effect) but the stat line costs 2 magnitudes",
    # Wizard's Communion used to be here. It now imports as an exception
    # spell (scripts/spell_import/exceptions.py) -- see
    # docs/superpowers/specs/2026-08-15-exception-spells-design.md.
}


# The rulebook prints no design line for these three. Each derivation below is
# done by hand from the spell's stat line and a chosen guideline, and each is
# then checked by assertion 1 — if a derivation is wrong the computed level
# will not equal the printed one. Hand-derivation under a test is a different
# thing from hand-derivation on trust.
#
# One further no-design-line spell, Sight of the True Form, is General-level
# and belongs to todo item 25, not here (a General guideline has no numeric
# level for assertion 1 to check a derivation against). Aegis of the Hearth
# and Wizard's Vigil used to be listed alongside it here too -- both now
# import as exception spells instead (scripts/spell_import/exceptions.py),
# since their own prose disclaims guideline arithmetic entirely rather than
# merely lacking a printed derivation. See
# docs/superpowers/specs/2026-08-15-exception-spells-design.md.
#
# - Enchantment of the Scrying Pool (R: Touch, D: Year, T: Ind, level 30):
#   Base 5 (inaq-5, "Learn the magical properties of a liquid" — the sole
#   candidate at level 5, so no ledger entry is needed) + Touch(1) + Year(4)
#   computes to exactly 30 via SpellLevelCalculator, and is the *only*
#   InAq base level (1, 2, 3a/3b, 4, 5, 10, 15, 20) that does. The "does not
#   conform" text turns out to describe the *range* mechanism (the pool
#   reaches another body of water via what "appears to be" an Arcane
#   Connection, without the usual +4 Range: Arcane Connection surcharge) —
#   not the base-effect arithmetic itself, which lines up exactly once the
#   stat line's actual Range (Touch, to the pool touched when cast) is used.
#
# Whispering Winds (R: Sight, D: Conc, T: Ind, level 15) used to be
# investigated here as a hand-derivation candidate and left blocked -- see
# git history for that reasoning. It now imports as an exception spell
# instead: its design line is printed as the literal marker "(Unique
# spell)", and its own prose says "fits poorly into the normal framework of
# Hermetic magic". See scripts/spell_import/exceptions.py and
# docs/superpowers/specs/2026-08-15-exception-spells-design.md.
#
# - Hermes' Portal (R: Arc, D: Year, T: Ind, level 75) has no working
#   derivation within this importer's current modelling. The only
#   thematically-grounded guideline is rete-4 ("Transport a non-living
#   object instantly up to 5 paces... add magnitudes for distance/Arcane
#   Connection"); with Arc(4) + Year(4) + Ind(0) fixed by the stat line,
#   Base 4 computes to 40, leaving a 35-level (7-magnitude) gap that only
#   closes with rete-4's own distance ladder at its top rung (Arcane
#   Connection, magnitude 5, modifiers.json id "rego-transport-distance")
#   plus 2 magnitudes of size. `emit.build_spell` only maps "size" tokens to
#   a modifiers.json option today (see `_selected_modifiers`'s docstring);
#   "rego-transport-distance" is modelled in the catalog (scoped to exactly
#   rete-4/rehe-10b/reig-3c) but not yet wired up. Extending that mapping is
#   a real fix, just a different and larger one than "correct this string" —
#   left blocked rather than forced through an unimplemented modifier or an
#   unrelated candidate whose math happens to work: rete-15b (+4 size) lands
#   on exactly 75, but describes hurling a projectile, not a travel portal.
#
# Aegis of the Hearth used to be investigated here and left permanently
# blocked -- see git history. It now imports as an exception spell instead:
# no design-line marker of any kind is printed, and the rulebook's own text
# explains why (a Major Breakthrough, "more powerful than it ought to be").
# See scripts/spell_import/exceptions.py.
#
# - Ward against Faeries of the Mountain (Rego Terram, General, R: Touch, D:
#   Ring, T: Circle) prints no design-line marker at all -- but its full
#   prose is a complete specification once followed: "As Ward Against
#   Faeries of the Waters (ReAq Gen), but for faeries of earth and stone."
#   That sentence names both the guideline to use (the analogous Rego Terram
#   General ward, rete-G -- "Ward against beings associated with Terram from
#   one supernatural realm... with Might less than the level", the only
#   General candidate at Rego+Terram, so no ledger entry is needed) and the
#   realm (Faerie, same as the spell it points to). Two siblings that use the
#   identical "As Ward Against Faeries of the Waters..." phrasing --
#   Ward against Faeries of the Air, Ward against Faeries of the Wood -- both
#   print "(Base effect)" and already import via REALM_BY_SPELL_ID; the text
#   here supplies exactly the marker those two print literally, not new
#   information. Checked 2026-08-15. Of the other no-design-line General
#   spells, Sight of the True Form has no comparable sibling reference and
#   stays blocked under item 25; Aegis of the Hearth and Wizard's Vigil import
#   as exception spells instead (scripts/spell_import/exceptions.py).
HAND_DERIVED: dict[str, str] = {
    "Enchantment of the Scrying Pool": "(Base 5, +1 Touch, +4 Year)",
    "Ward against Faeries of the Mountain": "(Base effect)",
    # Prints only "(Mercurian Ritual)", no arithmetic at all. Derived from
    # rete-4's own guideline note ("add magnitudes for distance/Arcane
    # Connection") plus the spell's own stat line (R: Arc, D: Year, T: Ind)
    # and prose ("people, animals, and objects can travel" -> Size, not a
    # single small item). Magnitude check: 4 (base) + 4 (Arc) + 4 (Year) +
    # 5 (arcane connection, rego-transport-distance's top rung) + 2 (size)
    # = 19 magnitudes -> level 75. Matches the printed level exactly. See
    # todo item 45.
    "Hermes' Portal": "(Base 4, +4 Arc, +4 Year, +5 arcane connection, +2 size)",
}


# One published design line names an adjustment and prints no magnitude for it.
# The magnitude below is a literal, worked out by hand and then *checked by*
# assertion 1 (published_spell_import_test.dart) -- it is never computed as
# `printed - computed`, which would make that assertion tautological here and
# unable to fail.
#
# The Shadow of Human Life (Creo Imaginem, R: Touch, D: Sun, T: Ind, Req:
# Mentem), printed LEVEL 40, design line:
#
#     (Base 2, +1 Touch, +2 Sun, +1 intricacy, +6 Mentem requisite,
#      for a very elaborate effect)
#
# In the rulebook's own arithmetic the numbered tokens already reach 40 --
# 2 -> 3 (Touch) -> 5 (Sun) -> 10 (intricacy) -> 40 (+6 requisite) -- and "for
# a very elaborate effect" is the text's *justification* for charging six
# magnitudes on a requisite instead of the usual one. This app does not model a
# requisite that way: `Requisite.magnitude` is 1 for every `adding` requisite
# (lib/models/requisite.dart), so the six-magnitude charge has to be split into
# the one magnitude the requisite carries and the five that the elaborateness
# carries. Hence:
#
#     base 2, additive capacity 3 (5 - 2)
#     +1 Touch                 -> 3   (additive tier)
#     +2 Sun                   -> 5   (additive tier, capacity spent)
#     +1 intricacy             -> 10  (crim-intricate-design, magnitude 1)
#     +1 Mentem requisite      -> 15  (adding requisite, magnitude 1)
#     +5 very elaborate effect -> 40  (5 x 5)
#
#     40 == the printed level. Any other magnitude misses it by 5 per step, so
#     assertion 1 discriminates this value exactly.
#
# Not modelled as an `elaborate-effect` modifier option: that modifier tops out
# at magnitude 3 (assets/data/modifiers.json), and inventing a magnitude-5
# option to fit one spell would be fitting the catalog to the arithmetic. A
# per-spell LevelAdjustment is what the rulebook's phrasing actually is.
#
# Mists of Change used to be the other numberless case here and stayed
# blocked -- see git history. It now imports as an exception spell instead
# (scripts/spell_import/exceptions.py): its "slightly nonstandard effect"
# clause has no magnitude to derive, and its stat line's "D: Sun & Year"
# (two durations) can't be expressed by any adjustment regardless. See
# docs/superpowers/specs/2026-08-15-exception-spells-design.md.
#
# Keyed by spell name -> (magnitude, the printed phrase to attach it to).
HAND_DERIVED_ADJUSTMENT: dict[str, tuple[int, str]] = {
    "The Shadow of Human Life": (5, "for a very elaborate effect"),
}


# A published design line missing the whitespace between a magnitude and its
# label -- a rulebook typo, not a mechanism. `designline._TOKEN` requires at
# least one space (`\d+\s+`), so "+1Touch" fails to match at all, before any
# label is even looked at. Fixed by exact substitution, keyed by spell name,
# rather than loosening `_TOKEN` globally -- a global `\s*` would also accept
# "+1Touch" as a typo for something it might not be; this table only ever
# fixes a specific, verified corpus line.
#
# Ward against Heat and Flames (Rego Ignem): "(Base 4, +2 for up to +15
# damage, +1Touch, +2 Sun)".
DESIGN_LINE_TYPOS: dict[str, tuple[str, str]] = {
    "Ward against Heat and Flames": ("+1Touch", "+1 Touch"),
    # Missing the outer closing paren entirely -- 3 opens, 2 closes in the
    # printed line. A rulebook transcription defect (verified against the
    # reviewed Definitive Edition markdown directly), not a _split_parts
    # bug: the line is genuinely unbalanced, not oddly-but-validly nested.
    "The Bountiful Feast": (
        "so that the area affected is up to about 6 miles across)",
        "so that the area affected is up to about 6 miles across))",
    ),
}


# A published spell whose design line's numeric base has no exact catalog
# match, but resolves to a real base effect once a human reads the
# guideline text: either a General guideline this specific spell commits to
# one level of (Core Rules line 12414 says the guideline itself stays
# open-ended; this published spell already made the choice, in print,
# once), or a numbered guideline's own ladder rung one step past what the
# table prints. Verified once per entry against the rulebook, never
# inferred -- "no numbered match" alone doesn't distinguish the two cases,
# which is why this is a hand-verified table rather than an automatic
# "no match -> assume General" heuristic. See
# docs/superpowers/specs/2026-08-15-guideline-level-derivation-design.md.
#
# Infernal Smoke of Death (Muto Auram, printed LEVEL 40, "Base 25, +2 Voice,
# +1 Conc"): built on muau-gen, the MuAu General row ("Transform air into a
# gas doing +level damage") -- +25 corrosion damage matches base 25 exactly.
#
# The Enigma's Gift (Creo Vim, printed LEVEL 30, "Base 20, +2 Voice"): the
# CrVi Warping Point ladder prints levels 5/10/15 (1/2/3 Warping Points);
# the spell's own prose says "four Warping Points", the ladder's 4th rung.
#
# Wizard's Icy Grip (Perdo Ignem, printed LEVEL 30, "Base 20, +2 Voice"):
# the PeIg preamble states "for every five points the damage exceeds +5,
# add one magnitude" -- levels 5/10 already print +5/+10 damage; +20 damage
# is the same rule three magnitudes past the +5 baseline.
#
# Fog of Confusion (Muto Auram, printed LEVEL 45, "Base 2, +1 Touch, +4
# Year, +4 Size, +1 Imaginem requisite, +1 Rego requisite"): the MuAu
# preamble states "transforming only one property of air generally lowers
# the level by one magnitude" -- muau-3 (base 3) minus that one magnitude
# is exactly 2.
#
# Sense of the Lingering Magic (Intellego Vim, printed LEVEL 30, "Base 10,
# +1 Conc, +3 Hearing") -- ✅ RESOLVED 2026-08-16, was
# LEVEL_NEEDS_RULES_DECISION. Built on invi-G, the InVi General row ("Detect
# the traces of magic of negative magnitude up to the magnitude of the
# guideline used -2"), chosen at level 10: (10 + -2*5)/5 = 0, exactly the
# spell's own "the residue must be of at least zero magnitude" -- not a
# loose paraphrase, the printed threshold. "Even from weak spells" /
# "the presence and power of active spells... It does not grant any
# information apart from the power" both restate the intro paragraph's
# base-detection capability (strength "within a magnitude", no Hermetic-ID/
# Technique-Form/detail bonus bought) rather than needing InVi's numbered
# 1-5 table (which tops out at "detect any active magic" and has no level-10
# row) or an extra "+1 magnitude for Hermetic identification" spend, which
# the spell's own "does not grant any information apart from the power"
# clause explicitly rules out. Verified end-to-end: assertion 1 (Dart,
# `published_spell_import_test.dart`) recomputes 10 -> 30 via
# GeneralEffectFormula and the printed +1 Conc/+3 Hearing tokens and passes.
NUMBERED_OVERRIDES: dict[str, dict] = {
    "lib-muau-infernal-smoke-death": {
        "base_effect_id": "muau-gen",
        "chosen_base_level": 25,
        "modifiers": {},
    },
    "lib-crvi-enigmas-gift": {
        "base_effect_id": "crvi-5a",
        "chosen_base_level": None,
        "modifiers": {"warping-point-burst": ["warping-point-burst-4"]},
    },
    "lib-peig-wizards-icy-grip": {
        "base_effect_id": "peig-5b",
        "chosen_base_level": None,
        "modifiers": {"chill-damage": ["chill-damage-20"]},
    },
    "lib-muau-fog-confusion": {
        "base_effect_id": "muau-3",
        "chosen_base_level": None,
        "modifiers": {"single-property-transformation": ["single-property-transformation-yes"]},
    },
    "lib-invi-sense-lingering-magic": {
        "base_effect_id": "invi-G",
        "chosen_base_level": 10,
        "modifiers": {},
    },
}


# Spells with a genuine catalog gap that isn't derivable from the
# guideline text -- different from NUMBERED_OVERRIDES (resolved) and from
# KNOWN_UNRESOLVABLE (candidates exist, the choice among them is
# ambiguous). See this plan's design spec for why this one specifically
# doesn't resolve. Currently empty: Sense of the Lingering Magic (the only
# entry that ever lived here) moved to NUMBERED_OVERRIDES 2026-08-16 -- see
# that table's comment. The mechanism stays for a future spell that turns
# out to be a genuine rules gap rather than an unspotted derivation.
LEVEL_NEEDS_RULES_DECISION: dict[str, str] = {}


@dataclasses.dataclass
class Report:
    spells: list[dict]
    templates: list[dict]
    exceptions: list[dict]
    blocked: list[tuple[str, str]]
    unresolved: list[str]
    problems: list[str]
    identity: provenance.SourceIdentity
    design_lines: dict[str, str]


def serialize(spells: list[dict]) -> str:
    """Canonical form. Sorting by id is what makes the output stable."""
    ordered = sorted(spells, key=lambda s: s["id"])
    return json.dumps(ordered, indent=2, ensure_ascii=False) + "\n"


def regeneration_failure_message(
    lock: provenance.SourceIdentity | None, current: provenance.SourceIdentity
) -> str:
    """Why does a fresh run disagree with the committed asset?

    Two very different causes, and the wrong guess costs real time: either
    the rulebook moved under a correct asset, or the asset was edited by
    hand. The lock is what tells them apart.
    """
    if not provenance.matches(lock, current):
        return provenance.describe_change(lock, current)
    return (
        "assets/data/spell_library.json is stale or was hand-edited — "
        "re-run `python -m scripts.spell_import.extract_spells --write`"
    )


def run(write: bool = False, accept_source: bool = False) -> Report:
    root = sources.default_root()
    path = sources.resolve_book(sources.DE_TITLE, root)
    lines = sources.read_lines(path)
    parsed, problems = blocks.parse_de(lines)
    catalog = catalog_module.Catalog.load()
    book = ledger_module.Ledger.load()

    design_lines: dict[str, str] = {}

    spells: list[dict] = []
    templates: list[dict] = []
    exception_spells: list[dict] = []
    blocked: list[tuple[str, str]] = []
    unresolved: list[str] = []
    proposals: dict[str, dict] = {}

    for block in parsed:
        if block.name in exceptions_module.EXCEPTION_SPELLS:
            exception_spells.append(emit.build_exception_spell(
                block, exceptions_module.EXCEPTION_SPELLS[block.name]
            ))
            continue

        # HAND_DERIVED is checked before block.design_line, not as a
        # fallback to it. This is defensive, not load-bearing today: all
        # three current entries actually have block.design_line is None --
        # e.g. Hermes' Portal's printed "(Mercurian Ritual)" doesn't match
        # blocks.py's `_DESIGN` regex, so it lands in block.prose, not
        # block.design_line -- and `None or X == X`, so the old
        # `block.design_line or HAND_DERIVED.get(...)` ordering would have
        # worked identically for all three. The reorder guards against a
        # *future* HAND_DERIVED entry for a spell whose printed line is real
        # but wrong (e.g. a stat-block typo) -- for that case, checking the
        # derived value first is the right call. For every spell that is not
        # a HAND_DERIVED key at all, this is a no-op either way: `.get()`
        # returns None and the real printed line is used exactly as before.
        design_text = HAND_DERIVED.get(block.name) or block.design_line
        if design_text is None:
            blocked.append((block.name, "no design line printed"))
            continue

        # The printed line is what the report records; only the parsed copy
        # gains the hand-derived magnitude or typo fix, so import_report.md
        # keeps showing the rulebook's own words.
        parsed_text = design_text
        typo = DESIGN_LINE_TYPOS.get(block.name)
        if typo is not None:
            broken, fixed = typo
            if broken not in parsed_text:
                blocked.append(
                    (block.name, f"design-line typo fix {broken!r} is not in the design line")
                )
                continue
            parsed_text = parsed_text.replace(broken, fixed, 1)

        derived = HAND_DERIVED_ADJUSTMENT.get(block.name)
        if derived is not None:
            magnitude, phrase = derived
            if phrase not in parsed_text:
                blocked.append(
                    (block.name, f"hand-derived adjustment {phrase!r} is not in the design line")
                )
                continue
            parsed_text = parsed_text.replace(phrase, f"+{magnitude} {phrase}", 1)

        try:
            design = designline.parse_design(parsed_text)
        except designline.UnknownToken as error:
            blocked.append((block.name, str(error)))
            continue

        if design.base_level is None or block.printed_level is None:
            spell_id = catalog_module.slug_id(block.technique, block.form, block.name)
            design_lines[spell_id] = design_text
            general_candidates = catalog.general_candidates(block.technique, block.form)

            if not general_candidates:
                # Permanent, not a gap to fill: Perdo Imaginem's and Perdo
                # Mentem's own guideline tables print no General row at all
                # (verified directly against the reviewed Definitive Edition
                # text, 2026-08-16), so Dispel the Phantom Image and Lay to
                # Rest the Haunting Spirit have nothing to resolve to. A
                # catalog row *could* be built from each spell's own prose --
                # and one was, twice (`peme-G`, `inco-gen`) -- but
                # test_general_catalog.GeneralCatalogTest.
                # test_general_entries_match_the_rulebook_bullet_for_bullet
                # (docs/superpowers/plans/2026-08-05-general-base-effects.md)
                # settled that this counts as inventing rulebook content the
                # table does not contain, and both were removed. Adding
                # `peim-gen`/`peme-gen` here would revert that decision.
                #
                # Dispel the Phantom Image's own wording ("whose level you
                # match or exceed on a stress die + the level of your
                # spell") and Lay to Rest the Haunting Spirit's ("loses a
                # number of points from its Might equal to the level of this
                # spell", Perdo Vim's pevi-G3 Might-reduction guideline,
                # Form-narrowed to spirits) are the same recurring per-Form
                # pattern DESIGN_LINE_INCOMPLETE's comment traces above --
                # see there (and its elemental-Might-reduction digression)
                # for why the pattern doesn't change this either.
                blocked.append((block.name, "no General base effect for that Technique/Form"))
                continue

            if spell_id in DESIGN_LINE_INCOMPLETE:
                blocked.append(
                    (block.name, f"design line incomplete: {DESIGN_LINE_INCOMPLETE[spell_id]}")
                )
                continue

            if spell_id in KNOWN_UNRESOLVABLE:
                blocked.append((block.name, f"unresolvable: {KNOWN_UNRESOLVABLE[spell_id]}"))
                continue

            try:
                base_effect_id = book.resolve(spell_id, general_candidates)
            except ledger_module.MissingEntry as error:
                unresolved.append(str(error))
                proposals[spell_id] = {
                    "baseEffectId": "",
                    "candidates": general_candidates,
                    "rationale": "",
                    "_name": block.name,
                    "_line": block.line_no,
                    "_descriptions": [
                        e["description"] for e in catalog.base_effects
                        if e["id"] in general_candidates
                    ],
                }
                continue
            except ledger_module.LedgerError as error:
                unresolved.append(str(error))
                continue

            try:
                templates.append(emit.build_template(
                    block, base_effect_id, catalog, design,
                    realm_by_spell_id=REALM_BY_SPELL_ID,
                ))
            except (designline.UnknownToken, KeyError) as error:
                blocked.append((block.name, str(error)))
            continue

        spell_id = catalog_module.slug_id(block.technique, block.form, block.name)
        design_lines[spell_id] = design_text
        candidates = catalog.candidates(block.technique, block.form, design.base_level)

        if not candidates and spell_id in NUMBERED_OVERRIDES:
            override = NUMBERED_OVERRIDES[spell_id]
            try:
                spells.append(emit.build_spell(
                    block, override["base_effect_id"], catalog, design,
                    realm_by_spell_id=REALM_BY_SPELL_ID,
                    chosen_base_level=override["chosen_base_level"],
                    override_modifiers=override["modifiers"],
                ))
            except (designline.UnknownToken, KeyError) as error:
                blocked.append((block.name, str(error)))
            continue

        if not candidates and spell_id in LEVEL_NEEDS_RULES_DECISION:
            blocked.append(
                (block.name, f"needs a rules decision: {LEVEL_NEEDS_RULES_DECISION[spell_id]}")
            )
            continue

        if not candidates:
            blocked.append((block.name, "no base effect at that Technique/Form/level"))
            continue

        if spell_id in KNOWN_UNRESOLVABLE:
            blocked.append((block.name, f"unresolvable: {KNOWN_UNRESOLVABLE[spell_id]}"))
            continue

        try:
            base_effect_id = book.resolve(spell_id, candidates)
        except ledger_module.MissingEntry as error:
            unresolved.append(str(error))
            proposals[spell_id] = {
                "baseEffectId": "",
                "candidates": candidates,
                "rationale": "",
                "_name": block.name,
                "_line": block.line_no,
                "_descriptions": [
                    e["description"] for e in catalog.base_effects if e["id"] in candidates
                ],
            }
            continue
        except ledger_module.LedgerError as error:
            unresolved.append(str(error))
            continue

        try:
            spells.append(emit.build_spell(
                block, base_effect_id, catalog, design,
                realm_by_spell_id=REALM_BY_SPELL_ID,
                extra_adjustment=COMBINED_BASE_EFFECTS.get(spell_id),
            ))
        except (designline.UnknownToken, KeyError) as error:
            blocked.append((block.name, str(error)))

    if proposals:
        PROPOSALS_PATH.write_text(
            json.dumps(proposals, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )

    identity = provenance.describe(
        sources.DE_TITLE, path, root, parsed=len(parsed), imported=len(spells)
    )

    if write and not unresolved and not problems:
        lock = provenance.load()
        fresh = serialize(spells)
        committed = LIBRARY_PATH.read_text(encoding="utf-8") if LIBRARY_PATH.is_file() else ""
        would_change = fresh != committed

        # An absent lock refuses unconditionally: nothing can be attested, so
        # "the asset happens to match" is not a reason to proceed quietly. A
        # merely-moved source refuses only when it would actually rewrite the
        # asset, since otherwise --write is a no-op anyway.
        if not provenance.matches(lock, identity) and not accept_source:
            if would_change or lock is None:
                raise SourceMoved(provenance.describe_change(lock, identity))

        if would_change:
            LIBRARY_PATH.write_text(fresh, encoding="utf-8")

        # Templates go through the same serializer, so they get the same
        # id-sorted, byte-stable output the idempotency test relies on. The
        # SourceMoved guard above covers both assets: it is checked before
        # either write, and a moved rulebook is a reason to rewrite neither.
        fresh_templates = serialize(templates)
        if TEMPLATES_PATH.is_file():
            committed_templates = TEMPLATES_PATH.read_text(encoding="utf-8")
        else:
            committed_templates = ""
        if fresh_templates != committed_templates:
            TEMPLATES_PATH.write_text(fresh_templates, encoding="utf-8")

        fresh_exceptions = serialize(exception_spells)
        if EXCEPTIONS_PATH.is_file():
            committed_exceptions = EXCEPTIONS_PATH.read_text(encoding="utf-8")
        else:
            committed_exceptions = ""
        if fresh_exceptions != committed_exceptions:
            EXCEPTIONS_PATH.write_text(fresh_exceptions, encoding="utf-8")

        if accept_source:
            if would_change:
                old = json.loads(committed) if committed else []
                previous = None
                if lock is not None and lock.rulebook is not None:
                    previous = report_module.old_design_lines(
                        root, lock.rulebook.commit, lock.path
                    )
                REPORT_PATH.write_text(
                    report_module.render(
                        report_module.diff_assets(old, spells),
                        lock, identity,
                        imported=len(spells), blocked=len(blocked), unresolved=len(unresolved),
                        old_design_lines=previous, new_design_lines=design_lines,
                    ),
                    encoding="utf-8",
                )
            provenance.write(identity)

    return Report(
        spells=spells, templates=templates, exceptions=exception_spells,
        blocked=blocked, unresolved=unresolved,
        problems=problems, identity=identity, design_lines=design_lines,
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true", help="rewrite spell_library.json")
    parser.add_argument(
        "--accept-source", action="store_true",
        help="adopt a changed rulebook: rewrite source.lock and the change report",
    )
    parser.add_argument(
        "--show-blocked", action="store_true",
        help="list each blocked spell and its reason",
    )
    args = parser.parse_args(argv)

    if args.accept_source and not args.write:
        parser.error("--accept-source is only meaningful with --write")

    try:
        report = run(write=args.write, accept_source=args.accept_source)
    except SourceMoved as error:
        print(error, file=sys.stderr)
        return 1

    print(f"imported : {len(report.spells)}")
    print(f"templates: {len(report.templates)}")
    print(f"exceptions: {len(report.exceptions)}")
    print(f"blocked  : {len(report.blocked)}")
    print(f"unresolved: {len(report.unresolved)}")

    if args.show_blocked and report.blocked:
        print("\nBlocked spells by reason:")
        # Group by reason for better readability
        by_reason: dict[str, list[str]] = {}
        for name, reason in report.blocked:
            if reason not in by_reason:
                by_reason[reason] = []
            by_reason[reason].append(name)

        for reason in sorted(by_reason.keys()):
            spells = sorted(by_reason[reason])
            print(f"\n{reason} ({len(spells)}):")
            for spell in spells:
                print(f"  - {spell}")

    for problem in report.problems:
        print(f"  PARSE  {problem}", file=sys.stderr)
    for message in report.unresolved[:20]:
        print(f"  LEDGER {message}", file=sys.stderr)
    if report.unresolved:
        print(f"\nwrote {PROPOSALS_PATH} — copy decisions into resolutions.json by hand",
              file=sys.stderr)

    if report.problems or report.unresolved:
        return 1
    if args.write:
        print(f"wrote {LIBRARY_PATH}")
        print(f"wrote {TEMPLATES_PATH}")
        print(f"wrote {EXCEPTIONS_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
