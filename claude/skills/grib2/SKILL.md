---
name: grib2
description: GRIB2 file format expert — structure, code tables, wgrib2 usage, and the variable/band/message data model for meteorological data
---

# GRIB2 Expert Skill

You are an expert on the WMO GRIB2 (GRIdded Binary Edition 2) file format, its code tables, tooling (especially wgrib2), and the conceptual data model of variables, bands, and messages in meteorological data.

## When to Use Sub-Skills

This skill is split across multiple files. Read the relevant sub-skill when deeper detail is needed:

- `format.md` — GRIB2 file structure (sections 0-8), encoding, and how messages are organized
- `table-4.2.md` — Code Table 4.2 reference and the `grib2-table` CLI tool for querying parameters by triplet or name
- `wgrib2.md` — wgrib2 tool: indexing, matching, slicing, extraction, and common recipes
- `data-model.md` — How variables, bands, and messages relate; identity vs coordinates; the Variable = Parameter + Statistical Processing + Level + TimeStep model

## Key Concepts (Quick Reference)

### One GRIB2 Message = One Variable

A GRIB2 file is a concatenation of self-contained **messages**. Each message encodes a single 2D grid of values for one specific combination of:

- **Parameter** — what is being measured (e.g., Temperature) — identified by the GRIB2 triplet `(discipline, parameterCategory, parameterNumber)`
- **Statistical processing** — how it was derived (instant, accumulated, averaged, min, max)
- **Level** — where vertically (e.g., 2 m above ground, 850 hPa)
- **Time step** — when (forecast hour or time range)

### The GRIB2 Triplet

The canonical identity for a parameter: `(discipline, parameterCategory, parameterNumber)` from Code Table 4.2.

For meteorological data, `discipline = 0`. Categories include:
- 0 = Temperature
- 1 = Moisture
- 2 = Momentum (wind)
- 3 = Mass (pressure, height)
- 6 = Cloud
- 7 = Thermodynamic stability

### Naming Systems

There are multiple naming systems for parameters — they don't always agree:

| System | Example for Temperature | Source |
|--------|------------------------|--------|
| GRIB2 triplet | `(0, 0, 0)` | WMO Code Table 4.2 |
| wgrib2 / NCEP abbreviation | `TMP` | NCEP parameter tables |
| ecCodes shortName | `t` (or `t2m` at 2m) | ECMWF parameter database |
| CF standard name | `air_temperature` | CF conventions |

**Preferred strategy**: GRIB2 triplet as ground truth for identity, wgrib2/NCEP abbreviations as primary display names.

### Identity vs Coordinate

- **Identity** (defines *what* the quantity is): Parameter + Statistical Processing
- **Coordinate** (defines *where/when* it was sampled): Level + Time Step

"Temperature at 850 hPa" and "Temperature at 500 hPa" are the same quantity at different coordinates. "Instantaneous temperature" and "6-hour average temperature" are **different quantities**.

## Common Tasks

| Task | Approach |
|------|----------|
| List all messages in a file | `wgrib2 file.grib2` (produces index) |
| Extract specific variables | `wgrib2 file.grib2 -match ':TMP:' -grib out.grib2` |
| Look up a parameter by triplet | `grib2-table 0 0 0` (see `table-4.2.md`) |
| Search parameters by name | `grib2-table -s "wind speed"` |
| List all params in a category | `grib2-table -d 0 -c 1` (Moisture) |
| Decode a wgrib2 index line | See `wgrib2.md` for field-by-field breakdown |
| Understand message structure | See `format.md` for section-by-section layout |
| Map between naming systems | See `data-model.md` for naming strategy |

## Resources

- WMO GRIB2 Code Tables: <https://codes.wmo.int/grib2/codeflag>
- NCEP GRIB2 Parameter Tables: <https://www.nco.ncep.noaa.gov/pmb/docs/grib2/grib2_doc/>
- wgrib2 documentation: <https://www.cpc.ncep.noaa.gov/products/wesley/wgrib2/>
- ecCodes: <https://confluence.ecmwf.int/display/ECC>
- ECMWF Parameter Database: <https://codes.ecmwf.int/grib/param-db/>
