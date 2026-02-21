# XWeather Raster Maps API Reference

**Base URL:** `https://maps.api.xweather.com`

Authentication is embedded in the URL path as `{client_id}_{client_secret}`.

Almost all requests will redirect to a time with actual data. YOU MUST follow redirects when requesting images.

When creating a file and downloading the data, ALWAYS show the user the final file path.

## Static Map URL Format

Generate a single map image with one request. Use in `<img>` tags or download directly.

### Center Point Method

```
https://maps.api.xweather.com/{client_id}_{client_secret}/{layers}/{width}x{height}/{location},{zoom}/{offset}.{format}
```

**Parameters:**

| Component | Description | Example |
|-----------|-------------|---------|
| `{client_id}_{client_secret}` | Credentials joined with underscore | `abc123_xyz789` |
| `{layers}` | Comma-separated layer codes (max 10) | `flat,radar,admin` |
| `{width}x{height}` | Image dimensions in pixels | `800x600` |
| `{location}` | Center point (see location formats below) | `44.96,-93.27` or `seattle,wa` |
| `{zoom}` | Zoom level, 2-19 (default 6) | `7` |
| `{offset}` | Time offset (see Time Offsets section) | `current` |
| `{format}` | Image format: `png` or `jpg` | `png` |

**Location formats:** lat/lon (`44.96,-93.27`), city/state (`seattle,wa`), zip (`98109`), or any supported place format.

**Example:**

```
https://maps.api.xweather.com/${XWEATHER_CLIENT_ID}_${XWEATHER_CLIENT_SECRET}/flat,radar,admin/800x600/seattle,wa,7/current.png
```

### Bounding Box Method

Define a geographic region instead of center+zoom:

```
https://maps.api.xweather.com/{client_id}_{client_secret}/{layers}/{width}x{height}/{south},{west},{north},{east}/{offset}.{format}
```

| Component | Description | Example |
|-----------|-------------|---------|
| `{south}` | Southern latitude | `30.10` |
| `{west}` | Western longitude | `-85.96` |
| `{north}` | Northern latitude | `33.09` |
| `{east}` | Eastern longitude | `-82.44` |

The system automatically determines center and zoom to fit the specified region.

**Example:**

```
https://maps.api.xweather.com/${XWEATHER_CLIENT_ID}_${XWEATHER_CLIENT_SECRET}/flat,radar,admin/800x600/30.10,-85.96,33.09,-82.44/current.png
```

### Size Limits

- Free developer trial: up to 2000x2000
- Paid subscriptions: up to 5000x5000

## Tile Server URL Format (XYZ Tiles)

For interactive maps (Leaflet, Mapbox, Google Maps, etc.):

```
https://maps.api.xweather.com/{client_id}_{client_secret}/{layers}/{z}/{x}/{y}/{offset}.{format}
```

| Component | Description |
|-----------|-------------|
| `{z}` | Zoom level (1-21) |
| `{x}` | Tile X coordinate |
| `{y}` | Tile Y coordinate |

### Server Redundancy

Use `maps1` through `maps4` subdomains to distribute load:

```
https://maps{1-4}.api.xweather.com/{client_id}_{client_secret}/{layers}/{z}/{x}/{y}/{offset}.{format}
```

### Leaflet Example

```javascript
L.tileLayer(
  'https://maps{s}.api.xweather.com/' +
  XWEATHER_CLIENT_ID + '_' + XWEATHER_CLIENT_SECRET +
  '/radar/{z}/{x}/{y}/current.png',
  {
    subdomains: '1234',
    attribution: '&copy; Xweather'
  }
).addTo(map);
```

### Multiple Layers in Tiles

Combine layers to reduce requests (especially useful on mobile):

```
https://maps.api.xweather.com/{id}_{secret}/flat,radar,admin/{z}/{x}/{y}/current.png
```

## Layer Specification

### Combining Layers

Comma-separate layer codes. Layers are composited left-to-right (first layer on bottom, last on top):

```
flat,radar,admin          -- base map + radar + borders/labels
terrain,alerts,radar,cities  -- terrain base + alerts + radar + city labels
```

