# GRIB2 Code Table 4.2 — Parameter Lookup

Code Table 4.2 maps `(discipline, parameterCategory, parameterNumber)` to named physical quantities.

**Do not embed table data in context.** Use the `grib2-table` tool to query parameters on demand.

## The Tool: `grib2-table`

Located at: `claude/skills/grib2/grib2-table`

Fetches from NCEP's official GRIB2 parameter tables. Results are cached for 1 day in `~/.cache/grib2-tables/`. Outputs TSV to stdout — pipe to `grep`, `column -t`, etc.

### Usage

```bash
# Lookup a specific parameter by triplet
grib2-table 0 0 0
# → 0  TMP  Temperature  K  (0,0,0)

# List all parameters in a category
grib2-table -d 0 -c 1          # All Moisture parameters
grib2-table -d 0 -c 2          # All Momentum (wind) parameters

# List categories for a discipline
grib2-table -d 0               # Meteorological categories
grib2-table -d 2               # Land surface categories

# List all disciplines
grib2-table                    # Shows discipline numbers and names

# Search by name (case-insensitive, searches across all categories)
grib2-table -s temperature
grib2-table -s "wind speed"
grib2-table -s precipitation

# Clear cache
grib2-table --clear-cache
```

### Output Format

Tab-separated: `number`, `abbrev`, `name`, `units`, `triplet`

```
number  abbrev  name                units   triplet
0       TMP     Temperature         K       (0,0,0)
1       VTMP    Virtual Temperature K       (0,0,1)
```

Local-use parameters (192+) are tagged `[NCEP]` in the name column.

## How to Read the Triplet

```
(discipline, parameterCategory, parameterNumber)
     ↑              ↑                  ↑
  Section 0      Section 4          Section 4
  (0=Meteo)    (Code Table 4.1)   (Code Table 4.2)
```

## Parameter Number Ranges

- **0-191**: WMO standard parameters (consistent across all producers)
- **192-254**: Reserved for local use by the originating center (NCEP, ECMWF, JMA define these differently)
- **255**: Missing

Local-use parameters (192+) are the primary source of "unknown" parameters when processing data from different centers. The same number means completely different things depending on who produced the file.

## Looking Up Unknown Parameters

When wgrib2 outputs a verbose string like `var discipline=0 master_table=33 parmcat=2 parm=62`:

```bash
# Parse out the triplet and look it up
grib2-table 0 2 62
```

If no result, the parameter may be:
1. From a newer WMO master table version than NCEP has published
2. A local-use parameter from a non-NCEP center
3. Check ECMWF's parameter database: <https://codes.ecmwf.int/grib/param-db/>

### Normalizing Unknown Names

When name resolution fails, normalize to: `unknown_{discipline}_{category}_{number}` (e.g., `unknown_0_2_62`).

## References

- NCEP GRIB2 tables (primary source): <https://www.nco.ncep.noaa.gov/pmb/docs/grib2/grib2_doc/>
- WMO Code Table 4.2: <https://codes.wmo.int/grib2/codeflag/4.2>
- ECMWF Parameter Database: <https://codes.ecmwf.int/grib/param-db/>
