"""Tokenize a spell's design line: `(Base 15, +1 Touch, +2 Group)`.

The Definitive Edition uses 104 distinct token shapes across 360 spells. Only
the ones this module models can be imported; everything else raises
UnknownToken, which is how a blocked spell announces itself. A tokenizer that
skipped what it did not recognise would import the spell with a missing
magnitude and a level that no longer matches — and assertion 1 would catch it
only by luck, since two dropped magnitudes can cancel.
"""
import dataclasses
import re

_PARENTHETICAL = re.compile(r"\([^)]*\)")
_BASE = re.compile(r"^Base(?:\s+level)?:?\s+(?P<level>\d+)")
# "Base Effect" (Tie the Threads That Bind, HoH:MC) alongside the core
# rulebook's "Base effect". Spelled out rather than re.IGNORECASE, which
# would also loosen the `Base` and `As ward guideline` alternatives this
# pattern shares -- "BASE" and "as WARD guideline" are not corpus wordings.
_BASE_GENERAL = re.compile(
    r"^Base\s+([Ee]ffect|[Ss]pell)\b|^Base$|^As\s+ward\s+guideline$")
_TOKEN = re.compile(r"^(?P<sign>[+-])\s*(?P<magnitude>\d+)\s+(?P<label>.+)$")
_REQUISITE = re.compile(r"^(?P<art>[A-Z][a-z]+)\s+requisites?$")
# A handful of design lines spell the requisite cost as "<Technique> effect"
# instead of "<Technique> requisite(s)", e.g. "+1 Rego effect" alongside a
# "Req: Rego" stat-line entry (Circling Winds of Protection, Piercing Shaft
# of Wood, Dream of the Mind That Sits). Restricted to the five canonical
# Technique names so it can't accidentally swallow unrelated "<Word> effect"
# phrases such as "fancy effect" or "additional effect".
_REQUISITE_EFFECT = re.compile(
    r"^(?P<art>Creo|Intellego|Muto|Perdo|Rego)\s+effect$"
)
_FREE_REQUISITE = re.compile(
    r"^(?:no\s+(?:cost|addition|increase)\s+for\s+requisites?"
    r"|requisites?\s+free"
    r"|requisites?\s+is\s+free"
    r"|no\s+cost\s+for\s+(?:Creo|Intellego|Muto|Perdo|Rego)\s+effect)$",
    re.IGNORECASE,
)

# A couple of design lines cost a requisite's magnitude in prose that names
# the Req: art but not in _REQUISITE's "<Art> requisite(s)" shape -- a
# trailing justification after the art name (Obliteration of the Metallic
# Barrier: "Rego to fling the fragments away") or the art name buried
# mid-phrase (Phantasmal Fire: "for light from Ignem requisite"). A closed
# allow-list on purpose, the same discipline as ADJUSTMENT_LABELS: a loose
# "contains an Art name" match would misread ordinary prose that happens to
# mention an Art in passing as a requisite cost.
REQUISITE_LABEL_ARTS: dict[str, str] = {
    "Rego to fling the fragments away": "Rego",
    "for light from Ignem requisite": "Ignem",
}

# Design lines that restate no art at all -- "+1 requisite" (The Eye of the
# Sage), "+1 extra effect from requisite" (Curse of the Ravenous Swarm) --
# because the Req: line already names it. This module sees only the
# design-line text, never the Req: line, so it cannot resolve which art the
# magnitude belongs to; it records an empty label and leaves the resolution
# to emit.py, which has the stat line and can safely resolve a bare
# requisite only when the spell declares exactly one. A closed set rather
# than a looser pattern, same discipline as REQUISITE_LABEL_ARTS: "extra
# effect from requisite" is a verified corpus wording, not a guess at a
# general "mentions requisite" shape.
_BARE_REQUISITE_LABELS = frozenset({
    "requisite",
    "requisites",
    "extra effect from requisite",
    # Embrace of Boethius (HoH:MC) charges "+2 necessary requisites" against
    # its two declared Req: arts. A closed entry rather than a pattern, the
    # same discipline as the rest of this set: the phrasing occurs exactly
    # once across all 54 books in the corpus.
    "necessary requisites",
})

