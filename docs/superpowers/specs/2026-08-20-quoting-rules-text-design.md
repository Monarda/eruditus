# Quoting Rules Text: what CC BY-SA 4.0 permits, and what it demands back

**Todo items:** 79 (79.1, 79.2, 79.3). Upstream of item 56; constrains items
31, 78, 82; consistent with 80.3.

**Status:** designed 2026-08-20

**Licence:** `Ars-Magica-Open-License/LICENSE.md` — Creative Commons
Attribution-ShareAlike 4.0 International. Section references in this document
(§2(a)(1), §3(a), §3(b), …) are to that file.

**Not legal advice.** This document records what the licence text says and what
the project decided to do about it. It is a product decision informed by
reading the licence, not an opinion from anyone qualified to give one.

---

## Problem

Item 56 assumed hint text would have to be *paraphrased* UI copy, because the
licence position had never been checked. It has been now: §2(a)(1) grants the
right to "reproduce and Share the Licensed Material, in whole or in part". **We
may quote rules text verbatim.**

Two conditions ride along — attribution (§3(a)) and ShareAlike (§3(b)) — and
both are product decisions rather than legal trivia.

**The item's own framing understated the urgency.** Item 79.2 noted that the
catalog JSON is "arguably already a database derived from the Licensed
Material (§4)". It is more direct than that: the app already ships the
rulebook's own words today, and has since the import landed.

- `assets/data/base_effects.json` — 612 guideline `description` strings that
  are the rulebook's wording verbatim ("Give an animal a +1 bonus to Recovery
  rolls").
- `assets/data/spell_library.json` — 336 published spell names, plus `summary`
  and `description` prose taken from the book.
- `scripts/spell_import/resolutions.json` — quotes design lines.

This is not a database right question awaiting item 56. It is straightforward
reproduction of licensed text, live in `main`, in a repo that at the time of
writing carries **no LICENSE file at all** and a `pubspec.yaml` still
describing itself as "A new Flutter project".

The intent is a public source repo and a released app, so both §3(a) and §3(b)
fully engage.

## Explicitly not in scope

- **Item 56's affordance design.** This document settles what may be quoted and
  how a quote must be marked; it does not design the hint sheet, popover or
  info icon.
- **Trademark, naming, and store listing.** §2(b)(2) does not license
  trademarks. The grant covers text, not "Ars Magica" as a mark, so nothing
  here settles what the app may be called or how it may be listed.
- **Whether machine translation is shippable.** Items 81.1 and 82 own that.
  This document only fixes what an MT string must be *marked* as.
- **The edition model.** `Book` gaining `language`/`workId`/attribution fields,
  and `visible_books()` keying on work id, are filed as a new item (see
  "Consequences for other items").
- **Retrofitting attribution into already-published builds.** There are none.

## Backwards compatibility is not a goal

`Spell` persists as a single JSON blob in the `spells.data` column, and
`AppDatabase` has bumped its schema version and dropped that table for every
blob-shape change from v4 through v9. Section 4 below changes the blob shape
again; it takes a **v10 bump and the same drop**, consistent with that standing
policy, rather than a per-field default on read.

## The organising idea: whose words are these?

The licence obligations turn on one question the codebase cannot currently
answer: **for a given piece of user-facing text, whose words are these?**

`Provenance` (`lib/models/provenance.dart`) looks like it answers this. It does
not. It records where an **entry** came from — `PublicationSource.published`
versus `userCreated`, self-validating on `published ⟺ has ≥1 citation`. That is
provenance of the *record*, not of the *string*.

Today the two coincide by accident: `Spell.summary` is the verbatim
`description` truncated to 400 characters, so a `published` spell's summary
happens to be the rulebook's words. **Item 31 breaks that deliberately** by
replacing those with ledger-*authored* summaries — our prose, on a `published`
entry. Anything styling text as a quote on the strength of
`source == published` would then attribute our paraphrase to the rulebook,
which is precisely the failure item 79.3 was opened to prevent.

Item 82 needs the same distinction for a different reason: §2(a)(4) makes a
translation Adapted Material, so a machine-translated quote is not the
rulebook's words either.

