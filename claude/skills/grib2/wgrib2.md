# wgrib2 — Indexing, Matching, and Slicing GRIB2 Files

wgrib2 is the primary command-line tool for working with GRIB2 files. It reads, inventories, extracts, converts, and manipulates GRIB2 data. Developed by NCEP/CPC.

Documentation: <https://www.cpc.ncep.noaa.gov/products/wesley/wgrib2/>

## Core Concepts

### The Inventory (Index)

The fundamental operation is producing an **inventory** — a text listing of all messages (fields/records) in a GRIB2 file. Every other operation builds on this.

```bash
wgrib2 file.grib2
```

Output format (one line per message):
```
1:0:d=2024010100:TMP:2 m above ground:anl:
2:4283914:d=2024010100:TMP:2 m above ground:3 hour fcst:
3:8567828:d=2024010100:RH:2 m above ground:anl:
```

Fields are colon-separated:
```
{msg_num}:{byte_offset}:d={init_time}:{param}:{level}:{time_step}:
    1          2              3           4       5         6
```

| Field | Meaning |
|-------|---------|
| `1` | Message number (1-based) |
| `0` | Byte offset from start of file |
| `d=2024010100` | Reference (initialization) time: YYYYMMDDHH |
| `TMP` | Parameter name (NCEP abbreviation) |
| `2 m above ground` | Level description |
| `anl:` or `3 hour fcst:` | Time step / forecast time |

### Index Files (`.idx`)

An index file is just the inventory saved to a file. This is **essential** for efficient random access — without it, you must scan the entire file sequentially.

```bash
# Create index
wgrib2 file.grib2 > file.grib2.idx

# Use index for extraction (wgrib2 reads the idx to find byte offsets)
wgrib2 file.grib2 -i -grib subset.grib2 < file.grib2.idx
```

The byte offset field allows seeking directly to a message without reading the entire file. This is how large GRIB2 files (multi-GB) are efficiently subsetted.

### Extended Inventory Options

More detailed inventory with `-v` flags:

```bash
# Verbose inventory — adds more metadata
wgrib2 -v file.grib2

# Very verbose — includes packing info, grid details
wgrib2 -V file.grib2

# Show specific metadata fields
wgrib2 -varX file.grib2          # Shows discipline/category/number triplet
wgrib2 -center file.grib2        # Originating center
wgrib2 -packing file.grib2       # Data packing type
wgrib2 -npts file.grib2          # Number of grid points
wgrib2 -grid file.grib2          # Full grid description
wgrib2 -stats file.grib2         # Min/max/mean of data values
```

Custom inventory format with `-s` (short) or custom templates:

```bash
# Short inventory (commonly used for .idx files)
wgrib2 -s file.grib2

# Custom format
wgrib2 -t -var -lev -ftime file.grib2
```

---

## Matching and Filtering (-match, -not, -if, -fi)

### -match / -not (Regex Matching on Inventory Lines)

The most common way to filter messages. Operates on the **inventory line** for each message.

```bash
# Match by parameter name
wgrib2 file.grib2 -match ':TMP:'

# Match by level
wgrib2 file.grib2 -match ':2 m above ground:'

# Match by parameter AND level (both must appear in same line)
wgrib2 file.grib2 -match ':TMP:' -match ':2 m above ground:'

# Multiple -match flags are AND-ed together

# Exclude messages
wgrib2 file.grib2 -not ':TMP:'

# Match with regex
wgrib2 file.grib2 -match ':(TMP|RH|DPT):'
wgrib2 file.grib2 -match ':([0-9]+ mb):'
wgrib2 file.grib2 -match ':[0-9]+ hour fcst:'
```

**Critical**: Always wrap match patterns in colons (`:pattern:`) to avoid partial matches. Without colons, `:TMP:` would also match `:APTMP:` or `:VTMP:`.

### -if / -fi (Conditional Processing)

Like `-match` but scopes subsequent operations to matching messages:

```bash
# Only apply -grib output for TMP messages
wgrib2 file.grib2 -if ':TMP:' -grib tmp_only.grib2 -fi

# Different outputs for different variables
wgrib2 file.grib2 \
  -if ':TMP:' -grib temperature.grib2 -fi \
  -if ':RH:'  -grib humidity.grib2 -fi
```

### Matching Gotchas