**Maximum:** 10 layers per request.

### Common Layer Combinations

| Use Case | Layers |
|----------|--------|
| Basic radar map | `flat,radar,admin` |
| Radar on dark base | `flat-dk,radar,admin-dk` |
| Satellite with borders | `satellite-geocolor,admin` |
| Temperature map | `flat,temperatures,admin` |
| Severe weather | `flat,alerts,stormcells,admin` |
| Forecast temps | `flat,ftemperatures,admin` |

## Layer Modifiers

Modifiers are appended to individual layer names with `:` separators. Multiple modifiers can be chained in any order.

**General syntax:** `layername:modifier1:modifier2:...`

### Opacity

**Syntax:** `layername:{value}` where value is 0-100 (default: 100)

- `radar:70` -- radar at 70% opacity
- `alerts:80` -- alerts at 80% opacity

### Blur

**Syntax:** `layername:blur({amount})` where amount is a positive integer (0 = no blur)

- `radar:blur(2)` -- moderate blur
- `satellite:blur(4)` -- heavy blur

### Grayscale

**Syntax:** `layername:gray()`

- `temperatures:gray()` -- grayscale temperature layer

### Invert

**Syntax:** `layername:invert()`

- `lightning-strikes:invert()` -- inverted colors

### Blending

**Syntax:** `layername:blend({mode})`

Only one blend mode per layer. Blending occurs between the source layer and all layers below it.

**Composite blend modes** (color-based):

| Mode | Effect |
|------|--------|
| `plus` | Adds source to destination, brightening |
| `minus` | Subtracts source from destination |
| `difference` | Subtracts darker from lighter |
| `exclusion` | Like difference, lower contrast |
| `multiply` | Darker results, highlights source |
| `contrast` | Adjusts contrast between layers |
| `screen` | Multiplies inverses, lighter result |
| `overlay` | Combines with destination brightness |
| `grain-merge` | Shows texture |
| `grain-extract` | Extracts texture information |
| `darken` | Selects darker value per channel |
| `lighten` | Selects lighter value per channel |
| `hue` | Source hue, destination luminance/saturation |
| `saturation` | Source saturation, destination luminance/hue |
| `invert` | Inverts color values |
| `color-dodge` | Brightens by decreasing contrast |
| `color-burn` | Darkens by increasing contrast |
| `hard-light` | Harsh spotlight effect |
| `soft-light` | Diffused spotlight effect |

**Alpha blend modes** (masking):

| Mode | Effect |
|------|--------|
| `src` | Source only |
| `dst` | Destination only |
| `src-over` | Source on top (default) |
| `dst-over` | Destination on top |
| `src-in` | Source where intersecting destination |
| `dst-in` | Destination where intersecting source |
| `src-out` | Source where NOT intersecting destination |
| `dst-out` | Destination where NOT intersecting source |
| `src-atop` | Source intersections over destination |
| `dst-atop` | Destination intersections over source |

### Scale HSLA

**Syntax:** `layername:scale-hsla({h0},{h1},{s0},{s1},{l0},{l1},{a0},{a1})`

All 8 parameters are floats from 0 to 1. Formula: `output = param0 + (original * (param1 - param0))`

To convert standard HSL values:
- Hue (0-360): divide by 360
- Saturation (0-100%): divide by 100
- Lightness (0-100%): divide by 100

Example: `lightning-strikes:scale-hsla(0,0,1,0,0.5,0,0,1)`

### Chaining Multiple Modifiers

Order is arbitrary when combining modifiers:

```
temperatures:70:blur(2):blend(grain-merge)
radar:80:blur(1)
lightning-strikes:invert():50
flat-dk:gray()
```

## Time Offsets

The `{offset}` component in the URL controls which point in time to render.

### Keywords

| Value | Description |
|-------|-------------|
| `current` | Most recent available data |
| `latest` | Same as `current` |

### Relative Offsets

Negative values for past, positive for future. Integer values only (no decimals).

**Units:** `s`/`second`/`seconds`, `m`/`min`/`minute`/`minutes`, `h`/`hr`/`hour`/`hours`, `d`/`day`/`days`