# Range, Duration and Target names as the design lines spell them, mapped to
# the `name` field in assets/data/parameters.json.
PARAMETER_LABELS = {
    "Touch": "Touch", "Eye": "Eye", "Voice": "Voice", "Sight": "Sight",
    "Arc": "Arcane Connection", "Arcane Connection": "Arcane Connection",
    "Per": "Personal", "Personal": "Personal",
    "Mom": "Momentary", "Momentary": "Momentary",
    "Diam": "Diameter", "Diameter": "Diameter", "Dia": "Diameter",
    "Conc": "Concentration", "Concentration": "Concentration",
    "Sun": "Sun", "Ring": "Ring", "Moon": "Moon", "Year": "Year",
    "Ind": "Individual", "Individual": "Individual",
    "Part": "Part", "Group": "Group", "Room": "Room",
    "Circle": "Circle", "Structure": "Structure", "Str": "Structure",
    "Bound": "Boundary", "Boundary": "Boundary",
    "Taste": "Taste", "Smell": "Smell", "Hearing": "Hearing", "Vision": "Vision",
    # Sensory Magic Targets (HoH:MC, catalog rows added by todo item 64).
    # The Targets landed in parameters.json without their design-line labels,
    # which blocked all seven spells that use one.
    "Flavor": "Flavor", "Texture": "Texture", "Scent": "Scent",
    "Sound": "Sound", "Spectacle": "Spectacle",
    # "Eve" is a one-letter OCR/typo slip of "Eye" that recurs in the DE text:
    # "Perception of the Conflicting Motives" has R: Eve in its stat line, and
    # "Aura of Rightful Authority" has R: Eye in its stat line but "+1 Eve" in
    # its design line, i.e. both spellings are used for the same spell.
    "Eve": "Eye",
}

