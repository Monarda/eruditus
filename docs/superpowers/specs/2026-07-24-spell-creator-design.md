---
title: Eruditus Spell Creator - Design Specification
date: 2026-07-24
version: 1.0
status: Approved
---

# Eruditus Spell Creator - Design Specification

## Executive Summary

Eruditus is a Flutter-based cross-platform application for creating Ars Magica spells. The MVP focuses on iOS, with future expansion to web and desktop. Users can create new spells by selecting predefined base effects, parameters, and special factors. The system automatically calculates spell levels, suggests similar existing spells, and allows users to build a personal spell library backed up to the cloud.

## Goals & Success Criteria

**MVP Goals:**
- Enable intuitive spell creation without requiring users to know base levels
- Suggest similar existing spells based on Technique+Form matching
- Support custom parameters, effects, and special factors
- Store spells locally with cloud backup capability
- Provide a pleasant iOS user experience

**Success Criteria:**
- User can create a spell in under 2 minutes
- Spell library contains 50+ built-in spells from core rules
- System accurately calculates all spell levels per Ars Magica rules
- Custom configuration persists across app sessions
- Cloud backup/restore works without data loss

## Scope: MVP vs. Future

**MVP (Phase 1):**
- Spell creation with base effects, parameters, special factors, requisites
- Built-in spell library (Ars Magica core rules)
- Spell suggestions (Technique+Form matching)
- Custom effects, parameters, special factors
- Local storage + cloud backup (export/import)
- iOS platform

**Future Phases:**
- Web and desktop platforms
- Spell library sharing between users
- Enchanted item creation
- Character spellcasting simulator
- Spell experimentation system
- Breakthrough tracking

---

## Architecture

### Layered Design

```
┌─────────────────────────────────────────┐
│   Presentation Layer                    │
│   (Flutter Widgets & Screens)           │
├─────────────────────────────────────────┤
│   Business Logic Layer                  │
│   (Spell Engine & BLoCs)                │
├─────────────────────────────────────────┤
│   Data Layer                            │
│   (Repositories & Services)             │
├─────────────────────────────────────────┤
│   Data Models & Persistence             │
│   (SQLite & JSON)                       │
└─────────────────────────────────────────┘
```

### Key Components

**Presentation Layer:**
- `SpellCreationScreen`: Main form for creating spells
- `SpellLibraryScreen`: Browse and search spells
- `ConfigurationScreen`: Manage custom effects/parameters/factors
- `BackupScreen`: Export/import to cloud

**Business Logic Layer:**
- `SpellEngine`: Spell validation, level calculation, suggestion matching
- `SpellCreationBloc`: Manages spell creation state
- `SpellLibraryBloc`: Manages library queries and filtering
- `ConfigurationBloc`: Manages custom configuration

**Data Layer:**
- `SpellRepository`: CRUD operations on user spells (SQLite)
- `LibraryRepository`: Load and search built-in spells
- `ConfigurationRepository`: Manage custom effects/parameters/factors
- `BackupService`: JSON export/import to cloud

**Data Models:**
- `Spell`: Complete spell definition with all properties
- `SpellDraft`: Temporary unsaved spell during creation
- `BaseEffect`: Effect description and base level
- `Parameter`: Named parameter with magnitude
- `SpecialFactor`: Technique+Form-specific modifier
- `Requisite`: Art with type (required/additional)

---

## Data Model Details

### Spell Class

```dart
class Spell {
  String id;                                    // Unique identifier
  String? name;                                 // Optional (required only for library)
  String technique;                             // Creo, Intellego, Muto, Perdo, Rego, Vim
  String form;                                  // Animal, Aquam, Auram, Corpus, Herbam, Ignem, Imaginem, Mentem, Terram, Vim
  BaseEffect baseEffect;                        // Selected effect (description + base level)
  List<SelectedParameter> parameters;           // Range, Duration, Target, custom
  List<String> selectedSpecialFactors;          // IDs of selected special factors
  List<RequiredRequisite> requiredRequisites;   // Arts needed for spell to function (free)
  List<AdditionalRequisite> additionalRequisites; // Arts that add effects (+1 mag each)
  String? description;                          // User-entered notes
  String source;                                // "built-in" or "user-created"
  DateTime createdAt;
  DateTime updatedAt;
  
  int get calculatedSpellLevel => _calculateLevel();
  int get totalMagnitude => _sumMagnitudes();
}
```

