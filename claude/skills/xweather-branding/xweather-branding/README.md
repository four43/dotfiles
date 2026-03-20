# Xweather Branding Skill

A Claude Code skill that provides Vaisala Xweather brand guidelines for building web UIs. Gives quick access to colors, typography, spacing, logos, and CSS so you can generate on-brand interfaces without hunting through brand books.

## What It Does

When invoked (via `/xweather-branding` or automatically when styling Xweather-branded interfaces), this skill loads the full brand identity into context: color tokens, type scale, layout principles, accessible pairings, and a CSS starter snippet. Claude can then generate HTML/CSS that follows Xweather guidelines out of the box.

## Contents

```text
skills/xweather-branding/
  SKILL.md              # Main skill prompt (colors, typography, layout rules, CSS starter)
  brand-book/
    brand-book.md       # Detailed summary of the full Xweather brand identity book
    *.png               # Source screenshots from the brand book (22 pages)
  slides/
    slides.md           # Patterns extracted from Xweather PowerPoint templates
    *.png               # Source screenshots from slide templates (9 slides)
  logos/
    Vaisala_Xweather_Logo_Black_RGB/   # Dark logo (SVG, PNG, AI)
    Vaisala_Xweather_Logo_White_RGB/   # White logo (SVG, PNG, AI)
```

## Key Brand Principles

- **Dark mode preferred** with Xweather Black (`#09151C`) as primary background
- **Squared-off corners** on all UI elements (no border-radius)
- **Flat coloring** (no shadows, no gradients on UI chrome)
- **Minimal color usage** -- structure hierarchy with grays, type, and layout rather than color
- **Reduced letter-spacing** on headlines (`-0.03em`) and ingress text (`-0.015em`)

## Links

- Xweather website (live example of the branding): <https://www.xweather.com/>
- Media kit: <https://www.xweather.com/for-media#media-kit>