1. **Colons matter**: `:TMP:` matches the parameter TMP. `TMP` without colons matches anywhere in the line.
2. **Multiple -match = AND**: `-match ':TMP:' -match ':500 mb:'` requires both to match.
3. **OR logic**: Use regex alternation: `-match ':(TMP|RH):'`
4. **Level strings are exact**: `'2 m above ground'` is not the same as `'2m above ground'`. Check actual wgrib2 output.
5. **Time step strings vary**: `'anl'`, `'3 hour fcst'`, `'0-6 hour acc fcst'`, `'0-6 hour ave fcst'`. Always check actual output.
6. **Regex is POSIX extended**: No lookahead/lookbehind. Use `[^:]*` to match anything within a field.

---

## Extraction and Slicing (-grib, -bin, -csv, -netcdf)

### Extract to GRIB2 (-grib)

Extract matching messages into a new GRIB2 file (preserving original encoding):

```bash
# Extract all temperature messages
wgrib2 file.grib2 -match ':TMP:' -grib temperature.grib2

# Extract specific level
wgrib2 file.grib2 -match ':TMP:' -match ':850 mb:' -grib tmp_850.grib2

# Extract using index file (efficient for large files)
grep ':TMP:' file.grib2.idx | wgrib2 file.grib2 -i -grib tmp.grib2

# Extract multiple specific messages by number
echo "1" | wgrib2 file.grib2 -i -grib msg1.grib2
```

### Extract to Binary (-bin, -ieee, -float)

```bash
# Raw binary float32 output (one flat array per message)
wgrib2 file.grib2 -match ':TMP:' -no_header -bin tmp.bin
# or
wgrib2 file.grib2 -match ':TMP:' -no_header -ieee tmp.bin

# With header (4-byte record length prefix, Fortran-style)
wgrib2 file.grib2 -match ':TMP:' -bin tmp.bin
```

### Extract to CSV (-csv)

```bash
wgrib2 file.grib2 -match ':TMP:2 m above ground:' -csv output.csv
```

CSV columns: `init_time, valid_time, param, level, lon, lat, value`

Warning: CSV output can be enormous for high-resolution grids. A single 0.25° global field has ~1M+ points.

### Convert to NetCDF (-netcdf)

```bash
wgrib2 file.grib2 -netcdf output.nc

# Subset first, then convert (recommended)
wgrib2 file.grib2 -match ':TMP:' -match ':2 m above ground:' -netcdf tmp_2m.nc
```

NetCDF conversion flattens the data — all messages go into a single file with time/level dimensions. Variable naming in the NetCDF follows wgrib2's conventions.

---

## Grid Operations

### Regridding (-new_grid)

```bash
# Regrid to 1-degree lat/lon
wgrib2 file.grib2 -new_grid latlon 0:360:1 -90:181:1 regridded.grib2

# Regrid to a specific Lambert conformal grid
wgrib2 file.grib2 -new_grid lambert:265:25:25 226.541:1799:3000 12.190:1059:3000 out.grib2

# new_grid syntax for latlon: lon_start:num_lon:dlon lat_start:num_lat:dlat
```

### Subregion (-small_grib, -ijsmall_grib)

```bash
# Extract lat/lon bounding box (lon1:lon2 lat1:lat2)
wgrib2 file.grib2 -small_grib -100:-80 30:50 subset.grib2

# Extract by grid index ranges (i1:i2 j1:j2)
wgrib2 file.grib2 -ijsmall_grib 1:100 1:50 subset.grib2
```

---

## Useful Recipes

### List All Unique Parameters in a File

```bash
wgrib2 file.grib2 -var | sort -u
```

### List All Unique Levels

```bash
wgrib2 file.grib2 -lev | sort -u
```

### List All Unique Forecast Times

```bash
wgrib2 file.grib2 -ftime | sort -u
```

### Get Grid Information

```bash
wgrib2 -d 1 -grid file.grib2
```

### Count Messages

```bash
wgrib2 file.grib2 | wc -l
```

### Get Min/Max/Mean of Data Values

```bash
wgrib2 file.grib2 -match ':TMP:2 m above ground:' -stats
```

### Append Messages to Existing File

```bash
# -append flag adds to existing output file instead of overwriting
wgrib2 file.grib2 -match ':TMP:' -grib -append collection.grib2
```

### Set/Change Metadata (-set)

```bash
# Change the parameter
wgrib2 file.grib2 -set_var TMP -grib out.grib2

# Change the level
wgrib2 file.grib2 -set_lev "2 m above ground" -grib out.grib2
```

### Merge Multiple GRIB2 Files

```bash
# Simply concatenate (GRIB2 files are just concatenated messages)
cat file1.grib2 file2.grib2 > merged.grib2

# Or use wgrib2 with -append
for f in *.grib2; do
  wgrib2 "$f" -grib -append merged.grib2
done
```

