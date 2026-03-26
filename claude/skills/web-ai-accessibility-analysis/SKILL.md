---
name: web-ai-accessibility-analysis
description: >
  Analyze a web page's accessibility for both human users and AI bots/agents.
  Fetches the page two ways — rendered content via WebFetch and raw HTML via
  curl — then evaluates against WCAG 2.1 AA, semantic HTML best practices,
  and AI/bot readability (structured data, ARIA, heading hierarchy, link
  context, form labels). Produces a graded report with actionable fixes.
  Trigger on phrases like "accessibility analysis", "a11y audit",
  "check accessibility", "is this page accessible", "can AI read this page",
  "bot accessibility", or any request to evaluate a web page for
  accessibility or AI readability.
---

# Web + AI Accessibility Analysis Skill

Analyze a web page's accessibility for **human users** (screen readers,
keyboard navigation, low vision, cognitive) and **AI consumers** (LLM agents,
web scrapers, search engines, assistive bots). Produces a structured report
with grades and actionable fixes.

---

## Core Principles

1. **Two fetches, two perspectives.** Always fetch the page both ways:
   - `WebFetch` — gives you the rendered, readable content (what an LLM or
     reader-mode sees)
   - `curl` to a temp file — gives you the raw HTML structure for inspecting
     tags, attributes, ARIA roles, and markup quality
2. **Standards-based.** Grade against WCAG 2.1 AA as the baseline. Reference
   specific success criteria (e.g., SC 1.1.1, SC 2.4.6) when citing issues.
3. **AI-readability is a first-class concern.** Evaluate how well an AI agent
   can parse, navigate, and extract meaning from the page.
4. **Be specific.** Don't say "add alt text" — say which images are missing it
   and suggest what the alt text should convey.
5. **Grade honestly.** A page with serious issues should get a low grade.

---

## Workflow

### Phase 0: Setup

1. Get the URL from the user
2. Ask if there are specific concerns or focus areas (optional — don't block
   on this, proceed with defaults if they just give a URL)

### Phase 1: Fetch the Page Two Ways

Run these in parallel:

#### 1a. WebFetch (rendered content)

Use the `WebFetch` tool to get the page content. This shows you what an LLM
or reader-mode would see — the "clean" version of the page.

Review this for:
- Content structure and readability
- Whether key information survives the rendering pipeline
- Navigation flow and content hierarchy

#### 1b. curl (raw HTML structure)

```bash
TMPFILE=$(mktemp /tmp/a11y-audit-XXXXXX.html)
curl -sL -A "Mozilla/5.0 (compatible; accessibility-audit)" -o "$TMPFILE" "<URL>"
echo "$TMPFILE"
```

Then **read the temp file** to inspect raw HTML. This is where you find
structural issues invisible in rendered content.

### Phase 2: Human Accessibility Audit (WCAG 2.1 AA)

Analyze the raw HTML for each category below. For every issue found, note:
- The WCAG success criterion violated
- The specific element(s) affected (quote the HTML)
- Severity: Critical / Major / Minor
- Suggested fix with example code

#### 2a. Perceivable

| Check | WCAG SC | What to look for |
|---|---|---|
| **Images** | 1.1.1 | `<img>` without `alt`, decorative images missing `alt=""` or `role="presentation"` |
| **Video/Audio** | 1.2.x | `<video>`/`<audio>` without captions or transcripts |
| **Color contrast** | 1.4.3, 1.4.6 | Inline styles with low-contrast color pairs, text on background images without fallback |
| **Text resize** | 1.4.4 | Fixed font sizes in `px` instead of `rem`/`em`, `maximum-scale=1` in viewport meta |
| **Content reflow** | 1.4.10 | Horizontal scrolling indicators, fixed-width containers |

#### 2b. Operable

| Check | WCAG SC | What to look for |
|---|---|---|
| **Keyboard access** | 2.1.1 | Click handlers on non-interactive elements without `tabindex`, `onmousedown` without `onkeydown` |
| **Focus visible** | 2.4.7 | `outline: none` or `outline: 0` in styles without alternative focus indicator |
| **Skip navigation** | 2.4.1 | Missing skip-to-content link |
| **Page title** | 2.4.2 | Missing or generic `<title>` |
| **Heading hierarchy** | 2.4.6 | Skipped heading levels (e.g., `h1` → `h3`), multiple `h1` tags |
| **Link purpose** | 2.4.4 | Links with text like "click here", "read more", "learn more" without `aria-label` |

#### 2c. Understandable

| Check | WCAG SC | What to look for |
|---|---|---|
| **Language** | 3.1.1 | Missing `lang` attribute on `<html>` |
| **Form labels** | 3.3.2 | `<input>` without associated `<label>`, missing `placeholder` as sole label |
| **Error identification** | 3.3.1 | Form validation without accessible error messages |
| **Consistent nav** | 3.2.3 | Navigation that changes order across the page |

#### 2d. Robust

| Check | WCAG SC | What to look for |
|---|---|---|
| **Valid HTML** | 4.1.1 | Duplicate IDs, unclosed tags, improper nesting |
| **ARIA usage** | 4.1.2 | `role` without required ARIA attributes, `aria-labelledby` referencing missing IDs |
| **Name, Role, Value** | 4.1.2 | Custom controls (divs acting as buttons) without proper ARIA roles |

### Phase 3: AI / Bot Readability Audit

Evaluate how well AI agents, LLMs, and bots can consume the page.

