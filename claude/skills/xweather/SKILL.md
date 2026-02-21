---
name: xweather
description: Query weather data and generate weather map images using the XWeather API
---

# XWeather API Skill

Query weather data and generate weather map imagery using the XWeather platform.

## Environment Requirements

The following environment variables MUST be set before making any XWeather API requests:

- `XWEATHER_CLIENT_ID` - Your XWeather API client ID
- `XWEATHER_CLIENT_SECRET` - Your XWeather API client secret

Before making any API call, verify these are available:

```bash
echo "Client ID: ${XWEATHER_CLIENT_ID:?XWEATHER_CLIENT_ID is not set}"
echo "Client Secret: ${XWEATHER_CLIENT_SECRET:+[set]}"
```

If either variable is missing, stop and tell the user to set them. Do NOT proceed with requests that will fail due to missing credentials.

## Two Products: When to Use Which

XWeather offers two distinct products. Choose based on what the user needs:

### Weather Data API (JSON responses)

**Base URL:** `https://data.api.xweather.com`

Use the Data API when the user needs **structured weather data** to work with programmatically:

- Current conditions, forecasts, or historical observations for a location
- Severe weather alerts and advisories
- Air quality readings and pollutant data
- Lightning strike data and storm cell tracking
- Earthquake, wildfire, or tropical cyclone information
- Sun/moon rise/set times, tide levels, river gauges
- Road weather conditions
- Maritime weather data
- Comparing weather across multiple locations
- Feeding weather data into scripts, dashboards, or other tools

You MUST NEVER query the API directly. ALWAYS write a python script to query, process and filter data. It returns too
much data to use directly.

### Raster Maps API (image responses)

**Base URL:** `https://raster.api.xweather.com`

Use Raster Maps when the user needs **visual weather imagery** — actual map images:

- Radar imagery overlaid on a map
- Satellite cloud imagery
- Temperature, wind, or precipitation heat maps
- Weather map tiles for embedding in web apps or dashboards
- Animated weather sequences (multiple frames)
- Visual representation of weather patterns over a geographic area

Raster Maps returns **PNG/image tiles**, not JSON. These are rendered map images suitable for display, embedding, or saving to files.

## Sub-Skills

Detailed endpoint documentation and usage patterns are in sub-skill files:

- `data-api.md` - Full Weather Data API reference (endpoints, actions, query parameters)
- `raster-maps.md` - Raster Maps API reference (layers, tile formats, configuration)
