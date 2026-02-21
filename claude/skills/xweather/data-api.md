# XWeather Data API Reference

**Base URL:** `https://data.api.xweather.com`

## Request Format

```
https://data.api.xweather.com/{endpoint}/{action}/{location}?client_id=$XWEATHER_CLIENT_ID&client_secret=$XWEATHER_CLIENT_SECRET&{params}
```

You MUST NEVER query the API directly. ALWAYS write a python script to query, process and filter data. It returns too
much data to use directly.

Data is also available as CSV if you set `format=csv` in the query parameters for responses that are expected to be large.

## Actions

### `:id` — Single Location Lookup

The primary action for getting weather data at one location. Pass a location identifier directly in the URL path or via `p=`.

```
/conditions/minneapolis,mn
/forecasts/98109
/observations/44.96,-93.27
```

Returns a **single object** in `response` (not an array). Use any supported location format (city, zip, coordinates, airport code, etc.).

### `closest` — Nearest Results

Returns results ordered from closest to farthest from the requested location. Without `limit`, returns only the **single closest result**. Useful for finding the nearest weather station, alert, or observation point.

```
/observations/closest?p=44.96,-93.27&limit=5&radius=50miles
```

Increase `radius` if no results are returned (default radius varies by endpoint).

### `within` — Geographic Area Search

Search for all data within a geographic shape. Results are **not ordered** unless you add `sort`.

**Circle** — center point + radius:

```
/alerts/within?p=44.96,-93.27&radius=100miles
```

**Rectangle** — SW corner, NE corner (4 values):

```
/stormreports/within?p=43.23,-96.92,45.62,-91.31
```

**Polygon** — 3+ points defining the boundary:

```
/fires/within?p=36.89,-106.25,43.89,-106.56,44.82,-92.77,41.02,-87.76,35.06,-92.29
```

### `search` — Advanced Query

General-purpose query using the `query` parameter. Results are **unordered**. Use this when you need to filter by specific property values rather than geography.

```
/observations/search?query=state:wa,ob.tempF:80:120
/stormreports/search?query=detail.typeCode:T
```

See the Query Parameters section for full `query` syntax (AND with `,`, OR with `;`, NOT with `!`, starts-with with `^`, range with `min:max`).

### `route` — Multiple Locations or Path

Returns data for each point along a route. This is powerful for two use cases:

