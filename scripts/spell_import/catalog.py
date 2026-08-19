"""Load the committed JSON catalogs and narrow base-effect candidates.

Narrowing is all this module does about base effects. It never picks between
candidates: a design line names its guideline only by level, and picking the
wrong one of four entries at the same level is invisible to a level test.
That decision belongs to a human and is recorded in ledger.json.
"""
import dataclasses
import json
import pathlib
import re

from .sources import REPO_ROOT

DATA_DIR = REPO_ROOT / "assets" / "data"

TECHNIQUE_ABBREVIATION = {
    "Creo": "cr", "Intellego": "in", "Muto": "mu", "Perdo": "pe", "Rego": "re",
}
FORM_ABBREVIATION = {
    "Animal": "an", "Aquam": "aq", "Auram": "au", "Corpus": "co", "Herbam": "he",
    "Ignem": "ig", "Imaginem": "im", "Mentem": "me", "Terram": "te", "Vim": "vi",
}

# Leading articles and prepositions the existing ids drop. Content words stay,
# however stock-phrase-like they look: "phantasm" lived here until todo item 29
# and cost `lib-crim-human-form` and `lib-crim-talking-head` the word naming
# what they conjure.
_STOPWORDS = {"the", "of", "a", "an"}

CORE_BOOK_ID = "arm5-core"


def cites(entry: dict, book_id: str) -> bool:
    """Does this catalog row come from `book_id`?

    The catalog stopped being core-rules-only when todo item 17 added a
    guideline from Houses of Hermes: Mystery Cults, and several tests here
    measure the catalog against the *core rulebook's* printed tables. Those
    have to say which rows they are talking about rather than assuming every
    row is core — a supplement row is not a surplus to be deleted.

    Candidate resolution *does* use this, via `visible_books` — see that
    function for why item 55's book-blind rule was revised.
    """
    return any(c.get("bookId") == book_id for c in entry.get("citations") or [])


def visible_books(book_id: str) -> frozenset[str]:
    """The books a spell printed in `book_id` may draw catalog rows from.

    A core spell is built from core rows only; a supplement spell may use core
    rows and its own book's. (*Mysteries Revised* joins every set once it is a
    registered book — it is not one yet, and inventing its id here would be a
    guess.)

    This **revises** item 55's rule that candidate resolution is book-blind and
    that an out-of-scope row is "a ledger decision, not a filter". Book-blind
    resolution meant every new supplement widened the candidate sets of spells
    printed years earlier, and each widening became a `unreviewedCandidates`
    backlog item for a human to clear -- item 32.1 cleared seven such entries,
    and all seven were of exactly this kind: HoH:MC rows offered to core
    spells that could never legally use them. Scoping the offer at source means
    a new book adds rows without reopening a single existing decision.

    There is deliberately **no exception mechanism**. A spell that genuinely
    needs a row from a third book fails loudly -- `StaleEntry`, or "no base
    effect at that Technique/Form/level" -- and the escape hatch gets designed
    against that concrete case rather than guessed at now.
    """
    return frozenset({CORE_BOOK_ID, book_id})


def slug_id(technique: str, form: str, name: str) -> str:
    prefix = TECHNIQUE_ABBREVIATION[technique] + FORM_ABBREVIATION[form]
    words = re.sub(r"[^a-z0-9\s-]", "", name.lower()).split()
    kept = [w for w in words if w not in _STOPWORDS] or words
    return f"lib-{prefix}-{'-'.join(kept)}"


@dataclasses.dataclass
class Catalog:
    base_effects: list[dict]
    parameters: list[dict]
    modifiers: list[dict]

    @classmethod
    def load(cls, data_dir: pathlib.Path = DATA_DIR) -> "Catalog":
        def read(name: str) -> list[dict]:
            return json.loads((data_dir / name).read_text(encoding="utf-8"))

        return cls(
            base_effects=read("base_effects.json"),
            parameters=read("parameters.json"),
            modifiers=read("modifiers.json"),
        )

    def candidates(
        self, technique: str, form: str, base_level: int, book_id: str
    ) -> list[str]:
        """Rows at this Technique/Form/level that a `book_id` spell may use.

        `book_id` is the book the *spell* was printed in, not the row's — see
        `visible_books` for the scoping rule and why it is not book-blind.
        """
        books = visible_books(book_id)
        return sorted({
            effect["id"]
            for effect in self.base_effects
            if effect["technique"] == technique
            and effect["form"] == form
            and effect["baseLevel"] == base_level
            and any(cites(effect, book) for book in books)
        })

    def general_candidates(
        self, technique: str, form: str, book_id: str
    ) -> list[str]:
        """Every General row for a Technique/Form a `book_id` spell may use.

        Unlike `candidates`, this cannot narrow by level: a General row has
        none. Perdo Vim therefore returns all 13, and the pick rests entirely
        on the ledger's recorded rationale plus assertion 6.
        """
        books = visible_books(book_id)
        return sorted({
            effect["id"]
            for effect in self.base_effects
            if effect["technique"] == technique
            and effect["form"] == form
            and effect["baseLevel"] is None
            and any(cites(effect, book) for book in books)
        })

    def reference_cost(self, effect_id: str) -> int:
        """Total magnitude of the parameters a guideline is priced against."""
        effect = next((e for e in self.base_effects if e["id"] == effect_id), None)
        if effect is None:
            raise KeyError(f"no base effect with id {effect_id!r} in base_effects.json")
        reference = effect.get("reference") or {
            "rangeId": "range-personal",
            "durationId": "duration-momentary",
            "targetId": "target-individual",
        }
        by_id = {p["id"]: p["magnitude"] for p in self.parameters}
        return sum(by_id[reference[key]]
                   for key in ("rangeId", "durationId", "targetId"))

    def open_slots(self, effect_id: str) -> list[str]:
        """The `OpenSlotKind` names this guideline declares open, or `[]`.

        Mirrors `reference_cost`'s lookup shape: an unknown id is a caller
        bug, not a "no slots" answer, so it raises rather than defaulting.
        """
        effect = next((e for e in self.base_effects if e["id"] == effect_id), None)
        if effect is None:
            raise KeyError(f"no base effect with id {effect_id!r} in base_effects.json")
        return list(effect.get("openSlots") or [])

    def target_type(self, parameter_id: str) -> str | None:
        """The rulebook's kind for a Target: "object", "container" or "sense".

        None for a Range or Duration row, for an unknown id, and for a Target
        that has not been annotated. The Dart-side assertion in
        `asset_data_loader_test.dart` is what forbids the last case; treating
        it as None here means an un-annotated Target simply never matches
        "container", which fails loudly at the call site rather than silently
        stamping a mode onto the wrong row.
        """
        for parameter in self.parameters:
            if parameter["id"] == parameter_id:
                return parameter.get("targetType")
        return None

    def parameter_id(self, category: str, name: str) -> str:
        for parameter in self.parameters:
            if parameter["category"] == category and parameter["name"] == name:
                return parameter["id"]
        raise KeyError(f"no {category} parameter named {name!r} in parameters.json")
