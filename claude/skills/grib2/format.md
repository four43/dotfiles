# GRIB2 File Format Structure

## Overview

GRIB2 (GRIdded Binary Edition 2) is a WMO standard for encoding gridded meteorological data. A GRIB2 file is simply a concatenation of one or more **messages** — there is no file-level header or index. Each message is self-contained and independently decodable.

## Message Structure

Every GRIB2 message consists of sections 0 through 8, in order. Some sections can repeat to encode multiple grids efficiently within a single message (though this is uncommon in practice — most files use one grid per message).

```
Section 0: Indicator          (16 bytes, always)
Section 1: Identification     (variable length)
Section 2: Local Use          (optional, variable length)
Section 3: Grid Definition    (variable length)
Section 4: Product Definition (variable length)  ← parameter identity lives here
Section 5: Data Representation(variable length)
Section 6: Bitmap             (variable length, optional)
Section 7: Data               (variable length)  ← actual grid values
Section 8: End                (4 bytes, always "7777")
```

Sections 2-7 can repeat within a single message (allowing multiple fields to share Section 1 and Section 3), but this is rare in operational data. Most tools treat each field as a separate logical message.

### Section 0: Indicator

- Magic bytes: `GRIB` (ASCII)
- Reserved (2 bytes)
- Discipline (1 byte) — Code Table 0.0: `0` = Meteorological, `2` = Land surface, `10` = Oceanographic
- Edition number: `2`
- Total message length (8 bytes)

The **discipline** here is the first component of the parameter triplet.

### Section 1: Identification

- Originating center and sub-center (Code Tables 0 and C)
- Master table version number — determines which Code Table 4.2 entries are available
- Local table version number
- Reference time (year, month, day, hour, minute, second) — the model initialization time
- Production status and type of data

Key insight: The **master table version** matters. A parameter added in master table v33 won't be recognized by software built against v28. The triplet is still valid — only name resolution fails.

### Section 2: Local Use (Optional)

Arbitrary data defined by the originating center. No standard format. Most operational files either omit this or use it minimally.

### Section 3: Grid Definition

Defines the grid geometry:

- Grid Definition Template Number (Code Table 3.1):
  - `0` = Latitude/longitude (equidistant cylindrical)
  - `30` = Lambert conformal
  - `40` = Gaussian latitude/longitude
  - `20` = Polar stereographic
- Number of grid points
- Grid dimensions (Ni × Nj)
- First/last grid point coordinates
- Grid increments (Di, Dj)
- Scanning mode (Code Table 3.4) — determines how grid points are ordered in the data array

**Scanning mode** is critical for correctly interpreting the data array. Common modes:
- `0x00` (0): +i direction, -j direction, consecutive i points (west→east rows, north→south)
- `0x40` (64): +i direction, +j direction (south→north)

### Section 4: Product Definition

This is where parameter identity lives.

- Product Definition Template Number (Code Table 4.0):
  - `0` = Analysis or forecast at a point in time
  - `1` = Individual ensemble forecast
  - `2` = Derived forecast (ensemble mean, etc.)
  - `8` = Average, accumulation, or extreme over a time interval
  - `9` = Probability forecast
  - `10` = Percentile forecast
  - `11` = Individual ensemble forecast over time interval
  - `12` = Derived forecast over time interval

- **Parameter Category** (Code Table 4.1) — second component of triplet
- **Parameter Number** (Code Table 4.2) — third component of triplet
- Type of generating process (analysis, forecast, etc.)
- Forecast time and units
- Type of first/second fixed surface (Code Table 4.5) — defines the level
- Scaled value of first/second fixed surface — the level value
- For templates 8+: statistical processing type (Code Table 4.10) — instant, accum, avg, max, min

**The parameter triplet** `(discipline, parameterCategory, parameterNumber)` uniquely identifies the physical quantity within a master table version. Discipline comes from Section 0, category and number from Section 4.

**Fixed surfaces** (Code Table 4.5) define the vertical level:
- `1` = Ground/water surface
- `100` = Isobaric surface (pressure level in Pa)
- `101` = Mean sea level
- `102` = Specific altitude above mean sea level
- `103` = Specific height above ground (m)
- `104` = Sigma level
- `105` = Hybrid level
- `106` = Depth below land surface (m)
- `108` = Level at specified pressure difference from ground
- `200` = Entire atmosphere (considered as a single layer)

### Section 5: Data Representation

Defines how grid values are packed into binary:

- Data Representation Template Number (Code Table 5.0):
  - `0` = Simple packing
  - `2` = Complex packing with spatial differencing (common for weather data)
  - `3` = Complex packing with spatial differencing
  - `40` = JPEG 2000 compression
  - `41` = PNG compression
  - `200` = Run-length packing (for categorical data like land/sea masks)

- Reference value (R), binary scale factor (E), decimal scale factor (D), number of bits per packed value
- Formula: `Y = R + (X × 2^E) / 10^D` where X is the packed integer

### Section 6: Bitmap

Optional. If present, indicates which grid points have data and which are missing.

- Bitmap indicator:
  - `0` = Bitmap follows (bit array: 1 = data present, 0 = missing)
  - `255` = No bitmap, all grid points have data
  - `254` = Use previously defined bitmap

### Section 7: Data

The actual packed grid values. Interpretation depends entirely on Section 5 (packing method) and Section 6 (bitmap). This section is opaque binary — you need a decoder.

### Section 8: End

Always exactly 4 bytes: `7777` (ASCII). Marks the end of the message.

## Multi-Field Messages

The GRIB2 spec allows sections 2-7 to repeat within a single message, sharing Sections 0 and 1. This means a single message can contain multiple fields with different parameters, levels, or times — but sharing the same identification metadata and potentially grid definition.

In practice:
- Most operational producers write one field per message
- Some producers (especially for ensemble data) pack multiple fields per message
- wgrib2 and ecCodes handle both cases transparently, presenting each field as a separate logical record

## File-Level Considerations

- **No file header**: A GRIB2 file is literally messages concatenated. You find messages by scanning for `GRIB` magic bytes.
- **No built-in index**: Sequential scanning is required without an external index. This is why wgrib2 index files (`.idx`) are essential for efficient access.
- **Mixed content**: A single file can contain messages with different grids, parameters, times, and even disciplines. This is common in model output files (e.g., a GFS file contains hundreds of different variables across many levels and time steps).
- **Byte alignment**: Messages are not padded to any alignment boundary. Each starts immediately after the previous message's `7777` end marker.
