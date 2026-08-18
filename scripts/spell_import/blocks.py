"""Assemble Definitive Edition spell blocks around their stat lines.

Structure in the reviewed DE:

    ### Creo Animal Spells          <- Technique and Form
    #### LEVEL 20                   <- printed level (or "#### GENERAL")
    ##### Soothe Pains of the Beast <- name
    R: Touch, D: Mom, T: Ind, Ritual
    <prose...>
    (Base level 15, +1 Touch)       <- design line

The stat line is the anchor and the `##### ` heading directly above it is the
discriminator. 385 lines in the book match the stat-line predicate; exactly
360 have a name heading above them, and every name heading in the spell
chapter has a stat line beneath it. The other 25 are creature and elemental
powers, which carry a `*Crush*, 0 points, Init equal to (Qik-2), Terram` line
instead of a heading.
"""
import dataclasses
import re

from . import statline

# Match "### Creo Terram Guidelines" as readily as "### Creo Animal Spells".
# Keying off the "Spells" suffix silently misfiles four Creo Terram spells.
_SECTION = re.compile(
    r"^###\s+(?P<technique>Creo|Intellego|Muto|Perdo|Rego)\s+"
    r"(?P<form>Animal|Aquam|Auram|Corpus|Herbam|Ignem|Imaginem|Mentem|Terram|Vim)\b"
)
_LEVEL = re.compile(r"^####\s+(?:\*{0,2})(?:LEVEL\s+(?P<level>\d+)|(?P<general>GENERAL))")
_NAME = re.compile(r"^#####\s+(?P<name>.+?)\s*$")
_DESIGN = re.compile(r"^\(\s*(?:Base\b|As ward guideline\s*\))")
# A requisite the book prints on its own line, directly beneath the stat
# line, rather than inline within it. See
# docs/superpowers/specs/2026-08-09-importer-requisite-continuation-design.md.
_REQ_CONTINUATION = re.compile(r"^Req(?:uisites?)?:")


def _normalize_stat_line(line: str) -> str:
    """Fix common formatting issues in stat lines.

    Some lines have missing commas between fields, e.g.:
      R: Voice, D: Conc T: Ind -> R: Voice, D: Conc, T: Ind
    """
    # Add missing comma before T: after duration (D: WORD T: -> D: WORD, T:)
    line = re.sub(r'(\bD:\s+[A-Za-z.]+)\s+(\bT:)', r'\1, \2', line)
    # Add missing comma before D: after range (R: WORD D: -> R: WORD, D:)
    line = re.sub(r'(\bR:\s+[A-Za-z]+)\s+(\bD:)', r'\1, \2', line)
    return line


@dataclasses.dataclass
class SpellBlock:
    name: str
    technique: str
    form: str
    printed_level: int | None
    stat: statline.StatLine
    prose: str
    design_line: str | None
    line_no: int


