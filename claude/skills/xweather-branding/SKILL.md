---
name: xweather-branding
description: Vaisala Xweather brand guidelines for creating web UIs — colors, typography, spacing, logos, and CSS. Use when building or styling Xweather-branded web interfaces.
---

# Xweather Branding Skill

Apply Vaisala Xweather brand identity when creating web UIs. This skill provides quick access to colors, typography, spacing, logos, and design principles for generating CSS and HTML.

## Design Philosophy

- **Calm layouts, minimal palette** — focus on content, not decoration
- **Clarity and precision** — respect the intelligence of the audience
- **Industry-leading quality** — every visual element should reflect this
- Prefer **dark mode / dark base maps** in software UIs
- **Squared-off corners** — do not use rounded corners (border-radius) on cards, containers, or UI elements
- **Flat coloring** — do not use box-shadows, drop-shadows, or embossed/raised effects. Use flat, solid color fills

## Quick Reference: Colors

### Xweather Black (Primary Dark)

PMS Black 6C | RGB 9/21/28 | CMYK 80/35/15/90

| Token | HEX | Usage |
|-------|-----|-------|
| `--xw-black` | `#09151C` | Primary background, darkest |
| `--xw-black-80` | `#0E1F2C` | Secondary dark background |
| `--xw-black-60` | `#263541` | Dark UI elements |
| `--xw-black-40` | `#3E4C56` | Muted dark accents |
| `--xw-black-20` | `#56626B` | Dark text on light bg |

### Misty Gray (Neutral)

RGB 102/130/140 | CMYK 35/0/5/50

| Token | HEX | Usage |
|-------|-----|-------|
| `--xw-gray` | `#66828C` | Base gray, borders |
| `--xw-gray-80` | `#859BA3` | Secondary text |
| `--xw-gray-60` | `#A3B4BA` | Disabled/muted elements |
| `--xw-gray-40` | `#C2CDD1` | Light borders, dividers |
| `--xw-gray-20` | `#F0F3F4` | Light background |

### Misty Green Extra Light (Brand Accent)

PMS 7464 | RGB 166/215/212 | CMYK 35/0/20/0

| Token | HEX | Usage |
|-------|-----|-------|
| `--xw-green` | `#A6D7D4` | Primary accent |
| `--xw-green-80` | `#C1E3E1` | Hover states |
| `--xw-green-60` | `#D3EBEA` | Light accent bg |
| `--xw-green-40` | `#E4F3F2` | Subtle highlight |
| `--xw-green-20` | `#F6FBFB` | Lightest accent bg |

### Dawn Orange (Optional Accent)

PMS 148 C | RGB 247/200/144 | CMYK 2/22/49/0

| Token | HEX | Usage |
|-------|-----|-------|
| `--xw-orange` | `#F7C890` | Warm accent (use sparingly) |
| `--xw-orange-80` | `#F9D9B1` | Warm highlight |
| `--xw-orange-60` | `#FBE4C8` | Light warm bg |
| `--xw-orange-40` | `#FDEFDE` | Subtle warm tint |
| `--xw-orange-20` | `#FEFAF4` | Lightest warm bg |

### Additional Accents

| Name | HEX |
|------|-----|
| Thunder Blue | `#0A2A3D` |
| Ember Orange | `#F86432` |
| Ember Orange Dark | `#E54A05` |

### Color Rules

- Color use is **limited, almost grayscale** — use color only for subtle details
- Structure hierarchy with **shades of gray, font styles, and layout** — not color
- **Never** use large solid Misty Green or Dawn Orange backgrounds
- Prefer grayscale, photo, or gradient backgrounds on large surfaces
- Cool/warm contrast (teal + orange) can pair **two related products** side by side

## Quick Reference: Typography

**Font family:** Vaisala Sans (fallback: system sans-serif)

Other families: Vaisala Sans Condensed, Vaisala Sans Mono

### Type Scale (Golden Ratio)

| Element | Size | Weight | CSS letter-spacing |
|---------|------|--------|--------------------|
| H1 | 144pt | Light (300) | -0.03em |
| H2 | 89pt | Light (300) | -0.03em |
| H3 | 55pt | Light (300) | -0.03em |
| Ingress/quotes | 34pt | Regular (400) | -0.015em |
| Subheader | 21pt | Medium (500) | -0.015em |
| Body text | 21pt | Regular (400) | 0 |