### BaseEffect Class

```dart
class BaseEffect {
  String id;
  String technique;
  String form;
  String description;                           // e.g., "Create a pillar of flame"
  int baseLevel;
  String source;                                // "built-in" or "user-created"
}
```

### Parameter Class

```dart
class Parameter {
  String id;
  String name;                                  // e.g., "Voice", "Touch", "Sun"
  String category;                              // "Range", "Duration", "Target", or custom
  int magnitude;                                // e.g., +2
  String source;                                // "built-in" or "user-created"
}

class SelectedParameter {
  String parameterId;
  Parameter parameter;                          // Resolved at runtime
}
```

### SpecialFactor Class

```dart
class SpecialFactor {
  String id;
  String technique;                             // e.g., "Creo"
  String form;                                  // e.g., "Imaginem"
  String name;                                  // e.g., "Increasing Sensory Complexity"
  String description;                           // e.g., "moving visual or clear words"
  int magnitude;                                // e.g., +1
  String source;                                // "built-in" or "user-created"
}
```

### Requisite Classes

```dart
class RequiredRequisite {
  String art;                                   // Art (Technique) needed for spell
  bool isMandatory;                             // Always true for required
}

class AdditionalRequisite {
  String art;                                   // Art that adds extra effects
  int magnitude;                                // Always +1 per requisite
}
```

---

## Spell Level Calculation

### Algorithm

Spell levels use a two-tier system where magnitudes add additively until reaching level 5, then multiply by 5 thereafter.

```
Algorithm:
  level = baseLevel
  additive_capacity = max(0, 5 - baseLevel)
  
  for each magnitude m (from all sources):
    if additive_capacity > 0:
      additive_portion = min(m, additive_capacity)
      multiplier_portion = m - additive_portion
      level += additive_portion
      additive_capacity -= additive_portion
      level += (multiplier_portion × 5)
    else:
      level += (m × 5)
  
  return level
```

### Magnitude Sources

Magnitudes come from (in order of application):
1. **Base Effect**: Encoded in the effect itself (starting level)
2. **Parameters**: Range, Duration, Target, and custom parameters
3. **Special Factors**: Technique+Form-specific modifiers
4. **Additional Requisites**: Arts that add extra effects (+1 mag each)

### Examples

**Eyes of the Cat (MuCo(An) 5)**
- Base 2 (Muto Corpus effect)
- Touch (+1 mag)
- Sun (+2 mag)
- Required: Animal (free)
- Calculation: 2 + 1 + 2 = 5 ✓

**Seal the Earth (CrTe 15)**
- Base 1
- Voice (+2 mag)
- Sun (+2 mag)
- Group (+2 mag)
- Calculation: 1 + 2 + 2 = 5, then +2×5 = 15 ✓

**Haunt of the Living Ghost (CrIm 35)**
- Base 2
- Arc (+4 mag)
- Conc (+1 mag)
- Move at command (+2 mag)
- Intricacy (+1 mag)
- Intellego requisite (+1 mag)
- Calculation: 2 + 3 (Arc) = 5, then (1+1+2+1+1)×5 = 30, total = 35 ✓

---

## User Interface Flow

### Main Navigation

Bottom tab bar with four sections:
1. **Create** - Spell creation form
2. **Library** - Browse spells
3. **Settings** - Configuration
4. **Backup** - Cloud export/import

### Spell Creation Flow

1. **Select Technique**
   - Dropdown list of 6 Techniques
   - Advances to Form selection

2. **Select Form**
   - Dropdown list of 10 Forms
   - Loads available Base Effects for this Technique+Form

3. **Choose Base Effect**
   - List of built-in effects + custom effects
   - Each shows: description, base level, source badge
   - User selects one (required)

4. **Add Parameters**
   - Three sections: Range, Duration, Target
   - Each is a dropdown with built-in + custom options
   - Selected parameters appear as removable "pills"
   - Multiple selections allowed (user rarely needs more than one per category)

5. **Select Special Factors** (if applicable)
   - Checkboxes for Technique+Form-specific factors
   - Each shows: name, magnitude, description
   - Zero or more can be selected

