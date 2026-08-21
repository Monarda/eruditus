# One-shot script, already applied (page references, task 6). Kept for
# reference only, not part of any build or test step -- do not re-run
# without checking `base_effects.json` and `parameters.json` first: if either
# file has grown new arm5-core entries since this ran, those entries need
# citation checking before this script is re-applied blindly.
#
# `base_effects.json`, `parameters.json` and `modifiers.json` are
# hand-maintained catalogs with no generator (unlike the extractor's own
# assets, which get their pages from an earlier task). This script gives the
# first two files their printed page numbers by direct lookup against the
# rulebook's own curated index tables -- never by searching or guessing --
# following the precedent set by `scripts/flag_ritual_effects.py` for a
# different field.
#
# `modifiers.json` is deliberately left untouched: modifiers are not
# individually indexed in the rulebook, so there is no key to look them up
# by. Inventing one would be exactly the guessing this design removed.
import pathlib
import re

from scripts.spell_import import pages

index = pages.load_index()


def enrich_base_effects():
    """Single-line-per-record format: rewrite only the `citations` substring
    on lines that already read `"citations": [{"bookId": "arm5-core"}]`."""
    path = pathlib.Path('assets/data/base_effects.json')
    lines = path.read_text(encoding='utf-8').split('\n')

    needle = '"citations": [{"bookId": "arm5-core"}]'
    core = 0
    hits = 0
    out = []
    for line in lines:
        if needle in line:
            match = re.search(r'"technique": "([^"]+)".*"form": "([^"]+)"', line)
            assert match, f'core citation with no technique/form: {line!r}'
            core += 1
            page = index.guideline_index_pages.get((match.group(1), match.group(2)))
            if page is not None:
                hits += 1
                replacement = (
                    f'"citations": [{{"bookId": "arm5-core", "page": {page}}}]')
                line = line.replace(needle, replacement)
        out.append(line)

    # newline='\n' is mandatory: Python on Windows would otherwise translate
    # every \n to \r\n and rewrite every line in the file.
    with open(path, 'w', encoding='utf-8', newline='\n') as handle:
        handle.write('\n'.join(out))

    print(f'base_effects.json: {hits} of {core} core entries got a page')


def enrich_parameters():
    """Multi-line pretty-printed format: each core citation is its own
    three-line block, `{ / "bookId": "arm5-core" / }`. A hit appends a comma
    to the bookId line and inserts a new `"page"` line after it -- no other
    line in the file moves."""
    path = pathlib.Path('assets/data/parameters.json')
    lines = path.read_text(encoding='utf-8').split('\n')

    name = None
    category = None
    core = 0
    hits = 0
    out = []
    for line in lines:
        name_match = re.match(r'^\s*"name": "(.*)",\s*$', line)
        if name_match:
            name = name_match.group(1)
        category_match = re.match(r'^\s*"category": "(.*)",\s*$', line)
        if category_match:
            category = category_match.group(1)

        if line.strip() == '"bookId": "arm5-core"':
            assert name and category, f'bookId with no name/category yet: {line!r}'
            core += 1
            key = f'{name} ({category})'.lower()
            page = index.topic_index_pages.get(key)
            if page is not None:
                hits += 1
                indent = line[:len(line) - len(line.lstrip())]
                out.append(line + ',')
                out.append(f'{indent}"page": {page}')
            else:
                out.append(line)
            continue

        out.append(line)

    with open(path, 'w', encoding='utf-8', newline='\n') as handle:
        handle.write('\n'.join(out))

    print(f'parameters.json: {hits} of {core} core entries got a page')


enrich_base_effects()
enrich_parameters()
