---
name: directions
description: Get driving, walking, and cycling directions between locations using the Mapbox Directions API. Use when the user asks for directions, routes, travel time, or distance between places.
---

# Mapbox Directions Skill

Get turn-by-turn directions, travel times, and distances between locations using the Mapbox Directions API.

## Environment Requirements

The following environment variable MUST be set before making any Mapbox API requests:

- `MAPBOX_ACCESS_TOKEN` - Your Mapbox API access token

Before making any API call, verify it is available:

```bash
echo "Mapbox Token: ${MAPBOX_ACCESS_TOKEN:?MAPBOX_ACCESS_TOKEN is not set}"
```

If the variable is missing, stop and tell the user to set it. Do NOT proceed with requests that will fail due to missing credentials.

## When to Use

- User asks for directions between two or more places
- User asks how far / how long between locations
- User wants to compare driving vs walking vs cycling routes
- User asks for turn-by-turn navigation steps

## Sub-Skills

Detailed API reference:

- [Directions API Reference](directions-api.md) - Endpoint format, parameters, and response handling