6. **Choose Requisites**
   - **Required Requisites** dropdown: Arts needed for spell to work (free)
   - **Additional Requisites** multi-select: Arts that add effects (+1 mag each)
   - Selected additional requisites appear as pills with "+1" badge

7. **Real-time Spell Level Display**
   - Shows calculated level and breakdown
   - Updates as user makes selections

8. **Action Buttons**
   - "Calculate & View Suggestions" — proceeds to suggestions view

### Suggestions View

After calculation:
- Shows the unnamed spell (e.g., "Creo Ignem - Level 25")
- Displays all matching spells from library (same Technique+Form)
- Each spell card shows: name, level, source, description
- User can:
  - "Save to Library" → prompts for spell name, saves to local DB
  - "Discard" → returns to creation form
  - "View All Library Spells" → opens library browser

### Spell Library Screen

- Search bar (search by name)
- Tab filters: "All", "Built-in", "My Spells"
- List of spells with:
  - Name
  - Technique+Form
  - Level
  - Source badge
  - Short description
- Tap spell for detail view (read-only for built-ins, editable for user-created)

### Configuration Screen

Three sections:

**1. Base Effects**
- Built-in effects per Technique+Form (read-only)
- "Add Custom Effect" button
- Edit/delete custom effects

**2. Parameters**
- Built-in parameters grouped by category (read-only)
- "Add Custom Parameter" button
- Edit/delete custom parameters

**3. Special Factors**
- Built-in factors per Technique+Form (read-only)
- "Add Custom Factor" button
- Edit/delete custom factors

### Backup Screen

- **Backup Status**: Last backup timestamp, sync status
- **Export Button**: "Backup to Cloud" → uploads JSON to cloud service
- **Import Button**: "Restore from Cloud" → fetches latest backup
- **Conflict Resolution**: If local and cloud differ, user chooses which to keep
- **Manual Export**: "Export as File" → saves JSON to device storage
- **Manual Import**: "Import from File" → loads JSON from device storage

---

## Data Storage

### Local Storage (SQLite)

**Tables:**
- `spells`: User-created spells
- `custom_effects`: User-defined base effects
- `custom_parameters`: User-defined parameters
- `custom_factors`: User-defined special factors
- `sync_metadata`: Cloud backup tracking (timestamps, status)

### Built-in Data (Bundled JSON)

```
assets/data/
  ├── base_effects.json          # All effects for all Technique+Form combinations
  ├── parameters.json            # All standard parameters (Range, Duration, Target, etc.)
  ├── special_factors.json       # All technique-specific factors
  └── spell_library.json         # 50+ core spells from rulebooks
```

### Cloud Backup Format

Exported JSON structure:
```json
{
  "version": "1.0",
  "exportDate": "2026-07-24T14:30:00Z",
  "spells": [
    {
      "id": "user-spell-1",
      "name": "My Fireball",
      "technique": "Creo",
      "form": "Ignem",
      "baseEffect": {
        "description": "Create pillar of flame",
        "baseLevel": 10
      },
      "parameters": [
        {"parameterName": "Voice", "magnitude": 2},
        {"parameterName": "Concentration", "magnitude": 1}
      ],
      "specialFactors": ["directed-image"],
      "requiredRequisites": [],
      "additionalRequisites": ["Rego"],
      "spellLevel": 30
    }
  ],
  "customParameters": [...],
  "customEffects": [...],
  "customFactors": [...]
}
```

### Cloud Sync Strategy

**MVP Approach (User-Initiated):**
- No automatic sync
- User manually taps "Backup to Cloud" or "Restore from Cloud"
- Conflict resolution: on import, if spell name matches existing, user chooses to replace, keep local, or rename imported version
- Cloud provider TBD (Firebase Firestore, simple REST backend, or similar)

---

## Spell Engine (Business Logic)

### Core Responsibilities

1. **Spell Validation**
   - Technique + Form are valid
   - Base effect exists for the Technique+Form
   - Parameters exist in the database
   - Requisites are valid Arts

2. **Spell Level Calculation**
   - Apply two-tier algorithm correctly
   - Handle magnitude sources (parameters, factors, additional requisites)
   - Return calculated level

3. **Suggestion Matching**
   - Query library for spells matching Technique+Form
   - Sort by level (closest matches first)
   - Return with source attribution

