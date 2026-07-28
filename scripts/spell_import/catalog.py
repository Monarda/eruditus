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

# 19 of the 36 committed library spells were hand-edited before this slugger
# existed and treat "of" (and which leading noun to drop) inconsistently —
# e.g. "Veil of Invisibility" keeps "of" (-> veil-of-invisibility) while
# "Illusion of Cool Flames" drops both "Illusion" and "of" (-> cool-flames).
# No general word-dropping rule reproduces all of them (see
# .superpowers/sdd/task-5-report.md for the full analysis), and inventing one
# would just curve-fit this noise into the rule that also generates ids for
# the ~250 spells being imported later, silently degrading those. So these
# 19 historical ids are pinned verbatim by spell name; the general rule
# below is authoritative only for names that aren't in this dict, i.e.
# spells not yet given an id.
#
# Note: "Incantation of Summoning the Dead" -> "lib-reem-summoning-the-dead"
# preserves the historical id as-is, including its "reem" prefix, which
# itself echoes a pre-existing typo in assets/data/base_effects.json's
# "reem-15b" entry (Rego Mentem should abbreviate to "reme", per
# FORM_ABBREVIATION, not "reem"). That typo is a base-effects data-quality
# issue, out of scope here, and relevant to the already-tracked todo about
# rebuilding the base-effect catalog from the correct source.
ID_OVERRIDES = {
    "Haunt of the Living Ghost": "lib-crim-haunt",
    "Eyes of the Eagle": "lib-inim-eyes-of-the-eagle",
    "Taste of the Spices and Herbs": "lib-muim-taste-of-spices",
    "Aura of Ennobled Presence": "lib-muim-ennobled-presence",
    "Notes of a Delightful Sound": "lib-muim-notes-of-delightful-sound",
    "Disguise of the Transformed Image": "lib-muim-disguise",
    "Illusion of Cool Flames": "lib-peim-cool-flames",
    "Veil of Invisibility": "lib-peim-veil-of-invisibility",
    "Removal of the Conspicuous Sigil": "lib-peim-conspicuous-sigil",
    "Silence of the Smothered Sound": "lib-peim-smothered-sound",
    "Chamber of Invisibility": "lib-peim-chamber-of-invisibility",
    "Illusion of the Shifted Image": "lib-reim-shifted-image",
    "Image from the Wizard Torn": "lib-reim-wizard-torn",
    "Wall of Protecting Stone": "lib-crte-wall-of-protecting-stone",
    "Reaching Hand of Ten Boulders": "lib-rete-reaching-hand-of-ten-boulders",
    "Incantation of the Body Made Whole": "lib-crco-body-made-whole",
    "Touch of Midas": "lib-crte-touch-of-midas",
    "Curse of the Ravenous Swarm": "lib-cran-ravenous-swarm",
    "Incantation of Summoning the Dead": "lib-reem-summoning-the-dead",
}


def slug_id(technique: str, form: str, name: str) -> str:
    if name in ID_OVERRIDES:
        return ID_OVERRIDES[name]
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