| Offset | Meaning |
|--------|---------|
| `-30minutes` | 30 minutes ago |
| `-2hours` | 2 hours ago |
| `-1day` | 1 day ago |
| `+1hour` | 1 hour forecast |
| `+6hours` | 6 hour forecast |
| `-90minutes` | 1.5 hours ago (use this, NOT `-1.5hours`) |

### Absolute UTC Time

Format: `YYYYMMDDhhiiss`

- `20240601174100` = June 1, 2024 at 17:41:00 UTC

The API returns the closest available data to the requested time.

### Animation Frames

To build animations, request multiple images with sequential time offsets. For example, loop through past radar frames:

```
/radar/.../-60minutes.png
/radar/.../-50minutes.png
/radar/.../-40minutes.png
/radar/.../-30minutes.png
/radar/.../-20minutes.png
/radar/.../-10minutes.png
/radar/.../current.png
```

For forecast animation, use positive offsets:

```
/fradar/.../current.png
/fradar/.../+1hour.png
/fradar/.../+2hours.png
/fradar/.../+3hours.png
```

## Available Layers

### Radar and Satellite

| Layer Code | Description |
|------------|-------------|
| `radar` | Radar imagery (regional) |
| `radar-global` | Global radar + satellite-derived radar |
| `satellite` | B/W infrared satellite |
| `satellite-geocolor` | Geocolor satellite (global) |
| `satellite-infrared-color` | Color IR satellite (cloud top temp) |
| `satellite-visible` | Visible satellite |
| `satellite-water-vapor` | Water vapor imagery |

### Observations (Current Conditions)

| Layer Code | Description |
|------------|-------------|
| `temperatures` | Surface temperature |
| `dew-points` | Dew point temperature |
| `feels-like` | Apparent temperature |
| `humidity` | Relative humidity |
| `wind-speeds` | Wind speed |
| `wind-gusts` | Wind gusts |
| `wind-dir` | Wind direction arrows |
| `wind-chill` | Wind chill (temps <= 40F) |
| `heat-index` | Heat index (temps >= 80F) |
| `visibility` | Visibility distance |
| `snow-depth` | Estimated snow depth |

### Forecasts

Forecast layers are prefixed with `f`:

| Layer Code | Description |
|------------|-------------|
| `ftemperatures` | Temperature forecast |
| `ftemperatures-max` | High temp forecast |
| `ftemperatures-min` | Low temp forecast |
| `fdew-points` | Dew point forecast |
| `ffeels-like` | Feels-like forecast |
| `fhumidity` | Humidity forecast |
| `fwind-speeds` | Wind speed forecast |
| `fwind-gusts` | Wind gust forecast |
| `fwind-chill` | Wind chill forecast |
| `fheat-index` | Heat index forecast |
| `fqpf-1h` | 1hr precip accumulation |
| `fqpf-6h` | 6hr precip accumulation |
| `fqpf-accum` | Accumulated precip |
| `fqsf-1h` | 1hr snow accumulation |
| `fqsf-accum` | Snow accumulation |
| `fsnow-depth` | Snow depth forecast |
| `fice-accum` | Ice accumulation forecast |
| `fvisibility` | Visibility forecast |
| `fpressure-msl` | Mean sea level pressure |
| `fpressure-msl-isobars` | Pressure with isobars |
| `fjet-stream` | Jet stream at 250mb |
| `fradar` | Model-based radar forecast |
| `fsatellite` | Model-based satellite forecast |
| `fsurface-analysis` | Frontal + pressure analysis |
| `fsurface-analysis-fronts` | Fronts only |
| `fsurface-analysis-pressure` | Pressure only |

### Severe Weather

| Layer Code | Description |
|------------|-------------|
| `alerts` | Active weather alerts (US, Canada, Europe) |
| `stormcells` | Radar-derived storm cells |
| `stormreports` | NWS 24hr storm reports |
| `convective` | SPC convective outlook |

### Lightning

| Layer Code | Description |
|------------|-------------|
| `lightning-flash` | CG + intracloud lightning (5 min) |
| `lightning-strikes` | CG strikes (5-15 min) |
| `lightning-all` | Combined CG + intracloud (5-15 min) |
| `lightning-strike-density` | Lightning frequency heat map |