Hence a per-string provenance, distinct from and additional to the per-entry
one.

## Design

### 1. Repo licence structure (79.2)

**Rule, stated by content rather than only by path:** rulebook-derived
*content* is CC BY-SA 4.0 wherever it appears; the *software* is MIT. Paths
that are wholly one or the other are named so the boundary is checkable.

| Path | Licence |
|---|---|
| `lib/`, `test/`, `integration_test/`, `tool/`, `scripts/spell_import/*.py` | MIT |
| `assets/data/*.json` | CC BY-SA 4.0 (Adapted Material) |
| `scripts/spell_import/resolutions.json` | CC BY-SA 4.0 — it quotes design lines; our rationales ride along |
| `docs/` | follows the text it quotes |

**Why the split, and why it is defensible.** §1(b) defines a "Collection" —
Licensed Material assembled with separate and independent contributions into a
collective whole — and a Collection is expressly *not* Adapted Material.
§3(b)'s ShareAlike condition applies only to Adapted Material. §4(b) reinforces
the point for databases: including licensed contents in a database in which one
holds sui generis rights does not itself make that database Adapted Material.

That divides the repo cleanly:

- `assets/data/*.json` **is** Adapted Material. The guidelines were transcribed,
  restructured into a schema, assigned identifiers, and in places corrected —
  "altered, arranged, transformed" in §1(a)'s terms. It carries CC BY-SA 4.0
  and §3(a)(1)(B)'s "indicate if You modified" applies.
- `lib/**` **is an independent contribution.** An engine that reads a data file
  and computes arithmetic is aggregated *with* the licensed data, not derived
  from it. The arithmetic it implements is a game system, not expression.

The edge case is a `.dart` file that embeds quoted rules text as a string
literal. The way to keep the edge clean is never to do that — which is where
items 56 and 80.3 were independently already heading, so the constraint costs
nothing new.

**Files created:**

- `LICENSE` — MIT, © 2026 Ivan Finch.
- `LICENSES/CC-BY-SA-4.0.txt` — the full licence text, copied from the pinned
  rulebook checkout.
- `NOTICE.md` — states the split and carries the §3(a) notice of section 2
  below.
- `assets/data/LICENSE` — a stub pointing at `LICENSES/CC-BY-SA-4.0.txt`, so
  the boundary is visible at the place it applies.
- `README.md` gains the table above.
- `pubspec.yaml` gains a real `description`. `publish_to: 'none'` stays — this
  is an application, not a pub package.

### 2. The §3(a) notice, and why it is a list

All six required parts:

| Clause | Content |
|---|---|
| (A)(i) creator | Trident, Inc. d/b/a Atlas Games®; markdown transcription by OriginalMadman |
| (A)(ii) copyright | © 1993–2024 Trident, Inc. d/b/a Atlas Games |
| (A)(iii) licence | CC BY-SA 4.0, with the deed URI |
| (A)(iv) disclaimer | CC's §5 warranty disclaimer, verbatim |
| (A)(v) URI | the CC deed URL, and the source repo **pinned at `ffc1c6b`** |
| (B) modified | "transcribed, restructured into JSON, assigned identifiers, and in places corrected — see `scripts/spell_import/`" |

Plus two lines the licence requires us not to imply otherwise: trademarks are
**not** licensed (§2(b)(2)), and nothing implies Atlas Games endorses eruditus
(§2(a)(6), §5).

Naming the pinned commit rather than a moving branch follows item 30's
provenance ethos: the URI identifies the material we actually adapted.

**The notice is structured as a list of source editions, not one paragraph.**
Today it holds a single attribution block naming two books (`arm5-core`,
`arm5-hohmc`), which share the same Atlas notice. The list shape matters
because §3(a)(1)(A)(i) requires retaining creator identification *as supplied
with the material* — a separately-published edition with its own translators
and its own copyright line needs its own block, not an appendix to Atlas's. A
third entry must be additive, never a rewrite.

Making the list **data-driven from `books.json`** is deferred to the edition
item; today it is hand-maintained in the shape the data-driven version will
produce.

### 3. In-app attribution (79.1)

