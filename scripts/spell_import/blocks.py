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

        try:
            normalized = _normalize_stat_line(raw)
            stat = statline.parse_statline(normalized)
        except ValueError as e:
            problems.append(f"line {index + 1}: {e}")
            name = None
            continue

        prose_lines: list[str] = []
        design: str | None = None
        cursor = index + 1
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
