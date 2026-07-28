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

# Leading articles and stock phrases the existing 36 ids drop.
_STOPWORDS = {"the", "of", "a", "an", "phantasm"}


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

    def candidates(self, technique: str, form: str, base_level: int) -> list[str]:
        return sorted({
            effect["id"]
            for effect in self.base_effects
            if effect["technique"] == technique
            and effect["form"] == form
            and effect["baseLevel"] == base_level
        })

    def parameter_id(self, category: str, name: str) -> str:
        for parameter in self.parameters:
            if parameter["category"] == category and parameter["name"] == name:
                return parameter["id"]
        raise KeyError(f"no {category} parameter named {name!r} in parameters.json")