def parse_de(lines: list[str]) -> tuple[list[SpellBlock], list[str]]:
    problems: list[str] = []
    found: list[SpellBlock] = []

    technique = form = None
    level: int | None = None
    is_general = False
    name: str | None = None
    name_line = -1

    for index, raw in enumerate(lines):
        cleaned = statline.strip_markup(raw)

        section = _SECTION.match(cleaned)
        if section:
            technique = section.group("technique")
            form = section.group("form")
            continue

        level_heading = _LEVEL.match(cleaned)
        if level_heading:
            is_general = level_heading.group("general") is not None
            level = None if is_general else int(level_heading.group("level"))
            continue

        name_heading = _NAME.match(cleaned)
        if name_heading:
            name = name_heading.group("name")
            name_line = index
            continue

        if statline.is_damaged_statline(raw):
            # Only report damaged stat lines that have a name heading (spells),
            # not creature/faerie powers or lines outside the spell chapter
            if name is not None and index == name_line + 1:
                problems.append(f"line {index + 1}: damaged stat line {raw.strip()!r}")
            continue

        if not statline.is_statline(raw):
            continue

        # A stat line whose preceding non-blank line is not a name heading is a
        # creature or faerie power, not a spell.
        if name is None or index != name_line + 1:
            continue

        if technique is None or form is None:
            problems.append(f"line {index + 1}: {name!r} has no Technique/Form section")
            name = None
            continue

        normalized = _normalize_stat_line(raw)
        folded = statline.strip_markup(normalized)

        # Look past any blank lines for a Req: continuation line and fold
        # it into the stat line before parsing, so parse_statline keeps
        # seeing one logical line exactly as it always has. If none is
        # found, prose_start stays at index + 1 and behaviour is identical
        # to before this fold existed.
        prose_start = index + 1
        cursor = prose_start
        while cursor < len(lines) and not statline.strip_markup(lines[cursor]):
            cursor += 1
        if cursor < len(lines):
            candidate = statline.strip_markup(lines[cursor])
            if _REQ_CONTINUATION.match(candidate):
                folded = f"{folded}, {candidate}"
                prose_start = cursor + 1

        try:
            stat = statline.parse_statline(folded)
        except ValueError as e:
            problems.append(f"line {index + 1}: {e}")
            name = None
            continue

        prose_lines: list[str] = []
        design: str | None = None
        cursor = prose_start
        while cursor < len(lines):
            candidate = statline.strip_markup(lines[cursor])
            if _NAME.match(candidate) or _SECTION.match(candidate) or _LEVEL.match(candidate):
                break
            if _DESIGN.match(candidate):
                design = candidate
                break
            if candidate:
                prose_lines.append(candidate)
            cursor += 1

        found.append(SpellBlock(
            name=name,
            technique=technique,
            form=form,
            printed_level=level,
            stat=stat,
            prose=" ".join(prose_lines),
            design_line=design,
            line_no=index + 1,
        ))
        name = None

    return found, problems


# The inline anchor: "PeAn 20" or "MuVi Gen" on its own line, directly above
# the stat line. Unlike the Definitive Edition's "### Creo Animal Spells" +
# "#### LEVEL 20" pair, this one line carries Technique, Form and printed
# level together, so parse_inline needs no section state at all.
_INLINE_ANCHOR = re.compile(
    r"^(?P<technique>Cr|In|Mu|Pe|Re)(?P<form>An|Aq|Au|Co|He|Ig|Im|Me|Te|Vi)\s+"
    r"(?:(?P<level>\d+)|(?P<general>Gen))\s*$"
)
_HEADING = re.compile(r"^#{1,6}\s")
# A name printed as bold text rather than a heading. Ball of Abysmal Music is
# the only HoH:MC spell headed this way. The `$` anchor is what keeps this
# from swallowing "**Dutiful Movement:** The automaton can walk..." -- a bold
# run followed by prose is a labelled paragraph, not a spell name.
_BOLD_NAME = re.compile(r"^\*\*(?P<name>.+?)\*\*\s*$")

_TECHNIQUE_NAMES = {
    "Cr": "Creo", "In": "Intellego", "Mu": "Muto", "Pe": "Perdo", "Re": "Rego",
}
_FORM_NAMES = {
    "An": "Animal", "Aq": "Aquam", "Au": "Auram", "Co": "Corpus",
    "He": "Herbam", "Ig": "Ignem", "Im": "Imaginem", "Me": "Mentem",
    "Te": "Terram", "Vi": "Vim",
}


def _inline_anchor(lines: list[str], index: int):
    """The `TeFo Level` match at `index`, or None."""
    if index < 0:
        return None
    return _INLINE_ANCHOR.match(statline.strip_markup(lines[index]))


