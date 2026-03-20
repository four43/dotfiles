# GRIB2 Data Model — Variables, Bands, and Messages

This describes how GRIB2 messages map to the conceptual data model of **variables** in meteorological data, and how identity, coordinates, and naming systems interact.

## The Core Equation

```text
Variable = (Parameter + Statistical Processing) + Level + TimeStep
```

| Component | What it answers | Identity or Coordinate? |
| --------- | -------------- | ---------------------- |
| **Parameter** | *What* is being measured? | Identity |
| **Statistical Processing** | *How* was it derived? (instant, accum, avg) | Identity |
| **Level** | *Where* vertically? | Coordinate |
| **Time Step** | *When* (forecast hour/range)? | Coordinate |

### Identity vs Coordinate

This distinction is fundamental to correctly organizing GRIB2 data:

- **Identity** defines *what* the quantity is. Two values with different identities are different physical quantities — they cannot be stacked or compared.
- **Coordinate** defines *where/when* the quantity was sampled. Two values with the same identity but different coordinates stack along a dimension.

Examples:

- "TMP at 850 hPa" and "TMP at 500 hPa" → same identity, different level coordinate → stack into pressure-level dimension
- "TMP at hour 12" and "TMP at hour 24" → same identity, different time coordinate → stack into time dimension
- "Instantaneous TMP" and "6-hour average TMP" → **different identities** → different physical quantities, different DataArrays

Statistical processing is part of identity because it changes the physical meaning: an instantaneous value and an averaged value are fundamentally different things, potentially with different units.

## Terminology

| Term | Scope | Example |
| ---- | ----- | ------- |
| **Variable** | Format-agnostic concept | "2-meter instantaneous temperature in Kelvin" |
| **Band** | GRIB2-specific implementation | A `Band` parsed from a GRIB2 message via ecCodes + wgrib2 |
| **Message** | GRIB2 file structure | One self-contained record in a GRIB2 file |
| **Parameter** | The physical quantity alone | "Temperature" — without level, time, or processing |

**One GRIB2 message = one band = one variable** (at a specific coordinate point).

## The Band Data Structure

A `Band` is the code-level representation of a GRIB2 message's metadata:

```text
Band
├── parameter: Parameter
│   ├── grib2_key: (discipline, category, number)  ← canonical identity
│   ├── name: str                                   ← from ecCodes
│   ├── param_id: int | None                        ← ecCodes paramId
│   └── wgrib2_param: str                           ← from wgrib2 (e.g., "TMP")
├── level: Level
│   ├── type: str                                   ← e.g., "isobaricInhPa"
│   ├── wgrib2_level: str                           ← from wgrib2 (e.g., "850 mb")
│   └── details: LevelDetails                       ← scaled surface values
├── time_step: TimeStep
│   ├── range: (float, float | None)                ← start, end
│   ├── time_unit: str                              ← "hours", "minutes"
│   ├── agg_type: str                               ← "instant", "accum", etc.
│   └── wgrib2_time_step: str                       ← from wgrib2 (e.g., "3 hour fcst")
└── units: str                                      ← e.g., "K", "m s**-1"
```

A Band is constructed from two data sources:

1. **ecCodes GRIB message handle** — structured metadata (triplet, level type, step range, units)
2. **wgrib2 index line** — human-readable strings for matching and display

## Parameter Identity: The GRIB2 Triplet

The canonical identifier: `(discipline, parameterCategory, parameterNumber)` from WMO Code Table 4.2.

- Always present in GRIB2 Section 4
- Machine-readable and unambiguous within a master table version
- **Equality is based on the triplet**, not on names or paramId

### Four Naming Systems

| System | Example (Temperature) | Source | Pros | Cons |
| ------ | --------------------- | ------ | ---- | ---- |
| GRIB2 triplet | `(0, 0, 0)` | WMO Code Table 4.2 | Unambiguous, always present | Not human-readable; local-use (192+) is producer-specific |
| wgrib2 / NCEP abbreviation | `TMP` | NCEP parameter tables | Human-readable, doesn't conflate level into name | NCEP-centric; verbose fallback for unknowns |
| ecCodes paramId / shortName | `t` or `t2m` | ECMWF parameter database | Comprehensive (GRIB1 + GRIB2) | shortName bakes in level (`t2m` vs `t`); paramId=0 for unknowns |
| CF standard name | `air_temperature` | CF conventions | Self-documenting, xarray ecosystem | Verbose, many gaps, not always 1:1 with triplets |