# Tokens that map onto entries in assets/data/modifiers.json. The label is
# resolved to a modifier option in catalog.py, not here.
MODIFIER_LABELS = {
    "size", "Size", "unnatural", "stone", "metal",
    # Ward against Heat and Flames (Rego Ignem) -- see emit.py's
    # rego-ignem-fire-intensity handling for the mapping.
    "for up to +15 damage",
    # "metal/gems" (Stone to Falling Dust, Perdo Terram) is the design lines'
    # combined phrasing for perdo-terram-material's two magnitude-2 options,
    # Base metal and Gemstone -- the spell costs +2 either way, which is why
    # the rulebook didn't bother distinguishing them. See emit.py's Terram
    # material handling for which option this resolves to and why.
    "metal/gems",
    "changing image", "intricacy",
    # Creo Auram's own guideline table (Definitive Edition, Creo Auram
    # Guidelines, Notes row) spells the same +2 tier "very unnatural";
    # "highly unnatural" (Wings of the Soaring Wind) is the one design line
    # that uses the alternate wording. See emit.py's unnatural-label handling.
    "highly unnatural",
    # Creo Imaginem complexity factors (assets/data/modifiers.json id
    # "crim-complexity"): "move at/under your command" is the design lines'
    # phrasing of crim-directed-image ("Image moves ... at your direction as
    # you concentrate", magnitude 2 — confirmed against all three spells
    # that use it: Phantasmal Animal, Phantasm of the Human Form, Haunt of
    # the Living Ghost, all Creo Imaginem at magnitude +2). "intelligible
    # speech" is crim-sensory-complexity ("clear words instead of noise",
    # magnitude 1 — Phantasm of the Talking Head, Creo Imaginem at +1).
    "move at your command", "move under your command", "intelligible speech",
    # Rego Imaginem complexity factors (id "reim-complexity"), each confirmed
    # against the spell(s) that use it, Rego Imaginem at the catalog's
    # magnitude. "moved image matches changes" -> reim-moved-image-matches
    # (+1, Wizard's Sidestep). "additional senses"/"additional sense" (both
    # spellings occur) -> reim-additional-senses (+1, Confusion of the Insane
    # Vibrations; Image from the Wizard Torn). "moving image" -> reim-
    # changing-image (+1, Image from the Wizard Torn — same "the image
    # moves" concept as "changing image" above, just worded differently).
    "moved image matches changes", "additional senses", "additional sense",
    "moving image",
    # "changing image" itself, confirmed against both Techniques that print
    # it. Perdo Imaginem's preamble: "Destroying changing images is more
    # difficult — add one level of magnitude to spells that do so" ->
    # peim-changing-image (+1, Veil of Invisibility; Silence of the
    # Smothered Sound). Rego Imaginem's preamble: "it is slightly harder to
    # affect changing images. Add one level of magnitude to spells that do
    # so" -> reim-changing-image, the same option "moving image" above
    # reaches (+1, The Captive Voice; Wizard's Sidestep).

    # Rego transport-distance ladder (modifiers.json id
    # "rego-transport-distance", scoped to rete-4/rehe-10b/reig-3c/rean-10b/
    # reaq-4b). Bare "distance" is deliberately NOT here -- it names no real
    # option (the modifier's own option table has no entry for it), so it
    # should keep failing at the tokenizer rather than succeed here and fail
    # one layer deeper in emit.py with a near-identical message. See todo
    # item 45.
    "5 paces", "50 paces", "500 paces", "1 league", "7 leagues",
    "arcane connection",
    # The three remaining unmodelled mechanisms from todo item 24's original
    # 21, each a real Hermetic mechanic rather than a one-off adjustment.
    # "for not needing to gesture" (Black Whisper, Perdo Mentem 40) and "for
    # no words" (The Kiss of Death, Perdo Corpus 45) buy off the still/silent
    # casting requirement the same way Quiet Casting/Still Casting Mastery
    # do at the Mastery-ability layer, but built permanently into the
    # spell's own level -- confirmed globally-scoped (not tied to either
    # spell's own Technique/Form) since nothing in either citation ties the
    # cost to Perdo, Mentem or Corpus. "Techniques and Forms" (Sight of the
    # Active Magics, Intellego Vim 40) is unrelated: it reveals which
    # Technique/Form is active in a detected magical aura, on top of the
    # base detection effect Sense of the Lingering Magic already covers --
    # scoped to Intellego Vim, not global. See emit.py's _MODIFIER_OPTIONS
    # for the mapping to modifiers.json's "no-gestures"/"no-words"/
    # "invi-techniques-and-forms" entries.
    "for not needing to gesture", "for no words", "Techniques and Forms",
}


class UnknownToken(ValueError):
    """A design-line token this importer does not model.

    Not a bug — the expected outcome for the ad-hoc, per-spell design-line
    prose this importer deliberately does not model (todo items 24, 25, 26,
    28, 18, 19 and 4). A census against the real Definitive Edition corpus
    found 36 such spells blocked on 34 distinct unrecognised tokens, after
    the recognised vocabulary was extended to cover every genuine
    parameter/modifier alias the census turned up. ELABORATE_LABELS and
    ADJUSTMENT_LABELS below then cleared 15 of those 36, leaving 21 spells
    blocked on 21 distinct tokens — every one of them a real, unmodelled
    mechanism (metal/gems, damage scaling, bare requisites, Techniques and
    Forms), which is exactly why those two tables stay closed.
    """


@dataclasses.dataclass(frozen=True)
class Token:
    magnitude: int
    label: str
    kind: str
    # Only kind="adjustment" sets this: the raw token text with its leading
    # "+N "/"-N " removed, brackets included. The bracket is not decoration
    # for an adjustment — "+2 Special (based on Concentration)" carries all
    # its meaning there — so the note is taken before parenthetical stripping.
    note: str | None = None


@dataclasses.dataclass(frozen=True)
class Design:
    base_level: int | None
    tokens: list[Token]