### Typography Rules

- **Reduced letter-spacing** is key — always apply tracking values above
- **Don't use uppercase titles** (exception: small overline headings)
- **Don't bold ingress text or quotes**
- **Don't use body text thinner than Regular**
- Scale sizes proportionally for web (e.g., divide pt values for responsive rem units)

## Quick Reference: Accessible Color Pairings

| Background | Text | Accessibility |
|------------|------|--------------|
| Xweather Black | White | Accessible (all sizes) |
| Misty Gray (base) | White | Accessible (all sizes) |
| Misty Green Extra Light | Dark text | Accessible (all sizes) |
| Misty Gray 60 | White | Large text/icons only |
| Misty Green 80 | Dark text | Large text/icons only |
| Light-on-light, orange combos | — | **Not accessible — avoid** |

## Logo Assets

Logos are in `./logos/`:

- `Vaisala_Xweather_Logo_Black_RGB/` — dark logo (.svg, .png, .ai) — use on light backgrounds
- `Vaisala_Xweather_Logo_White_RGB/` — white logo (.svg, .png, .ai) — use on dark backgrounds

### Logo Rules

- Clear space = optical height (x) of the logo on all sides
- Anchor logo to a **corner** of the layout, or center it
- The **X symbol** (standalone) should never be combined with the full logo
- Squared-off corners on any container holding the logo

## Layout & Imagery Principles

- Clean, minimalistic modern UI + scientific rigor aesthetic
- **Squared-off corners** on all containers, cards, and UI elements — no border-radius
- **Flat coloring** — no shadows, no gradients on UI chrome, no raised/embossed effects
- Gradients are for **imagery and atmospheric backgrounds only** — use organic, non-linear gradients (like sky, shadow, mist)
- Prefer **dark mode** and **dark base maps**
- Photography: cinematic, color-graded, weather-related (dusk, dawn, mist)

## CSS Starter

```css
:root {
  /* Xweather Black */
  --xw-black: #09151C;
  --xw-black-80: #0E1F2C;
  --xw-black-60: #263541;
  --xw-black-40: #3E4C56;
  --xw-black-20: #56626B;

  /* Misty Gray */
  --xw-gray: #66828C;
  --xw-gray-80: #859BA3;
  --xw-gray-60: #A3B4BA;
  --xw-gray-40: #C2CDD1;
  --xw-gray-20: #F0F3F4;

  /* Misty Green Extra Light */
  --xw-green: #A6D7D4;
  --xw-green-80: #C1E3E1;
  --xw-green-60: #D3EBEA;
  --xw-green-40: #E4F3F2;
  --xw-green-20: #F6FBFB;

  /* Dawn Orange (optional accent) */
  --xw-orange: #F7C890;
  --xw-orange-80: #F9D9B1;
  --xw-orange-60: #FBE4C8;
  --xw-orange-40: #FDEFDE;
  --xw-orange-20: #FEFAF4;

  /* Additional accents */
  --xw-thunder-blue: #0A2A3D;
  --xw-ember-orange: #F86432;
  --xw-ember-orange-dark: #E54A05;

  /* Typography */
  --font-family: 'Vaisala Sans', system-ui, -apple-system, sans-serif;
  --font-family-condensed: 'Vaisala Sans Condensed', system-ui, sans-serif;
  --font-family-mono: 'Vaisala Sans Mono', ui-monospace, monospace;

  /* Letter spacing */
  --tracking-headline: -0.03em;
  --tracking-ingress: -0.015em;
  --tracking-body: 0;
}

/* No rounded corners — squared off */
* {
  border-radius: 0;
}

/* No shadows — flat coloring */
* {
  box-shadow: none;
}
```

## Sub-Skills

- [Brand Book Summary](brand-book/brand-book.md) — Complete guidelines from the Xweather brand identity book
- [Example Slides](slides/slides.md) — Patterns extracted from Xweather PowerPoint templates (charts, layouts, dark/light slides)