1. **Actual routes** — weather along a driving/flight path
2. **Multiple arbitrary locations** — batch weather for a list of places (cheaper than multiple `:id` calls since it's one HTTP request)

**Query string** (semicolon-separated points):

```
/conditions/route?p=44.96,-93.27;41.88,-87.63;40.71,-74.01
```

**POST with JSON body** (for longer lists or per-point options):

```json
POST /forecasts/route
[
  { "p": "minneapolis,mn", "id": "MSP", "from": "+0minutes" },
  { "p": "chicago,il", "id": "ORD", "from": "+4hours" },
  { "p": "new+york,ny", "id": "JFK", "from": "+8hours" }
]
```

The `from` field per point is useful for **route forecasts** — get the forecasted weather at each stop at the estimated arrival time.

**Key parameters:**

- `mindist` — Minimum distance between points (default: 1km). Filters out redundant closely-spaced points.

**Output:** Returns a **GeoJSON FeatureCollection**. Each point is a Feature with coordinates and weather data in `properties`.

**Cost:** Each point counts as a separate API access. A 50-point route = 50 accesses.

### `affects` — Places Impacted by Events

Returns **place objects** for all locations affected by a weather event. The event is identified by its polygon (storm cells, warnings) or radius (earthquakes, fires). Not all endpoints support this action.

```
/stormcells/affects?id=KMPX-SC-123
/earthquakes/affects?p=usgs:abc123
```

### `contains` — What Covers This Location?

Inverse of `within`. Given a location, returns all polygon-based data that **contains** it. Useful for: "what drought zone / convective outlook / alert area am I in?"

```
/convective/outlook/contains?p=minneapolis,mn
/droughts/monitor/contains?p=43.765,-97.128
/alerts/contains?p=44.96,-93.27
```

## Common Query Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `p` | Location: city/state, coordinates, zip, airport code | `p=minneapolis,mn`, `p=45.25,-95.25` |
| `limit` | Number of results (default: 1) | `limit=5` |
| `plimit` | Number of sub-elements (e.g. forecast periods) | `plimit=5` |
| `skip` | Pagination offset | `skip=10` |
| `filter` | Data subset filtering (endpoint-specific) | `filter=day`, `filter=1hr` |
| `fields` | Restrict output fields (dot-notation, comma-separated) | `fields=ob.tempF,ob.weather` |
| `query` | Advanced filtering: `property:operator:value` | `query=state:wa,name:^sea` |
| `from` | Start date/time (relative or absolute) | `from=-4hours`, `from=2024-01-01` |
| `to` | End date/time | `to=now`, `to=+3days` |
| `for` | Conditions at a specific point in time | `for=-2hours` |
| `radius` | Search distance | `radius=50miles` |
| `sort` | Result ordering (`:1` asc, `:-1` desc) | `sort=temp:-1` |
| `format` | Output format | `format=geojson` |

## Location Formats

| Format | Example |
|--------|---------|
| City, State | `seattle,wa` |
| City, Country | `paris,france` |
| Lat, Lon | `37.25,-97.25` |
| US Zip | `98109` |
| Canadian Postal | `M3C 4H9` |
| ICAO Airport | `KMPX` |
| IATA Airport | `MSP` |
| FIPS Code | `fips:53033` |

## Response Format

```json
{
  "success": true,
  "error": null,
  "response": [ ...results... ]
}
```

## Batch Requests

Up to 31 endpoints in a single request:

```
https://data.api.xweather.com/batch/{location}?requests=/{endpoint1},{endpoint2}&client_id=...&client_secret=...
```

---

## Endpoint Documentation

Before using an endpoint, fetch its documentation page from XWeather to get the latest information on
supported actions, parameters, filters, and response fields:

```
https://www.xweather.com/docs/weather-api/endpoints/{slug}
```

### Conditions

| Endpoint | Path | Description | Docs |
|----------|------|-------------|------|
| Conditions | `/conditions` | Interpolated current, forecast, and historical weather for a location | [docs](https://www.xweather.com/docs/weather-api/endpoints/conditions) |
| Conditions Summary | `/conditions/summary` | Aggregated min/max/avg weather summaries over time ranges | [docs](https://www.xweather.com/docs/weather-api/endpoints/conditions-summary) |
| Observations | `/observations` | Raw station observations from METAR, PWS, MADIS networks | [docs](https://www.xweather.com/docs/weather-api/endpoints/observations) |
| Road Weather | `/roadweather` | Road condition forecasts with GREEN/YELLOW/RED index | [docs](https://www.xweather.com/docs/weather-api/endpoints/roadweather) |
| Road Weather Analytics | `/roadweather/analytics` | Full road surface analytics: condition, temperature, hydroplane risk | [docs](https://www.xweather.com/docs/weather-api/endpoints/roadweather-analytics) |
| Road Weather Conditions | `/roadweather/conditions` | Mid-tier road weather: summary index plus surface condition | [docs](https://www.xweather.com/docs/weather-api/endpoints/roadweather-conditions) |
| Impacts | `/impacts/:activity` | Weather impact assessment for activities (general, trucking, maritime) | [docs](https://www.xweather.com/docs/weather-api/endpoints/impacts) |

### Historical

| Endpoint | Path | Description | Docs |
|----------|------|-------------|------|
| Observations Archive | `/observations/archive` | Full-day archived station observations | [docs](https://www.xweather.com/docs/weather-api/endpoints/observations-archive) |
| Observations Summary | `/observations/summary` | Daily observation summaries, up to 30 days historical | [docs](https://www.xweather.com/docs/weather-api/endpoints/observations-summary) |
| Air Quality Archive | `/airquality/archive` | Historical air quality data (Jan 2024+) | [docs](https://www.xweather.com/docs/weather-api/endpoints/airquality-archive) |
| Hail Archive | `/hail/archive` | Historical hail events with size and severity | [docs](https://www.xweather.com/docs/weather-api/endpoints/hail-archive) |
| Maritime Archive | `/maritime/archive` | Historical marine weather: waves, swells, currents, SST | [docs](https://www.xweather.com/docs/weather-api/endpoints/maritime-archive) |
| Tropical Cyclones Archive | `/tropicalcyclones/archive` | Historical tropical cyclone data (1851+) | [docs](https://www.xweather.com/docs/weather-api/endpoints/tropicalcyclones-archive) |
| Renewables Irradiance Archive | `/renewables/irradiance/archive` | Historical solar irradiance (Europe/Africa, 2004+) | [docs](https://www.xweather.com/docs/weather-api/endpoints/renewables-irradiance-archive) |

### Forecasts

| Endpoint | Path | Description | Docs |
|----------|------|-------------|------|
| Forecasts | `/forecasts` | Up to 15-day weather forecasts, daily/hourly/custom intervals | [docs](https://www.xweather.com/docs/weather-api/endpoints/forecasts) |
| Air Quality Forecasts | `/airquality/forecasts` | Up to 4-day AQI and pollutant forecasts globally | [docs](https://www.xweather.com/docs/weather-api/endpoints/airquality-forecasts) |
| Indices | `/indices/:type` | Health/activity indices (migraine, golf, biking, etc.) 0-5 scale | [docs](https://www.xweather.com/docs/weather-api/endpoints/indices) |
| Xcast Forecasts | `/xcast/forecasts` | Hyperlocal forecasts with confidence limits, 10-min to hourly | [docs](https://www.xweather.com/docs/weather-api/endpoints/xcast-forecasts) |

### Severe Weather

| Endpoint | Path | Description | Docs |
|----------|------|-------------|------|
| Alerts | `/alerts` | Government-issued weather alerts (US, Canada, Europe) | [docs](https://www.xweather.com/docs/weather-api/endpoints/alerts) |
| Alerts Summary | `/alerts/summary` | Aggregated alert overview across regions | [docs](https://www.xweather.com/docs/weather-api/endpoints/alerts-summary) |
| Convective Outlook | `/convective/outlook` | SPC severe weather forecasts for the US | [docs](https://www.xweather.com/docs/weather-api/endpoints/convective-outlook) |
| Droughts Monitor | `/droughts/monitor` | USDM drought area designations (US only) | [docs](https://www.xweather.com/docs/weather-api/endpoints/droughts-monitor) |
| Fires | `/fires` | Active wildfire information (North America) | [docs](https://www.xweather.com/docs/weather-api/endpoints/fires) |
| Fires Outlook | `/fires/outlook` | Fire weather condition forecasts | [docs](https://www.xweather.com/docs/weather-api/endpoints/fires-outlook) |
| Hail Threats | `/hail/threats` | Real-time hail risk nowcasts | [docs](https://www.xweather.com/docs/weather-api/endpoints/hail-threats) |
| Storm Cells | `/stormcells` | NEXRAD-tracked storm cells with forecasts | [docs](https://www.xweather.com/docs/weather-api/endpoints/stormcells) |
| Storm Cells Summary | `/stormcells/summary` | Active storm cell overview | [docs](https://www.xweather.com/docs/weather-api/endpoints/stormcells-summary) |
| Storm Reports | `/stormreports` | NWS local storm reports | [docs](https://www.xweather.com/docs/weather-api/endpoints/stormreports) |
| Storm Reports Summary | `/stormreports/summary` | Aggregated storm report data | [docs](https://www.xweather.com/docs/weather-api/endpoints/stormreports-summary) |

### Lightning

| Endpoint | Path | Description | Docs |
|----------|------|-------------|------|
| Lightning | `/lightning` | Real-time individual lightning strike/pulse data | [docs](https://www.xweather.com/docs/weather-api/endpoints/lightning) |
| Lightning Analytics | `/lightning/analytics` | Extended lightning data with damage assessment metrics | [docs](https://www.xweather.com/docs/weather-api/endpoints/lightning-analytics) |
| Lightning Flash | `/lightning/flash` | Consolidated flash records (grouped CG/CC strikes) | [docs](https://www.xweather.com/docs/weather-api/endpoints/lightning-flash) |
| Lightning Summary | `/lightning/summary` | Aggregate lightning statistics: counts, type, peak amplitude | [docs](https://www.xweather.com/docs/weather-api/endpoints/lightning-summary) |
| Lightning Threats | `/lightning/threats` | Lightning nowcasts with up to 60-min forecast | [docs](https://www.xweather.com/docs/weather-api/endpoints/lightning-threats) |

### Air Quality

| Endpoint | Path | Description | Docs |
|----------|------|-------------|------|
| Air Quality | `/airquality` | Current AQI, health index, and pollutant data globally | [docs](https://www.xweather.com/docs/weather-api/endpoints/airquality) |
| Air Quality Archive | `/airquality/archive` | Historical air quality data (Jan 2024+) | [docs](https://www.xweather.com/docs/weather-api/endpoints/airquality-archive) |
| Air Quality Forecasts | `/airquality/forecasts` | Up to 4-day AQI and pollutant forecasts | [docs](https://www.xweather.com/docs/weather-api/endpoints/airquality-forecasts) |
| Air Quality Index | `/airquality/index` | Simplified headline AQI value and category | [docs](https://www.xweather.com/docs/weather-api/endpoints/airquality-index) |

### Maritime

| Endpoint | Path | Description | Docs |
|----------|------|-------------|------|
| Maritime | `/maritime` | Global marine weather: waves, swells, currents, SST | [docs](https://www.xweather.com/docs/weather-api/endpoints/maritime) |
| Maritime Archive | `/maritime/archive` | Historical marine weather data | [docs](https://www.xweather.com/docs/weather-api/endpoints/maritime-archive) |
| Tides | `/tides` | Current and forecast tide levels (US coasts) | [docs](https://www.xweather.com/docs/weather-api/endpoints/tides) |
| Tides Stations | `/tides/stations` | Tide station metadata and locations | [docs](https://www.xweather.com/docs/weather-api/endpoints/tides-stations) |

### Climate

| Endpoint | Path | Description | Docs |
|----------|------|-------------|------|
| Normals | `/normals` | 30-year climate normals (US locations) | [docs](https://www.xweather.com/docs/weather-api/endpoints/normals) |
| Normals Stations | `/normals/stations` | Station data for climate normals | [docs](https://www.xweather.com/docs/weather-api/endpoints/normals-stations) |

### Geographical

| Endpoint | Path | Description | Docs |
|----------|------|-------------|------|
| Countries | `/countries` | Country data: name, ISO codes, capital, population | [docs](https://www.xweather.com/docs/weather-api/endpoints/countries) |
| Earthquakes | `/earthquakes` | Global earthquake data: magnitude, depth, type | [docs](https://www.xweather.com/docs/weather-api/endpoints/earthquakes) |
| Places | `/places` | Geographic location data for cities, stations, airports | [docs](https://www.xweather.com/docs/weather-api/endpoints/places) |
| Places Airports | `/places/airports` | Airport/heliport data with IATA/ICAO codes | [docs](https://www.xweather.com/docs/weather-api/endpoints/places-airports) |
| Places Postal Codes | `/places/postalcodes` | US ZIP and Canadian postal code data | [docs](https://www.xweather.com/docs/weather-api/endpoints/places-postalcodes) |
| Rivers | `/rivers` | US river/lake gauge readings from NOAA | [docs](https://www.xweather.com/docs/weather-api/endpoints/rivers) |
| Rivers Gauges | `/rivers/gauges` | Enhanced gauge data with flood impacts and crests | [docs](https://www.xweather.com/docs/weather-api/endpoints/rivers-gauges) |
| Sun/Moon | `/sunmoon` | Sunrise/sunset, moonrise/set, and moon phase data | [docs](https://www.xweather.com/docs/weather-api/endpoints/sunmoon) |
| Moon Phases | `/sunmoon/moonphases` | Moon phase calendar with filtering | [docs](https://www.xweather.com/docs/weather-api/endpoints/sunmoon-moonphases) |
| Tropical Cyclones | `/tropicalcyclones` | Active tropical cyclone tracking and forecasts | [docs](https://www.xweather.com/docs/weather-api/endpoints/tropicalcyclones) |
| Tropical Cyclones Archive | `/tropicalcyclones/archive` | Historical tropical cyclone data (1851+) | [docs](https://www.xweather.com/docs/weather-api/endpoints/tropicalcyclones-archive) |