# Eight spells give the same reason -- "this effect is more elaborate than the
# guideline describes" -- in five wordings. Each maps to the `elaborate-effect`
# modifier; the magnitude comes from the printed token, never from arithmetic
# on the printed level.
ELABORATE_LABELS = frozenset({
    "fancy effect",
    "complex effect",
    "for special effect",
    "additional effect",
    "elaborate design",
})

# Bare "complexity", as distinct from the Imaginem sensory-complexity factors
# in MODIFIER_LABELS. Core Rules 12204 makes this a general judgement
# magnitude -- "this normally adds magnitudes to the spell level to account
# for the complexity" -- and the corpus bears that out: 23 tokens across 9
# books and 12 Technique/Form pairs, none of them Imaginem. Both spellings
# occur in print.
COMPLEXITY_LABELS = frozenset({"complexity", "Complexity"})

# Closed allow-list of per-spell adjustments, matched exactly against the
# token's *note* -- the raw text with its "+N "/"-N " prefix removed, brackets
# and all. Anything not here keeps blocking its spell: absorbing unknown
# "+N <prose>" tokens would import real mechanisms (metal/gems, damage
# scaling, requisites) with a correct computed level and wrong modelling,
# invisible to the level test.
#
# Matching the note rather than the parenthetical-stripped label is what keeps
# this an allow-list. A bare "Special" entry would absorb any
# "+N Special (<anything>)", and the corpus already hides two different
# mechanisms behind that one word: "(based on Concentration)" is a nonstandard
# Duration, "(equivalent to Boundary)" a nonstandard Target. The spec's table
# lists these tokens with their brackets, and "matched exactly" is only true
# of the bracketed form.
#
# "Special (equivalent to Boundary)" does match its corpus token (The
# Bountiful Feast), but does not unblock that spell: the same design line has
# unbalanced brackets, so the later "+1 Size (for a total of ..." token never
# closes and blocks it anyway. Listed regardless -- it is a real corpus token
# in the spec's table, and an entry whose spell blocks downstream is worth
# more than a silent omission.
ADJUSTMENT_LABELS = frozenset({
    "for shape and primary motivation",
    "see through intervening material",
    "to allow various shapes",
    "for slightly unnatural control",
    "because the spell allows growth or two kinds of shrinking",
    "because the old limb is needed",
    "Special (based on Concentration)",
    "Special (equivalent to Boundary)",
    "Special based on Mom",
    # The one corpus adjustment printed with no number at all: The Shadow of
    # Human Life's "(..., +6 Mentem requisite, for a very elaborate effect)".
    # It only ever reaches this tokenizer with a magnitude already attached,
    # supplied by extract_spells.HAND_DERIVED_ADJUSTMENT -- listing it here is
    # what lets that synthesised "+5 for a very elaborate effect" resolve as an
    # adjustment rather than an unknown token. A bare, numberless occurrence
    # still fails _TOKEN and still blocks its spell.
    "for a very elaborate effect",
})