§3(a)(2) is permissive about the medium: attribution may be satisfied "in any
reasonable manner based on the medium, means, and context", explicitly
including "by providing a URI or hyperlink to a resource that includes the
required information". Quoted text in the UI therefore does not need the full
six-part notice attached to it. It needs a route to one place that carries it.

- **New `lib/presentation/screens/about_screen.dart`**, reached from an
  "About & Licences" `ListTile` at the foot of
  `lib/presentation/screens/configuration_screen.dart`. Not a fifth bottom-nav
  tab: `lib/main.dart` already carries four (Create, Library, Settings,
  Backup), and a fifth is poor value for a screen visited once.
- The screen carries the section 2 notice list, the two disclaimers, the app
  version, and a button into Flutter's built-in `showLicensePage()` for package
  licences.
- **`LicenseRegistry.addLicense()` in `main.dart`** registers the Atlas entry so
  the notice also appears to anyone reaching licences the standard Flutter way.
  Roughly ten lines, and it means the obligation is discharged by two
  independent routes.
- **No `url_launcher`.** §3(a)(1)(A)(v) requires the URI be *provided*, not
  clickable. `SelectableText` discharges that without a new dependency or the
  Android `queries` / iOS plist configuration `url_launcher` requires.

**Localisation.** Screen chrome — title, button labels, the `ListTile` label —
goes through ARB per item 80. The notice body does **not**: it is verbatim
source-language text, which 80.3's rule already routes around ARB. The
consistency is structural rather than an exception carved out for this screen.

### 4. Per-string provenance (79.3)

**New `lib/models/text_provenance.dart`:**

```dart
enum TextProvenance { verbatim, authored, translated }
```

with wire values `'verbatim'`, `'authored'`, `'translated'`, following
`PublicationSource`'s existing `fromWire`/`wireValue` shape rather than
inventing a second serialization idiom.

| Value | Meaning |
|---|---|
| `verbatim` | the published words of a cited edition — whichever edition, in whatever language |
| `authored` | our own prose |
| `translated` | our rendering of someone else's words |

**`verbatim` is defined by "a cited edition", not by "the English rulebook".**
An officially published translation licensed under CC BY-SA is Licensed
Material in its own right, not our derivation of the English. Quoting it is
`verbatim`, cited to *its* book and page. Collapsing it into `translated` would
simultaneously under-credit its translators and claim a modification we did not
make. `translated` means only "we produced this rendering", which is exactly the
thing §3(a)(1)(B) obliges us to indicate.

**A `SourcedText` value type** (`text` + `provenance`) carries the pair. Applied
to the user-facing rules-text fields: `BaseEffect.description`, `Spell.summary`,
`Spell.description`, and whatever item 56 adds. Serialized as
`{"text": "…", "provenance": "verbatim"}` with **no bare-string fallback** — a
silent default is the mechanism by which text would get mis-attributed, which is
the whole failure mode this type exists to prevent.

**Rendering rule, in one place:**

| Provenance | Treatment |
|---|---|
| `verbatim` | quote styling (rule or tint, distinct from body) plus a source marker routing to the About screen |
| `authored` | plain body text, no marker |
| `translated` | disclosed as a translation, never presented as the rulebook's words |

**Resolution order** when the same content exists in more than one edition:

| Priority | Source | Provenance | Marked as |
|---|---|---|---|
| 1 | licensed edition matching the locale | `verbatim` | quote, cited to *that* edition |
| 2 | licensed edition in another language | `verbatim` | quote, cited, visibly not in the UI language |
| 3 | our machine translation | `translated` | disclosed as machine-generated (§3(a)(1)(B)) |
| — | our own prose | `authored` | plain body, no quote styling |

This gives item 82.3 — "decide what the flag actually drives" — a concrete
answer for the catalog half of its two stores.

### 5. The quoting boundary

Quote what explains **one control**: the guideline line, a spell's own prose,
and the rulebook's definition paragraph for a Range, Duration, Target or
modifier. Not chapter-length rules.

The licence sets no ceiling — §2(a)(1) permits reproduction "in whole or in
part" — so this is a **product** boundary, not a legal one. It is what keeps
eruditus a calculator rather than a partial rulebook reader, and it keeps item
56's extraction target small enough to be testable.