### Get the GRIB2 Triplet (-varX)

`-varX` appends a 7th colon-separated field to each inventory line encoding the full
parameter identity as `var{discipline}_{master_table_version}_{local_table_version}_{master_table_number}_{category}_{number}`.

```bash
wgrib2 -varX file.grib2
```

Example output:
```
1:0:d=2026032012:TMP:2 m above ground:360 hour fcst::var0_2_1_7_0_0
2:513114:d=2026032012:DPT:2 m above ground:360 hour fcst::var0_2_1_7_0_6
3:1052558:d=2026032012:RH:2 m above ground:360 hour fcst::var0_2_1_7_1_1
7:3403697:d=2026032012:UGRD:10 m above ground:360 hour fcst::var0_2_1_7_2_2
```

Decoding the `-varX` field `var0_2_1_7_0_0`:
```
var{discipline}_{master_table}_{local_table}_{master_table_num}_{category}_{number}
    0              2             1             7                  0          0
```

- `discipline` = 0 (Meteorological) — from Section 0
- `master_table` = 2 (master table version) — from Section 1
- `local_table` = 1 (local table version) — from Section 1
- `master_table_num` = 7 — from Section 1
- `category` = 0 (Temperature) — from Section 4, Code Table 4.1
- `number` = 0 (Temperature) — from Section 4, Code Table 4.2

The triplet for `grib2-table` lookup is the last three meaningful fields: `(discipline, category, number)` — i.e., `(0, 0, 0)` for TMP.

This is especially useful for identifying unknown parameters where wgrib2 can't resolve a name — the triplet is always present even when name lookup fails.

### Process via Index File (Efficient Random Access)

```bash
# 1. Create index once
wgrib2 file.grib2 -s > file.grib2.idx

# 2. Use grep + pipe to extract specific messages efficiently
grep ':TMP:' file.grib2.idx | wgrib2 file.grib2 -i -grib tmp.grib2

# This is much faster for large files because wgrib2 seeks directly
# to the byte offset rather than scanning sequentially
```

### Pipe wgrib2 to Python (for programmatic reading)

```bash
# Output as raw binary, read in Python with numpy
wgrib2 file.grib2 -match ':TMP:2 m above ground:' -no_header -order we:ns -bin - | python3 read_binary.py
```

In Python:
```python
import numpy as np
# Read raw float32 binary
data = np.frombuffer(sys.stdin.buffer.read(), dtype=np.float32)
data = data.reshape(ny, nx)  # must know grid dimensions
```

---

## Performance Tips

1. **Always create and use index files** for repeated access to large files
2. **Filter before converting**: `-match` then `-netcdf` is much faster than converting everything
3. **Use -grib for subsetting** (preserves original packing, no decode/re-encode)
4. **Use `grep | wgrib2 -i`** pattern for programmatic extraction from index files
5. **Avoid -csv for large grids** — output size explodes (one row per grid point)
6. **cat for merging** is faster than wgrib2 when you want all messages
7. **-d N** processes only message N (1-based) — useful for quick inspection

---

## Common Options Reference

| Option | Description |
|--------|-------------|
| `-s` | Short inventory (compact format, good for .idx files) |
| `-v` | Verbose inventory |
| `-V` | Very verbose inventory |
| `-d N` | Process only message number N |
| `-match REGEX` | Only process messages matching regex on inventory |
| `-not REGEX` | Exclude messages matching regex |
| `-if REGEX` / `-fi` | Conditional block — scope operations to matching messages |
| `-grib FILE` | Output matching messages as GRIB2 |
| `-bin FILE` | Output as raw binary (with Fortran headers) |
| `-no_header` | Suppress Fortran record-length headers in binary output |
| `-ieee FILE` | Output as IEEE float binary |
| `-csv FILE` | Output as CSV |
| `-netcdf FILE` | Convert to NetCDF |
| `-append` | Append to output file instead of overwriting |
| `-i` | Read message numbers or inventory from stdin |
| `-var` | Print parameter name |
| `-varX` | Print discipline/category/number triplet |
| `-lev` | Print level |
| `-ftime` | Print forecast time |
| `-grid` | Print grid definition |
| `-stats` | Print min/max/mean statistics |
| `-npts` | Print number of grid points |
| `-center` | Print originating center |
| `-new_grid` | Regrid to new grid definition |
| `-small_grib` | Extract lat/lon subregion |
| `-set_var` | Change parameter name |
| `-order we:ns` | Set output order (west-east, north-south) |