# A handful of design lines tack on a bare explanatory clause after a costed
# token -- no leading sign, no magnitude of its own -- continuing what the
# previous token already paid for rather than declaring a new mechanism:
# "+1 additional effect, changing the water to ice" (Ice of Drowning), "+1
# Conc, mist is a purely cosmetic effect and thus is free" (Frosty Breath of
# the Spoken Lie), "+3 size, so that the whole stream floods" (Deluge of
# Rushing and Dashing). A closed allow-list on purpose, the same discipline as
# ADJUSTMENT_LABELS/ELABORATE_LABELS: a blanket "any unsigned clause is free"
# rule would silently absorb an unverified, genuinely-costed mechanism worded
# the same way -- each entry here is checked against its own spell's printed
# level before being added, same as every other allow-list in this module.
#
# Break the Oncoming Wave prints its continuation as three comma-separated
# clauses, not one -- "+1 Conc, ward, so the target is the warded Individual,
# not the water" -- each entered separately below, since this tokenizer
# checks one comma-split segment at a time and has no notion of "the rest of
# the sentence".
#
# Ball of Abysmal Flame's continuation follows a semicolon rather than a
# comma ("+2 Voice; the ball appearing to shoot from your hand is a cosmetic
# effect") -- `_split_parts` treats `;` as an equivalent top-level boundary
# (see its docstring), so by the time this allow-list is checked the clause
# is just another unsigned, no-label part like the others here.
#
# Three ritual-justification clauses (item 18): "ritual because it has a
# really major effect" (Curse of the Ravenous Swarm), "ritual for large
# effect" (Neptune's Wrath), "ritual because of spectacular effect" (Breath
# of the Open Sky). Each is the storyguide's stated reason the spell is a
# Ritual, printed with no number of its own; nothing in extract_spells.py
# gates on Ritual correctness (see item 18), and each spell's `Ritual` marker
# in its own stat line -- not this clause -- is what the importer reads for
# that. Curse of the Ravenous Swarm's design line also carries its own
# swarm-size clause upstream of the ritual one, "for a swarm weighing as much
# as one thousand pigs" -- likewise no magnitude of its own, continuing the
# "+2 size" token just before it.
TRAILING_CONTINUATION_LABELS = frozenset({
    "changing the water to ice",
    "mist is a purely cosmetic effect and thus is free",
    "so that the whole stream floods",
    "ward",
    "so the target is the warded Individual",
    "not the water",
    "the ball appearing to shoot from your hand is a cosmetic effect",
    "for a swarm weighing as much as one thousand pigs",
    "ritual because it has a really major effect",
    "ritual for large effect",
    "ritual because of spectacular effect",
})

_BARE_MAGNITUDE = re.compile(r"^(?P<sign>[+-])\s*(?P<magnitude>\d+)$")


def _merge_comma_split_magnitudes(
    parts: list[tuple[str, str]],
) -> list[tuple[str, str]]:
    """Rejoin a magnitude that `_split_parts` separated from its own label.

    "+2, highly unnatural, +1 Rego requisite" (Wings of the Soaring Wind)
    prints a comma between the magnitude and the label it belongs to, where
    every other design line in the corpus uses a space. `_split_parts`
    correctly treats that comma as a top-level boundary, producing a bare
    "+2" that can never match `_TOKEN` on its own (it requires a label) and a
    label-only "highly unnatural" that can never match it either (it requires
    a sign). Neither shape can otherwise succeed, so merging an unlabelled
    magnitude with the very next part -- when that part carries no sign of
    its own -- can never turn a token that should fail into one that wrongly
    succeeds; it only lets this punctuation quirk reach the same
    label-recognition check every other token goes through.
    """
    merged: list[tuple[str, str]] = []
    index = 0
    while index < len(parts):
        raw, stripped = parts[index]
        has_next = index + 1 < len(parts)
        if has_next and _BARE_MAGNITUDE.match(stripped):
            next_raw, next_stripped = parts[index + 1]
            if next_stripped[:1] not in "+-":
                merged.append((f"{raw} {next_raw}", f"{stripped} {next_stripped}"))
                index += 2
                continue
        merged.append((raw, stripped))
        index += 1
    return merged