## Testing

- **Every `verbatim` string resolves to an entry carrying ≥1 citation.** Extends
  `Provenance`'s existing entry-level invariant to the string level: a quote
  whose source cannot be named is a licence defect, not a display bug.
- **A `userCreated` entry can hold no `verbatim` text.** The mirror of the
  above, matching `Provenance`'s existing two-way check.
- **Widget test: the About screen renders all six §3(a) parts**, plus the two
  disclaimers. This is the guard against the notice silently rotting as the
  screen is restyled.
- **`NOTICE.md` exists and carries the CC deed URI and the pinned commit.**
- **Render test: `verbatim` and `authored` are visually distinct**, so the
  distinction cannot be quietly dropped by a later styling change.
- The three existing suites stay green: `flutter test`, the Python extractor
  suite, and `flutter test integration_test -d windows`.

## Files

| File | Change |
|---|---|
| `LICENSE` | new — MIT |
| `LICENSES/CC-BY-SA-4.0.txt` | new — full licence text |
| `NOTICE.md` | new — the split, and the §3(a) notice list |
| `assets/data/LICENSE` | new — stub pointing at the CC text |
| `README.md` | licence table |
| `pubspec.yaml` | real `description` |
| `lib/models/text_provenance.dart` | new — `TextProvenance`, `SourcedText` |
| `lib/models/base_effect.dart` | `description` becomes `SourcedText` |
| `lib/models/spell.dart` | `summary`, `description` become `SourcedText` |
| `lib/data/database/app_database.dart` | v10 bump, drop `spells` |
| `lib/presentation/screens/about_screen.dart` | new |
| `lib/presentation/screens/configuration_screen.dart` | "About & Licences" entry |
| `lib/main.dart` | `LicenseRegistry.addLicense()` |
| `scripts/spell_import/emit.py` | emit `SourcedText` for extracted text |
| `assets/data/*.json` | regenerated in the new shape |
| ARB files | About-screen chrome only |

## Consequences for other items

| Item | What this settles |
|---|---|
| **56** | The "UI copy vs. catalog data" fork resolves to **catalog data**. A hardcoded English string cannot be attributed, cited, or edition-swapped. Hints carry `verbatim` text plus a citation. |
| **78** | The source marker on a quote *is* the page-reference affordance. One control, not two. |
| **31** | Ledger-authored summaries must be `authored`. This constraint is what makes item 31 safe to do rather than a mis-attribution waiting to happen. |
| **80.3** | Already correct, and load-bearing here: rules text bypassing ARB is what keeps a verbatim quote in its source language. |
| **82** | `translated` and ARB's `x-translation-status` are one convention across the two stores 82 identifies. The resolution-order table answers 82.3 for the catalog store. |
| **30** | Same provenance ethos; the §3(a) URI names the pinned `ffc1c6b` rather than a moving branch. |

**One new item to file — *Source editions: the work/edition distinction*.** An
officially published translation is a second edition of the *same work*, and two
things cannot express that today:

1. **`Book` cannot describe an edition.** `lib/models/book.dart` holds
   `id`/`title`/`abbreviation`/`edition`, where `edition` means "5e", not a
   language edition. It needs `language`, `workId`, and the per-book §3(a)
   fields (`creators`, `copyrightNotice`, `licenceId`, `uri`,
   `modificationNote`) that make section 2's notice list data-driven.
2. **Book-scoping would misfire, and this is the load-bearing half.**
   `scripts/spell_import/catalog.py`'s `visible_books()` enforces DECISIONS.md's
   rule that *a spell may only use rows from books it could have been printed
   against*. A translated edition of the same work is not a different book under
   that rule — but as a fresh `books.json` row it would read as one, so a core
   spell would either lose access to its own guidelines or wrongly widen its
   candidate set. **Scoping must key on work id; language selection keys on
   edition.**

A corollary that keeps the arithmetic safe: a translated edition must populate
per-locale text against the **existing** guideline ids (`cran-1` stays
`cran-1`). A parallel per-language catalog would fork the level computation.

File it against the importer theme alongside item 77 — 77.1's latent
parameter-collision defect is the same seam, and both go live on the same
trigger.
