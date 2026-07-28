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


class UnnecessaryEntry(LedgerError):
    pass


@dataclasses.dataclass(frozen=True)
class Entry:
    base_effect_id: str
    candidates: list[str]
    rationale: str


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
            entries[spell_id] = Entry(
                base_effect_id=value["baseEffectId"],
                candidates=sorted(value["candidates"]),
                rationale=value["rationale"],
            )
        return cls(entries=entries)

    @classmethod
    def load(cls, path: pathlib.Path = LEDGER_PATH) -> "Ledger":
        return cls.from_dict(json.loads(path.read_text(encoding="utf-8")))

    def resolve(self, spell_id: str, candidates: list[str]) -> str:
        candidates = sorted(candidates)
        entry = self.entries.get(spell_id)

        if len(candidates) == 1:
            if entry is not None and entry.base_effect_id == candidates[0]:
                raise UnnecessaryEntry(
                    f"{spell_id}: only one candidate ({candidates[0]}); "
                    "remove the ledger entry, or change it to a deliberate override"
                )
            if entry is None:
                return candidates[0]

        if not candidates:
            raise MissingEntry(f"{spell_id}: no base effect at that Technique/Form/level")

        if entry is None:
            raise MissingEntry(
                f"{spell_id}: {len(candidates)} candidates {candidates} and no ledger entry"
            )

        if entry.candidates != candidates:
            raise StaleEntry(
                f"{spell_id}: decided against {entry.candidates} but the catalog now "
                f"offers {candidates} — re-examine the choice, then update the entry"
            )

        if entry.base_effect_id not in candidates:
            raise StaleEntry(
                f"{spell_id}: chose {entry.base_effect_id}, which is not among {candidates}"
            )

        return entry.base_effect_id