### Air Quality

| Layer Code | Description |
|------------|-------------|
| `air-quality-index` | AQI measurements |
| `air-quality-index-categories` | AQI category colors |
| `air-quality-health-index-categories` | Health impact categories |
| `air-quality-co` | Carbon monoxide |
| `air-quality-no2` | Nitrogen dioxide |
| `air-quality-o3` | Ozone |
| `air-quality-pm10` | Particulate matter < 10um |
| `air-quality-pm2p5` | Particulate matter < 2.5um |
| `air-quality-so2` | Sulfur dioxide |

### Maritime

| Layer Code | Description |
|------------|-------------|
| `maritime-sst` | Sea surface temperature |
| `maritime-currents` | Ocean currents |
| `maritime-surges` | Storm surge height |
| `maritime-wave-heights` | Wave heights |
| `maritime-wave-periods` | Wave periods |
| `maritime-wind-wave-heights` | Wind wave heights |
| `maritime-swell-heights` | Primary swell heights |
| `maritime-swell-periods` | Primary swell periods |

### Tropical Cyclones

| Layer Code | Description |
|------------|-------------|
| `tropical-cyclones` | Active cyclones with 5-day forecast |
| `tropical-cyclones-forecast-error-cones` | Probable track cones |
| `tropical-cyclones-forecast-lines` | Forecast track lines |
| `tropical-cyclones-positions` | Current positions |
| `tropical-cyclones-track-lines` | Historical track lines |

### Precipitation and Climate

| Layer Code | Description |
|------------|-------------|
| `precip` | Accumulated precipitation |
| `precip-normals` | Precipitation normals |
| `precip-depart` | Departure from normal |
| `precip-depart-percent` | % departure from normal |
| `drought-monitor` | Drought severity |

### Fires

| Layer Code | Description |
|------------|-------------|
| `fires-obs-points` | Active fire observations |
| `fires-obs-icons` | Fire position icons |
| `fires-outlook` | Fire weather outlook |

### Base Maps

| Layer Code | Description |
|------------|-------------|
| `flat` | Light flat base |
| `flat-dk` | Dark flat base |
| `terrain` | Terrain base |
| `terrain-dk` | Dark terrain base |
| `blue-marble` | Blue marble satellite base |

### Overlays and Borders

| Layer Code | Description |
|------------|-------------|
| `admin` | Borders, states, cities labels |
| `admin-dk` | Dark variant |
| `admin-cities` | City name emphasis |
| `admin-cities-dk` | Dark city names |
| `states` | State/province outlines |
| `counties` | US county outlines |
| `countries-outlines` | Country outlines |
| `interstates` | Major highways |
| `roads` | Major roads (US) |
| `rivers` | River lines |

### Text Overlays (Numeric Values)

| Layer Code | Description |
|------------|-------------|
| `temperatures-text` | Temperature values |
| `dew-points-text` | Dew point values |
| `wind-speeds-text` | Wind speed values |
| `humidity-text` | Humidity values |

### Masks

| Layer Code | Description |
|------------|-------------|
| `land-flat` | Land mask (flat) |
| `land-terrain` | Land mask (terrain) |
| `water-flat` | Water mask |
| `water-depth` | Bathymetry water mask |
| `clip-us-flat` | Flat with transparent US cutout |
| `clip-us-terrain` | Terrain with transparent US cutout |

## Quick Reference

### Minimal static map (radar over Seattle):

```bash
curl -o weather.png "https://maps.api.xweather.com/${XWEATHER_CLIENT_ID}_${XWEATHER_CLIENT_SECRET}/flat,radar,admin/800x600/seattle,wa,7/current.png"
```

### Tile URL template for Leaflet:

```
https://maps.api.xweather.com/{id}_{secret}/{layers}/{z}/{x}/{y}/current.png
```

### Layer with modifiers:

```
radar:70:blur(1)           -- 70% opacity, slight blur
temperatures:gray():50     -- grayscale at 50% opacity
alerts:blend(overlay):80   -- overlay blend at 80% opacity
```
