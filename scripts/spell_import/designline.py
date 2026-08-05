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
_BASE_GENERAL = re.compile(r"^Base\s+(effect|spell)\b|^Base$")
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
    "changing image", "intricacy", "complexity",
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


def _split_parts(text: str) -> list[tuple[str, str]]:
    """Split on top-level commas and periods, keeping raw and stripped forms.

    Parentheticals must survive splitting for two reasons: a bracketed aside
    can itself contain a comma ("+1 Size (for a total of +4 Size, including
    ...)"), which the old blanket strip-then-split turned into two bogus
    tokens; and for adjustment tokens the aside IS the content -- "+2 Special
    (based on Concentration)" carries all its meaning in the bracket.

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

        at_boundary = char in ",." and depth == 0 and (
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
    for raw, part in parts[1:]:
        if _FREE_REQUISITE.match(part):
            tokens.append(Token(magnitude=0, label="free", kind="requisite"))
            continue

        token_match = _TOKEN.match(part)
        if not token_match:
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
        elif label in PARAMETER_LABELS:
            tokens.append(Token(magnitude, PARAMETER_LABELS[label], "parameter"))
        elif label in MODIFIER_LABELS:
            tokens.append(Token(magnitude, label, "modifier"))
        else:
            raise UnknownToken(f"unrecognised token {part!r} in {text!r}")

    return Design(base_level=base_level, tokens=tokens)