#### 3a. Structured Data

- Check for `<script type="application/ld+json">` — parse and summarize
- Check for microdata (`itemscope`, `itemprop`) or RDFa
- Grade: Is there enough structured data for an AI to understand what this
  page *is* (article, product, event, org, FAQ)?

#### 3b. Semantic HTML

- Are content sections marked with `<article>`, `<section>`, `<nav>`,
  `<aside>`, `<header>`, `<footer>`, `<main>`?
- Or is it `<div>` soup? Count the ratio of semantic to non-semantic
  container elements.
- Are lists actually `<ul>`/`<ol>` or just styled divs?
- Are tables used for data or layout?

#### 3c. Heading Hierarchy as Outline

- Extract all headings (`h1`-`h6`) in order
- Present as an indented outline
- Evaluate: Does this outline accurately represent the page's content
  structure? Could an AI use headings alone to understand the page?

#### 3d. Link & Navigation Context

- Do links have descriptive text (not "click here")?
- Is there a `<nav>` with clear structure?
- Are there breadcrumbs (structured data or HTML)?
- Could an AI agent navigate this site from this page alone?

#### 3e. Meta & Machine-Readable Signals

- `<meta name="description">` present and useful?
- `<meta name="robots">` — is the page indexable?
- Open Graph / Twitter Card tags
- `<link rel="canonical">`
- RSS/Atom feed links
- Sitemap reference
- `robots.txt` considerations

#### 3f. Content Extractability

- Compare WebFetch output to raw HTML — how much content survives?
- Is critical content hidden behind JavaScript rendering (invisible to curl)?
- Are there `<noscript>` fallbacks?
- Is content in images without text alternatives?
- Would an AI agent miss important information if it could only see the
  rendered text?

#### 3g. Content Integrity Check (Animated / JS-Dependent Values)

Many pages use JavaScript to animate statistics, counters, or key figures
(e.g., "40%" animates from 0 to 40 on scroll). Bots that fetch raw HTML see
the **initial value** (often `0` or empty), not the final displayed value.

**How to check:**
1. In the raw HTML, search for patterns that suggest animated counters:
   - Elements with text content of `0`, `0%`, `$0`, etc. near classes or
     attributes containing words like `counter`, `animate`, `count`, `stat`,
     `number`, `metric`, `figure`
   - `data-*` attributes that hold target values (e.g., `data-count="40"`,
     `data-target="1000"`, `data-value`)
   - Intersection Observer or scroll-trigger patterns in inline scripts
2. Compare any statistics or numbers mentioned in the WebFetch output against
   the raw HTML. If WebFetch shows "40%" but the raw HTML shows "0%", the
   value is JS-animated.
3. Flag each animated value found with:
   - The element and its raw HTML value
   - The intended display value (from `data-*` attrs or WebFetch)
   - Impact: bots, screen readers reading the page before animation fires,
     and search engines will all see the wrong value

**Why this matters:** Search engines may index "0%" instead of "40%". Screen
readers announce the initial DOM value. AI agents scraping the page get
incorrect data. SSR frameworks that hydrate on the client are especially prone
to this — the server renders the initial state, JS animates it later.

### Phase 4: Report Generation

Create the report file using `references/report-template.md` as the structure.
Default output path: `./accessibility-report.md` (or user-specified path).

#### Grading Scale

Grade each category **A-F**:

| Grade | Meaning |
|---|---|
| **A** | Excellent — meets or exceeds standards, minimal issues |
| **B** | Good — mostly compliant, only minor issues |
| **C** | Acceptable — several issues but core content is accessible |
| **D** | Poor — significant barriers for some users or AI consumers |
| **F** | Failing — critical issues that block access |

#### Overall Grades Table

| Category | Grade | Summary |
|---|---|---|
| **Perceivable** (WCAG) | | |
| **Operable** (WCAG) | | |
| **Understandable** (WCAG) | | |
| **Robust** (WCAG) | | |
| **AI Structured Data** | | |
| **AI Semantic HTML** | | |
| **AI Content Extractability** | | |
| **Overall Human A11y** | | |
| **Overall AI Readability** | | |

### Phase 5: Remediation Priorities

Present a prioritized fix list:

1. **Critical** — blocks access entirely (missing form labels, no keyboard
   access, no alt text on functional images)
2. **High** — significant barrier (poor heading structure, missing skip nav,
   no structured data)
3. **Medium** — degrades experience (missing lang attribute, generic link
   text, no meta description)
4. **Low** — nice to have (additional structured data types, microdata
   enrichment, Open Graph tags)

For each fix, provide a concrete code example showing the before/after.

---

## Guardrails

- **Always fetch both ways.** The WebFetch-only view misses structural issues;
  the curl-only view misses JavaScript-rendered content. You need both.
- **Don't guess about color contrast.** You can flag suspicious inline styles
  but note that full contrast analysis requires visual rendering. Suggest
  tools like axe or Lighthouse for definitive contrast checks.
- **Don't fabricate WCAG criteria.** If you're unsure which SC applies, say so
  rather than citing a wrong one.
- **Clean up temp files.** After analysis, remove the curl temp file.
- **Write the report incrementally.** Update the output file after each phase
  so the user always has a partial result.
- **Scope to the single page.** Don't crawl the entire site unless asked.
  Note when issues likely affect the whole site (e.g., missing lang attribute,
  no skip nav) vs. page-specific issues.
