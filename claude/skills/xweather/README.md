# Xweather Skill

A Claude Code skill for querying the [Xweather](https://www.xweather.com/) platform — both the **Data API** (structured JSON weather data) and the **Raster Maps API** (rendered map imagery).

## What It Does

When invoked (via `/xweather`), this skill gives Claude the knowledge to:

- **Query weather data** — current conditions, forecasts, historical observations, severe weather alerts, air quality, lightning, maritime conditions, tropical cyclones, and more via 50+ Data API endpoints.
- **Generate weather map images** — radar, satellite, temperature, precipitation, and other layers composited into static PNGs or XYZ tile URLs for interactive maps.
- **Write processing scripts** — since the Data API returns large JSON payloads, the skill always writes temporary Python scripts to query, filter, and process the data before returning results. This keeps responses focused on the information you actually need.

## Two Products

| Product | Base URL | Returns | Use When |
|---------|----------|---------|----------|
| **Data API** | `data.api.xweather.com` | JSON | You need structured data — temperatures, alerts, forecasts, AQI, etc. |
| **Raster Maps** | `maps.api.xweather.com` | PNG images | You need visual maps — radar overlays, satellite imagery, heat maps |

## Requirements

Two environment variables must be set:

- `XWEATHER_CLIENT_ID` — your Xweather API client ID
- `XWEATHER_CLIENT_SECRET` — your Xweather API client secret

The skill checks for these before making any requests and will stop with a clear message if they're missing.

## Example Uses

- "What's the weather in Seattle right now?"
- "Show me a radar map of the midwest"
- "Are there any active severe weather alerts in Texas?"
- "Get the 5-day forecast for Minneapolis"
- "Show air quality levels across California"
- "What's the lightning activity near Tampa?"
- "Generate a satellite image of Hurricane X"
- "Compare current temperatures across 10 US cities"

## Skill Files

| File | Purpose |
|------|---------|
| [SKILL.md](SKILL.md) | Main skill definition — environment setup, product selection guidance, and sub-skill pointers |
| [data-api.md](data-api.md) | Full Data API reference — endpoints, actions (`:id`, `closest`, `within`, `search`, `route`), query parameters, location formats, and all 50+ endpoint docs links |
| [raster-maps.md](raster-maps.md) | Raster Maps API reference — static map and tile URL formats, 80+ layer codes, layer modifiers (opacity, blur, blending), time offsets, and animation |