def _inline_name_above(lines: list[str], start: int) -> str | None:
    """The spell name at or above `start`, skipping blank lines.

    Returns None as soon as a non-blank line that is not a name is reached,
    so ordinary prose above an anchor cannot be mistaken for a heading. The
    blank-skipping is not defensive: Perceive the Change has a blank
    blockquote line between its heading and its anchor, and Revenge of the
    Bitten Toad has none.
    """
    cursor = start
    while cursor >= 0:
        quoted = statline.strip_quote(lines[cursor])
        if not quoted.strip():
            cursor -= 1
            continue
        cleaned = statline.strip_markup(lines[cursor])
        # Any heading level, not just `#####`: parse_de's _NAME is specific to
        # the Definitive Edition's own nesting, and the supplements do not
        # share it.
        if _HEADING.match(cleaned):
            return _HEADING.sub("", cleaned).strip()
        bold = _BOLD_NAME.match(quoted)
        if bold is not None:
            return statline.strip_markup(bold.group("name"))
        return None
    return None


def parse_inline(lines: list[str]) -> tuple[list[SpellBlock], list[str]]:
    """Assemble spell blocks anchored on an inline `TeFo Level` line.

    Used by supplements rather than the Definitive Edition. The anchor is the
    stat line, as always; what discriminates a spell from a creature power
    here is the `TeFo Level` line directly above it, with the name above that
    as either a heading or a bold run.

    A stat line with no anchor above it is skipped in silence, exactly as
    parse_de skips creature and elemental powers. Across the corpus those
    unanchored blocks are overwhelmingly enchanted-device effects and NPC
    spell lists rather than spells, so reporting each one would bury the
    genuine problems.
    """
    problems: list[str] = []
    found: list[SpellBlock] = []

    for index, raw in enumerate(lines):
        if statline.is_damaged_statline(raw):
            if _inline_anchor(lines, index - 1) is not None:
                problems.append(f"line {index + 1}: damaged stat line {raw.strip()!r}")
            continue

        if not statline.is_statline(raw):
            continue

        anchor = _inline_anchor(lines, index - 1)
        if anchor is None:
            continue

        name = _inline_name_above(lines, index - 2)
        if name is None:
            continue

        technique = _TECHNIQUE_NAMES[anchor.group("technique")]
        form = _FORM_NAMES[anchor.group("form")]
        level = None if anchor.group("general") else int(anchor.group("level"))

        normalized = _normalize_stat_line(raw)
        folded = statline.strip_markup(normalized)

        # Identical to parse_de's fold: look past blank lines for a `Req:`
        # continuation printed on its own line and splice it into the stat
        # line, so parse_statline keeps seeing one logical line.
        prose_start = index + 1
        cursor = prose_start
        while cursor < len(lines) and not statline.strip_markup(lines[cursor]):
            cursor += 1
        if cursor < len(lines):
            candidate = statline.strip_markup(lines[cursor])
            if _REQ_CONTINUATION.match(candidate):
                folded = f"{folded}, {candidate}"
                prose_start = cursor + 1

        try:
            stat = statline.parse_statline(folded)
        except ValueError as e:
            problems.append(f"line {index + 1}: {e}")
            continue

        prose_lines: list[str] = []
        design: str | None = None
        cursor = prose_start
        while cursor < len(lines):
            candidate = statline.strip_markup(lines[cursor])
            if _DESIGN.match(candidate):
                design = candidate
                break
            # Stop at the next block or section. The scan is bounded by
            # structure rather than a line count on purpose: Form of the
            # (Temperament) Heartbeast prints four variant paragraphs between
            # its stat line and its design line.
            if _HEADING.match(candidate) or _BOLD_NAME.match(
                    statline.strip_quote(lines[cursor])):
                break
            if candidate:
                prose_lines.append(candidate)
            cursor += 1

        found.append(SpellBlock(
            name=name,
            technique=technique,
            form=form,
            printed_level=level,
            stat=stat,
            prose=" ".join(prose_lines),
            design_line=design,
            line_no=index + 1,
        ))

    return found, problems


PARSERS = {
    "de": parse_de,
    "inline": parse_inline,
}