def _split_parts(text: str) -> list[tuple[str, str]]:
    """Split on top-level commas, periods and semicolons, keeping raw and
    stripped forms.

    Parentheticals must survive splitting for two reasons: a bracketed aside
    can itself contain a comma ("+1 Size (for a total of +4 Size, including
    ...)"), which the old blanket strip-then-split turned into two bogus
    tokens; and for adjustment tokens the aside IS the content -- "+2 Special
    (based on Concentration)" carries all its meaning in the bracket.

    Semicolon joins `,`/`.` as a boundary character for the same reason: one
    design line in the whole corpus uses it as the magnitude/prose separator
    where every other spell uses a comma -- "(Base 25, +2 Voice; the ball
    appearing to shoot from your hand is a cosmetic effect)" (Ball of
    Abysmal Flame). Checked against every design line in Chapter 9: it is the
    only one containing a semicolon at all, so there is no other corpus usage
    this split could misinterpret. (The rulebook's `**Range: X; Duration:
    Y;**`-style guideline headers also use `;`, but those never reach
    `_split_parts` -- it parses only text captured by blocks.py's `_DESIGN`
    line match, not the guideline preamble.)

    Returns (raw, stripped) pairs. Tokenising reads `stripped`; adjustment
    notes read `raw`.
    """
    parts: list[str] = []
    depth = 0
    current: list[str] = []

    for index, char in enumerate(text):
        if char == "(":
            depth += 1
        elif char == ")":
            depth = max(0, depth - 1)

        at_boundary = char in ",.;" and depth == 0 and (
            index + 1 >= len(text) or text[index + 1].isspace()
        )
        if at_boundary:
            parts.append("".join(current))
            current = []
        else:
            current.append(char)

    parts.append("".join(current))

    result = []
    for part in parts:
        raw = part.strip()
        if not raw:
            continue
        result.append((raw, _PARENTHETICAL.sub("", raw).strip()))
    return result


def parse_design(text: str) -> Design:
    inner = text.strip()
    if inner.startswith("("):
        inner = inner[1:]
    if inner.endswith(")"):
        inner = inner[:-1]

    parts = _split_parts(inner)
    if not parts:
        raise UnknownToken(f"empty design line: {text!r}")

    head = parts[0][1]
    base_match = _BASE.match(head)
    if base_match:
        base_level: int | None = int(base_match.group("level"))
    elif _BASE_GENERAL.match(head):
        base_level = None
    else:
        raise UnknownToken(f"unrecognised base term {head!r} in {text!r}")

    tokens: list[Token] = []
    for raw, part in _merge_comma_split_magnitudes(parts[1:]):
        if _FREE_REQUISITE.match(part):
            tokens.append(Token(magnitude=0, label="free", kind="requisite"))
            continue

        token_match = _TOKEN.match(part)
        if not token_match:
            if part in TRAILING_CONTINUATION_LABELS and tokens:
                # No magnitude of its own -- it continues whatever token
                # came before it, so it contributes nothing further.
                continue
            raise UnknownToken(f"unrecognised token {part!r} in {text!r}")

        magnitude = int(token_match.group("magnitude"))
        if token_match.group("sign") == "-":
            magnitude = -magnitude
        label = token_match.group("label").strip()

        # The elaborate wordings carry no bracketed mechanism, so they match on
        # the stripped label — that is what lets "+1 fancy effect (the spell
        # effectively keeps being cast...)" resolve. Adjustments must not:
        # see ADJUSTMENT_LABELS.
        if label in ELABORATE_LABELS:
            tokens.append(Token(magnitude, label, "elaborate"))
            continue

        if label in COMPLEXITY_LABELS:
            tokens.append(Token(magnitude, label, "complexity"))
            continue

        raw_match = _TOKEN.match(raw)
        note = raw_match.group("label").strip() if raw_match else raw
        if note in ADJUSTMENT_LABELS:
            # label is the note here, so the token records the allow-list key
            # it actually matched rather than a truncated form of it.
            tokens.append(Token(magnitude, note, "adjustment", note=note))
            continue

        requisite_match = _REQUISITE.match(label) or _REQUISITE_EFFECT.match(label)
        if requisite_match:
            tokens.append(Token(magnitude, requisite_match.group("art"), "requisite"))
        elif label in REQUISITE_LABEL_ARTS:
            tokens.append(Token(magnitude, REQUISITE_LABEL_ARTS[label], "requisite"))
        elif label in _BARE_REQUISITE_LABELS:
            tokens.append(Token(magnitude, "", "requisite"))
        elif label in PARAMETER_LABELS:
            tokens.append(Token(magnitude, PARAMETER_LABELS[label], "parameter"))
        elif label in MODIFIER_LABELS:
            tokens.append(Token(magnitude, label, "modifier"))
        else:
            raise UnknownToken(f"unrecognised token {part!r} in {text!r}")

    return Design(base_level=base_level, tokens=tokens)
