"""The hand-edited record of every base-effect decision that needed judgement.

A published spell's design line names its guideline only by level. Creo Animal
has four entries at level 15, all producing the same computed level, so the
level test cannot tell a right choice from a wrong one. Todo item 5 is the
proof: 19 of 36 built-in spells referenced wrong or invented base-effect ids
while every level test was green.

This file is written by hand and read by the extractor. The extractor never
writes it — a generated file that silently rewrites the human decisions it
depends on is not a ledger.
"""
import dataclasses
import json
import pathlib

LEDGER_PATH = pathlib.Path(__file__).resolve().parent / "resolutions.json"


class LedgerError(Exception):
    """Base class for ledger problems. All are build failures."""


class MissingEntry(LedgerError):
    pass


class StaleEntry(LedgerError):
    pass


class WidenedEntry(StaleEntry):
    """A stale entry the catalog only *added* to, leaving the choice standing.

    Deliberately a subclass: an un-migrated ledger is still a build failure,
    so every existing `except StaleEntry` keeps its behaviour. What the
    subclass buys is knowing the difference between "somebody must re-read
    this spell" and "carry the recorded decision forward" — the second is
    mechanical, and `migrate_ledger.py` does it.
    """


class UnnecessaryEntry(LedgerError):
    pass


@dataclasses.dataclass(frozen=True)
class Entry:
    base_effect_id: str
    candidates: list[str]
    rationale: str
    # Candidates that entered the catalog after this decision was made and
    # have never been weighed against it by a human. Empty on a hand-written
    # entry; populated only by `migrate_ledger.py`. The rationale above is
    # silent about these ids by construction, which is exactly why they are
    # named here rather than folded into `candidates` and forgotten — see
    # todo item 32, whose whole subject is entries no test can check.
    unreviewed_candidates: tuple[str, ...] = ()


@dataclasses.dataclass
class Ledger:
    entries: dict[str, Entry]

    @classmethod
    def from_dict(cls, raw: dict) -> "Ledger":
        entries: dict[str, Entry] = {}
        for spell_id, value in raw.items():
            for field in ("baseEffectId", "candidates", "rationale"):
                if field not in value:
                    raise ValueError(f"{spell_id}: ledger entry is missing {field!r}")
            if not str(value["rationale"]).strip():
                raise ValueError(f"{spell_id}: ledger entry needs a non-empty rationale")
            unreviewed = tuple(sorted(value.get("unreviewedCandidates", ())))
            unknown = [c for c in unreviewed if c not in value["candidates"]]
            if unknown:
                raise ValueError(
                    f"{spell_id}: unreviewedCandidates {unknown} are not among "
                    "this entry's candidates"
                )
            entries[spell_id] = Entry(
                base_effect_id=value["baseEffectId"],
                candidates=sorted(value["candidates"]),
                rationale=value["rationale"],
                unreviewed_candidates=unreviewed,
            )
        return cls(entries=entries)

    @classmethod
    def load(cls, path: pathlib.Path = LEDGER_PATH) -> "Ledger":
        return cls.from_dict(json.loads(path.read_text(encoding="utf-8")))

    def unreviewed(self) -> dict[str, tuple[str, ...]]:
        """Every entry carrying candidates no human has weighed, by spell id."""
        return {spell_id: entry.unreviewed_candidates
                for spell_id, entry in sorted(self.entries.items())
                if entry.unreviewed_candidates}

    def resolve(self, spell_id: str, candidates: list[str]) -> str:
        candidates = sorted(candidates)
        entry = self.entries.get(spell_id)

        if len(candidates) == 1:
            if entry is not None and entry.base_effect_id == candidates[0]:
                # An entry disagreeing with the sole candidate does NOT reach
                # here: it falls through to the `not in candidates` check
                # below, which raises StaleEntry. That is the design, not a
                # gap (todo item 29, decided 2026-08-17). The ledger records
                # a choice *among* the candidates a spell's design line
                # admits, never one against them -- `candidates` is what lets
                # the build re-check a decision when the catalog moves, and a
                # choice outside its own candidate set cannot be re-checked
                # at all. A sole candidate that is the wrong guideline is a
                # base_effects.json bug, or an ExceptionSpell.
                raise UnnecessaryEntry(f"{spell_id}: only one candidate ({candidates[0]}); "
                                        "remove the ledger entry")
            if entry is None:
                return candidates[0]

        if not candidates:
            raise MissingEntry(f"{spell_id}: no base effect at that Technique/Form/level")

        if entry is None:
            raise MissingEntry(
                f"{spell_id}: {len(candidates)} candidates {candidates} and no ledger entry"
            )

        if entry.candidates != candidates:
            added = [c for c in candidates if c not in entry.candidates]
            removed = [c for c in entry.candidates if c not in candidates]
            if added and not removed and entry.base_effect_id in candidates:
                raise WidenedEntry(
                    f"{spell_id}: decided against {entry.candidates}, and the catalog "
                    f"has since added {added}. The choice ({entry.base_effect_id}) is "
                    "still available and still stands — run "
                    "`python -m scripts.spell_import.migrate_ledger --write` to carry "
                    "it forward, which records the added ids as unreviewed rather "
                    "than pretending they were weighed"
                )
            raise StaleEntry(
                f"{spell_id}: decided against {entry.candidates} but the catalog now "
                f"offers {candidates} — re-examine the choice, then update the entry"
            )

        if entry.base_effect_id not in candidates:
            raise StaleEntry(
                f"{spell_id}: chose {entry.base_effect_id}, which is not among {candidates}"
            )

        return entry.base_effect_id


def migrate_raw(raw: dict, widenings: dict[str, list[str]]) -> dict:
    """Carry each widened entry forward in the raw ledger mapping.

    Takes the parsed JSON rather than `Entry` objects so a rewrite touches
    only the entries that widened: every other entry, its key order and its
    rationale text round-trip untouched.

    The recorded choice and rationale are preserved verbatim — that is the
    whole point, since a widening leaves the decision standing. What is
    *added* is the honest part: the new ids land in `unreviewedCandidates`,
    so the entry says "these arrived after I was written and nobody has
    weighed them" instead of silently implying the rationale considered them.
    """
    migrated = dict(raw)
    for spell_id, candidates in widenings.items():
        entry = dict(raw[spell_id])
        added = [c for c in candidates if c not in entry["candidates"]]
        entry["candidates"] = sorted(candidates)
        entry["unreviewedCandidates"] = sorted(
            set(entry.get("unreviewedCandidates", ())) | set(added)
        )
        migrated[spell_id] = entry
    return migrated