**Strategy**: GRIB2 triplet as ground truth, wgrib2/NCEP abbreviations as primary display names.

Why wgrib2 names win for display:

- We ship wgrib2 indexes alongside GRIB2 files
- NCEP names don't conflate level into the parameter name
- De facto standard in operational US meteorology
- Short enough for DataTree paths

## Levels

A level defines the vertical position. Identified by:

- **Type** (`typeOfLevel`): e.g., `isobaricInhPa`, `heightAboveGround`, `surface`
- **Value(s)**: e.g., 850, 2, 0-0.1

### Single Level vs Layer

- **Single level**: One surface value — `isobaricInhPa = 850` (the 850 hPa surface)
- **Layer**: Two surface values — `depthBelowLandLayer = 0-0.1` (0 to 10 cm depth)

### The Level-Type Problem

The same physical level can be encoded differently:

- "2 meters above ground" could be `heightAboveGround(2)` or `heightAboveGroundLayer(0, 2)`
- This causes identical data to land in different tree branches

## Statistical Processing (Aggregation Type)

| Type | Meaning | Example |
| ---- | ------- | ------- |
| `instant` | Snapshot at a point in time | Temperature at hour 12 |
| `accum` | Accumulated over interval | Total precipitation 0-6 hours |
| `avg` | Averaged over interval | Average wind speed 0-6 hours |
| `max` | Maximum over interval | Max temperature 0-6 hours |
| `min` | Minimum over interval | Min temperature 0-6 hours |

In GRIB2, this comes from Code Table 4.10 (`typeOfStatisticalProcessing`) in Product Definition Templates 8+. For instantaneous values (template 0), there is no statistical processing.

## Time Step

| Field | Meaning | Example |
| ----- | ------- | ------- |
| `range` | Start and optional end of forecast time | `(12.0, None)` = hour 12; `(0.0, 6.0)` = 0-6 hour range |
| `time_unit` | Unit | `"hours"`, `"minutes"` |
| `agg_type` | Statistical processing | `"instant"`, `"accum"` |
| `wgrib2_time_step` | Original wgrib2 string | `"32 hour fcst"`, `"0-6 hour acc fcst"` |

## DataTree Mapping

In an xarray DataTree, variable components map to tree structure:

```text
/{wgrib2_param}/{agg_type}/
    DataArray(typeOfLevel) with dims [time, level, y, x]
```

- **Parameter** → first path level (e.g., `TMP`)
- **Statistical processing** → second path level (e.g., `instant`, `avg`)
- **Level type** → data variable name (e.g., `isobaricInhPa`)
- **Level value** → coordinate dimension within each DataArray
- **Time step** → coordinate dimension within each DataArray

Example tree:

```text
/TMP/instant/
    isobaricInhPa  [time=4, level=37, y=721, x=1440]
    heightAboveGround  [time=4, level=1, y=721, x=1440]
/TMP/avg/
    heightAboveGround  [time=4, level=1, y=721, x=1440]
/APCP/accum/
    surface  [time=4, y=721, x=1440]
```

## Unknown Parameters

When wgrib2 or ecCodes can't resolve a parameter name:

- **wgrib2 output**: `"var discipline=0 master_table=33 parmcat=2 parm=62"` → normalize to `unknown_0_2_62`
- **ecCodes output**: `paramId=0`, `name="unknown"` → `param_id=None`

Sources of unknowns:

1. Newer WMO master table version than the software supports
2. Local-use parameters (192-254) from a center whose tables aren't loaded
3. Producer-specific extensions

### ecCodes Definition Overrides

Unknown parameters can be taught to ecCodes via custom definition files:

```text
ENV ECCODES_DEFINITION_PATH=/MEMFS/definitions:/app/data/eccodes_definitions
```

For each center, maintain files under `data/eccodes_definitions/grib2/localConcepts/{center}/`:

- `shortName.def` — abbreviation
- `name.def` — human-readable name
- `units.def` — units

This extends (not replaces) built-in definitions. Note: wgrib2 has separate parameter tables and won't pick up ecCodes definitions.

## Key Invariants

1. **One message = one variable at one coordinate point** (one parameter + processing type + level + time step)
2. **Every file open must yield the same number of DataArrays as source messages** — no clobbering, no silent drops
3. **Parameter identity is the triplet** — name resolution can fail without losing identity
4. **Statistical processing is part of identity, not a coordinate** — instant and averaged values of the same parameter are different quantities
5. **Local-use parameters (192+) require center context** — the same number means different things from different producers