4. **Spell Normalization**
   - Convert SpellDraft to Spell on save
   - Ensure all required fields are present
   - Validate before persistence

### Error Handling

**Validation Errors (caught before save):**
- Technique not selected
- Form not selected
- Base effect not selected
- Invalid parameters
- Invalid requisites

**Data Integrity:**
- Requisite Arts must exist in Arts list
- Parameters must reference existing Parameter IDs
- Special factors must reference existing SpecialFactor IDs

**Cloud Errors:**
- Network timeout → show retry prompt
- Malformed JSON on import → show error with details
- Version mismatch → handle gracefully (inform user, offer options)

---

## BLoC State Management

### SpellCreationBloc

**Events:**
- `TechniqueSelected(String technique)`
- `FormSelected(String form)`
- `BaseEffectSelected(BaseEffect effect)`
- `ParameterAdded(Parameter parameter)`
- `ParameterRemoved(String parameterId)`
- `SpecialFactorToggled(String factorId, bool selected)`
- `RequisiteAdded(Requisite requisite)`
- `RequisiteRemoved(String requisite)`
- `SpellCalculated()`
- `SpellSaveRequested(String? name)`
- `SpellDiscarded()`

**States:**
- `SpellCreationInitial`
- `TechniqueSelecting`
- `FormSelecting`
- `BaseEffectSelecting`
- `SpellFormValid(currentSpellDraft, suggestedSpells)`
- `SpellSaving`
- `SpellSaved(Spell savedSpell)`
- `SpellDiscarded`
- `SpellCreationError(String message)`

### SpellLibraryBloc

**Events:**
- `LibraryLoaded()`
- `SearchQueryChanged(String query)`
- `FilterChanged(String filterType)` // "All", "Built-in", "My Spells"
- `SpellSelected(Spell spell)`

**States:**
- `LibraryLoading`
- `LibraryLoaded(List<Spell> spells, int totalCount)`
- `SpellDetailView(Spell spell, bool isEditable)`
- `LibraryError(String message)`

### ConfigurationBloc

**Events:**
- `CustomEffectAdded(BaseEffect effect)`
- `CustomEffectDeleted(String effectId)`
- `CustomParameterAdded(Parameter parameter)`
- `CustomParameterDeleted(String parameterId)`
- `CustomFactorAdded(SpecialFactor factor)`
- `CustomFactorDeleted(String factorId)`
- `ConfigurationLoaded()`

**States:**
- `ConfigurationLoading`
- `ConfigurationLoaded(customEffects, customParameters, customFactors)`
- `ConfigurationUpdated()`
- `ConfigurationError(String message)`

---

## Testing Strategy

### Unit Tests (Spell Engine)

- Spell level calculation (all two-tier scenarios)
- Magnitude summation with various base levels
- Suggestion matching algorithm
- Validation logic for all field types

### Integration Tests

- Spell creation → suggestion display → save flow
- Load built-in library
- Custom effect/parameter/factor creation and persistence
- Cloud backup JSON serialization

### Manual Testing

- Test iOS UI on real device
- Verify spell creation with 20+ different spell types
- Test cloud backup with network interruptions
- Test configuration persistence across app restarts

---

## Assumptions & Constraints

**Assumptions:**
- User has basic familiarity with Ars Magica rules (the app is not a tutorial)
- Internet connection for cloud backup (cached offline is nice-to-have)
- iOS 12+ (standard Flutter support)

**Constraints:**
- MVP limited to iOS (web/desktop future)
- No real-time collaboration/sharing (future phase)
- Cloud backup is manual, not automatic (MVP simplicity)
- Requisite handling follows core book rules (supplements handled via custom factors)

---

## Success Metrics

- User can create 5 different spells without error
- Spell library contains 50+ working spells from core rules
- Cloud backup/restore works with zero data loss
- App responds to user input within 200ms
- No crashes on iOS 12+

---

## Open Questions / Future Considerations

- Cloud provider selection (Firebase vs. custom backend)
- Spell library expansion (which supplement books to include in MVP)
- Advanced filtering (by level range, by requisites, etc.)
- Spell export/share format (compatible with other tools?)
- Mobile-optimized UI vs. responsive design for future web/desktop

