# Mapbox Directions API Reference

**Base URL:** `https://api.mapbox.com/directions/v5`

## Request Format

```
GET https://api.mapbox.com/directions/v5/{profile}/{coordinates}?access_token=$MAPBOX_ACCESS_TOKEN&{params}
```

Use `curl` to query the API directly. Pipe through `jq` to extract relevant fields from the response.

## Profiles

| Profile | Use Case |
|---------|----------|
| `mapbox/driving-traffic` | Driving with live/historic traffic data |
| `mapbox/driving` | Driving, fastest route without traffic |
| `mapbox/walking` | Pedestrian and hiking |
| `mapbox/cycling` | Bicycle-optimized |

Default to `mapbox/driving` unless the user specifies otherwise.

## Coordinates

Semicolon-separated `{longitude},{latitude}` pairs. **Longitude first, latitude second.** Minimum 2, maximum 25.

```
-122.42,37.78;-77.03,38.91
```

If the user provides an address or place name, use the Mapbox Geocoding API to resolve it first:

```bash
curl -s "https://api.mapbox.com/search/geocode/v6/forward?q=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$ADDRESS'))")&access_token=$MAPBOX_ACCESS_TOKEN" | jq -r '.features[0].geometry.coordinates | "\(.[0]),\(.[1])"'
```

## Key Query Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `alternatives` | boolean | `false` | Return alternative routes |
| `steps` | boolean | `false` | Include turn-by-turn instructions |
| `geometries` | string | `polyline` | Response geometry format: `geojson`, `polyline`, `polyline6` |
| `overview` | string | `simplified` | Route geometry detail: `full`, `simplified`, `false` |
| `annotations` | string | — | Comma-separated: `distance`, `duration`, `speed`, `congestion`, `maxspeed` |
| `language` | string | `en` | Language for turn instructions |
| `exclude` | string | — | Comma-separated: `motorway`, `toll`, `ferry`, `unpaved` |
| `depart_at` | string | — | ISO 8601 departure time (traffic profiles) |
| `arrive_by` | string | — | ISO 8601 arrival time (traffic profiles) |

## Common Usage Patterns

### Basic directions with duration and distance

```bash
curl -s "https://api.mapbox.com/directions/v5/mapbox/driving/-122.42,37.78;-77.03,38.91?overview=false&access_token=$MAPBOX_ACCESS_TOKEN" \
  | jq '{distance_miles: (.routes[0].distance / 1609.34 | round), duration_hours: (.routes[0].duration / 3600 * 10 | round / 10)}'
```

### Turn-by-turn directions

```bash
curl -s "https://api.mapbox.com/directions/v5/mapbox/driving/-122.42,37.78;-77.03,38.91?steps=true&geometries=geojson&overview=full&access_token=$MAPBOX_ACCESS_TOKEN" \
  | jq '.routes[0].legs[0].steps[] | {instruction: .maneuver.instruction, distance_miles: (.distance / 1609.34 * 10 | round / 10), duration_min: (.duration / 60 | round)}'
```

### Compare alternatives

```bash
curl -s "https://api.mapbox.com/directions/v5/mapbox/driving/-122.42,37.78;-77.03,38.91?alternatives=true&overview=false&access_token=$MAPBOX_ACCESS_TOKEN" \
  | jq '.routes[] | {distance_miles: (.distance / 1609.34 | round), duration_hours: (.duration / 3600 * 10 | round / 10)}'
```

### With traffic

```bash
curl -s "https://api.mapbox.com/directions/v5/mapbox/driving-traffic/-122.42,37.78;-77.03,38.91?overview=false&annotations=congestion,duration&access_token=$MAPBOX_ACCESS_TOKEN" \
  | jq '{distance_miles: (.routes[0].distance / 1609.34 | round), duration_hours: (.routes[0].duration / 3600 * 10 | round / 10)}'
```

## Response Structure

The API returns JSON with:

- `code` — `"Ok"` on success
- `routes[]` — Array of route objects, each containing:
  - `distance` — Total distance in **meters**
  - `duration` — Total duration in **seconds**
  - `geometry` — Route line (format depends on `geometries` param)
  - `legs[]` — One per pair of waypoints, each containing:
    - `steps[]` — Turn-by-turn instructions (when `steps=true`), each with:
      - `maneuver.instruction` — Human-readable instruction
      - `maneuver.type` — e.g. `turn`, `merge`, `arrive`
      - `distance` — Step distance in meters
      - `duration` — Step duration in seconds
- `waypoints[]` — Snapped input coordinates

## Unit Conversions

The API returns metric units. Convert for display:

- **Meters to miles:** `meters / 1609.34`
- **Meters to km:** `meters / 1000`
- **Seconds to minutes:** `seconds / 60`
- **Seconds to hours:** `seconds / 3600`

## Error Handling

- `InvalidInput` — Bad coordinates or parameters
- `NoRoute` — No route found between points
- `NoSegment` — A coordinate couldn't snap to the road network
- `ProfileNotFound` — Invalid profile name

On error, check `code` and `message` in the response.
