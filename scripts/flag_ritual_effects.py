import pathlib
import re

REQUIRED = [
    'craq-25b', 'crau-25', 'crco-5b', 'crig-25b', 'crte-25b',
    'pevi-G9', 'pevi-G10',
]

SUGGESTED = [
    # Creo Animal (11)
    'cran-15a', 'cran-20a', 'cran-25b', 'cran-25c', 'cran-25d', 'cran-25e',
    'cran-30a', 'cran-30b', 'cran-35', 'cran-40', 'cran-75',
    # Creo Corpus (20)
    'crco-15a', 'crco-15c', 'crco-20a', 'crco-20b', 'crco-20c', 'crco-25a',
    'crco-25b', 'crco-25c', 'crco-25d', 'crco-30a', 'crco-30b', 'crco-30d',
    'crco-35a', 'crco-35b', 'crco-35c', 'crco-40', 'crco-45', 'crco-50',
    'crco-55', 'crco-70',
    # Creo Herbam (7)
    'crhe-1e', 'crhe-2c', 'crhe-3b', 'crhe-4', 'crhe-5', 'crhe-10',
    'crhe-15b',
]

FLAGS = {}
for effect_id in REQUIRED:
    FLAGS[effect_id] = 'required'
for effect_id in SUGGESTED:
    FLAGS[effect_id] = 'suggested'
assert len(FLAGS) == 45, f'expected 45 distinct ids, got {len(FLAGS)}'

path = pathlib.Path('assets/data/base_effects.json')
lines = path.read_text(encoding='utf-8').split('\n')

seen = set()
out = []
for line in lines:
    match = re.match(r'\s*\{"id": "([^"]+)"', line)
    flag = FLAGS.get(match.group(1)) if match else None
    if flag:
        seen.add(match.group(1))
        stripped = line.rstrip()
        trailing_comma = stripped.endswith(',')
        body = stripped[:-1] if trailing_comma else stripped
        assert body.endswith('}'), f'unexpected line shape for {match.group(1)}'
        assert '"ritualRequirement"' not in body, f'{match.group(1)} already flagged'
        line = body[:-1] + f', "ritualRequirement": "{flag}"' + '}' + (',' if trailing_comma else '')
    out.append(line)

missing = set(FLAGS) - seen
assert not missing, f'ids not found in the catalog: {sorted(missing)}'

# newline='\n' is mandatory: Python on Windows would otherwise translate every
# \n to \r\n and rewrite all 604 lines.
with open(path, 'w', encoding='utf-8', newline='\n') as handle:
    handle.write('\n'.join(out))

print(f'flagged {len(seen)} entries')
