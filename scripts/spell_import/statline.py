"""Find and read a spell's stat line: `R: Touch, D: Sun, T: Ind, Ritual`.

The stat line is the anchor for the whole import. Every spell has one and
almost nothing else does, which makes it a far more reliable locator than the
heading structure — headings vary between books and are sometimes simply wrong
(the Definitive Edition files four Creo Terram spells under a Guidelines
heading with no Spells heading of its own).

The predicate is "contains R:, then D:, then T:", NOT "starts with R:". The
two are indistinguishable on the Definitive Edition, which is why the weaker
rule looks sound; across the supplements the conjunction finds 2378 stat lines
against 1300, because books such as Against the Dark write
`**R:** Voice, **D:** Diameter, **T:** Part`.
"""
import dataclasses
import re

_LEADING = re.compile(r"^[>\s]*")
_BOLD = re.compile(r"\*\*")
_BR = re.compile(r"<br\s*/?>", re.IGNORECASE)

_CONJUNCTION = re.compile(r"\bR:\s*\S.*?\bD:\s*\S.*?\bT:\s*\S")
# Tolerant: a field is present if its letter is followed by an optional colon
# and then a word. Used only to raise damaged lines for review.
_FIELD = re.compile(r"\b([RDT]):?\s+\*{0,2}[A-Za-z]")

_FIELDS = re.compile(
    r"\bR:\s*(?P<range>.+?)\s*[,.]\s*"
    r"\bD:\s*(?P<duration>.+?)\s*[,.]\s*"
    r"\bT:\s*(?P<target>.+)$"
)
_REQ = re.compile(r"\bReq(?:uisites?)?:\s*(?P<arts>[A-Za-z, ]+)")
_RITUAL = re.compile(r"\bRitual\b")

ARTS = {
    "Creo", "Intellego", "Muto", "Perdo", "Rego",
    "Animal", "Aquam", "Auram", "Corpus", "Herbam",
    "Ignem", "Imaginem", "Mentem", "Terram", "Vim",
}


def strip_markup(line: str) -> str:
    return _BOLD.sub("", _BR.sub("", _LEADING.sub("", line))).strip()


def is_statline(line: str) -> bool:
    return bool(_CONJUNCTION.search(strip_markup(line)))


def is_damaged_statline(line: str) -> bool:
    """Two of the three fields present, but not a well-formed stat line.

    These are not skipped and not parsed — they are reported. A transposed
    `R: Touch, T: Ring, D: Circle` would otherwise import with Duration and
    Target swapped, and both values are legal, so nothing downstream would
    notice.
    """
    cleaned = strip_markup(line)
    if _CONJUNCTION.search(cleaned):
        return False
    return len({m.group(1) for m in _FIELD.finditer(cleaned)}) >= 2


@dataclasses.dataclass(frozen=True)
class StatLine:
    range_name: str
    duration_name: str
    target_name: str
    is_ritual: bool
    requisite_arts: list[str]
    trailing: str


def parse_statline(line: str) -> StatLine:
    cleaned = strip_markup(line)
    match = _FIELDS.search(cleaned)
    if not match:
        raise ValueError(f"not a well-formed stat line: {line!r}")

    tail = match.group("target")
    is_ritual = bool(_RITUAL.search(tail))

    requisites: list[str] = []
    req_match = _REQ.search(tail)
    if req_match:
        for art in req_match.group("arts").split(","):
            art = art.strip()
            if art in ARTS:
                requisites.append(art)
        tail = tail[: req_match.start()]

    # The target is the first token run before Ritual/Req/description prose.
    target = _RITUAL.split(tail)[0].strip().rstrip(",.").strip()
    # Some books run the description straight on: keep only the leading words
    # that look like a target name (capitalised words, "or", parenthesis-free).
    target = re.match(r"[A-Za-z]+(?:\s+[A-Za-z]+){0,2}", target)
    target = target.group(0).strip() if target else ""

    return StatLine(
        range_name=match.group("range").strip().rstrip(",."),
        duration_name=match.group("duration").strip().rstrip(",."),
        target_name=target,
        is_ritual=is_ritual,
        requisite_arts=requisites,
        trailing=cleaned,
    )
