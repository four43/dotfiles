---
name: business-analysis
description: >
  Deep research skill for analyzing businesses — existing companies or new ideas.
  Researches competitors via web search, grades the business against them, and
  produces a structured report using frameworks like Business Model Canvas,
  Hamilton Helmer's 7 Powers, Porter's Five Forces, and competitive positioning
  maps. Trigger on phrases like "analyze this business", "business analysis",
  "competitive analysis", "how does X compare to competitors", "is this business
  idea viable", "market analysis", or any request to evaluate a company's
  competitive position, market fit, or strategic strengths.
---

# Business Analysis Skill

This skill guides Claude through a deep-research business analysis that produces
a comprehensive, framework-backed report. It uses web search extensively to
gather real competitor and market data before applying strategic frameworks.

---

## Core Principles

1. **Research before opining.** Always search the web for real data — competitors,
   pricing, market size, funding, reviews — before filling in any framework.
2. **Frameworks are lenses, not checklists.** Use each framework to surface
   different insights. Skip sections that don't apply; go deep where they do.
3. **Grade honestly.** The user wants signal, not cheerleading. Be direct about
   weaknesses and existential risks.
4. **Cite sources.** When stating market data, competitor info, or claims, note
   where you found it.
5. **Write incrementally.** Update the report file after each research phase so
   the user always has a useful artifact.

---

## Workflow

### Phase 0: Intake

Ask the user enough to start researching. Batch these questions — don't
over-interrogate before doing any work.

**Essential (always ask what's missing):**
- What is the business / idea? (name, URL, one-liner description)
- What problem does it solve and for whom?
- What's the revenue model (or intended model)?
- Is this an existing business you run/are evaluating, or a new idea?

**If the user provides a URL or company name**, skip questions they've already
answered implicitly and move to research.

---

### Phase 1: Competitive Landscape Research

Use `WebSearch` and `WebFetch` extensively. Search for:

1. **Direct competitors** — companies solving the same problem for the same
   customer segment
2. **Indirect competitors** — alternative solutions the customer might use
   (including "do nothing" or manual workarounds)
3. **Market data** — TAM/SAM/SOM estimates, growth rates, recent funding rounds
   in the space
4. **Customer sentiment** — reviews, complaints, Reddit/HN threads, G2/Capterra
   ratings for competitors
5. **Pricing intelligence** — competitor pricing pages, packaging, free tiers

Build a competitor table as you go:

| Competitor | One-liner | Target Customer | Pricing | Key Differentiator | Weakness |
|---|---|---|---|---|---|

Create the report file at this point and populate the competitor landscape
section. Use the path the user specifies, or default to
`./business-analysis-report.md`.

---

### Phase 2: Framework Analysis

Apply each framework using the research gathered. Not every framework will be
equally useful — spend more time on the ones that yield real insight for this
particular business.

#### 2a. Business Model Canvas

Fill in all 9 blocks. Be specific — don't write generic filler.

| Block | Description |
|---|---|
| **Key Partners** | Who do you depend on? Suppliers, platforms, channel partners |
| **Key Activities** | What must you do well to deliver the value proposition? |
| **Key Resources** | Assets required — IP, talent, data, capital, brand |
| **Value Proposition** | Why does the customer pick you over alternatives? |
| **Customer Relationships** | Self-serve, high-touch, community, automated? |
| **Channels** | How do customers discover and buy? |
| **Customer Segments** | Who specifically — be narrow, not "everyone" |
| **Cost Structure** | Major cost drivers — fixed vs variable |
| **Revenue Streams** | How money comes in — subscriptions, transactions, licensing |

#### 2b. Hamilton Helmer's 7 Powers

For each power, assess whether the business **has it**, **could build it**, or
**lacks it**, and explain why. This is the most important framework for
long-term defensibility.

| Power | Definition | Assessment |
|---|---|---|
| **Scale Economies** | Unit costs decline with volume | |
| **Network Economies** | Value increases with each user | |
| **Counter-Positioning** | Incumbents can't copy you without damaging their own business | |
| **Switching Costs** | Customers face real cost to leave | |
| **Branding** | Reputation that justifies premium pricing | |
| **Cornered Resource** | Exclusive access to a valuable asset (talent, data, IP, rights) | |
| **Process Power** | Org capabilities built over time that are hard to replicate | |

**Power Score:** Summarize as a simple count — e.g., "2 powers present,
1 emerging, 4 absent" — and assess whether the business has enough
defensibility to sustain margins long-term.

#### 2c. Porter's Five Forces

Assess the attractiveness of the industry/market:

| Force | Intensity (Low/Med/High) | Analysis |
|---|---|---|
| **Threat of New Entrants** | | Barriers to entry, capital requirements |
| **Bargaining Power of Suppliers** | | Concentration, switching costs |
| **Bargaining Power of Buyers** | | Price sensitivity, alternatives |
| **Threat of Substitutes** | | How easily could customers solve this differently? |
| **Competitive Rivalry** | | Number of players, differentiation, growth rate |

#### 2d. Competitive Positioning Map

Describe (or suggest the user visualize) a 2x2 positioning map. Pick the two
axes that matter most for this market. Common axis pairs:

- Price vs. Feature Depth
- Self-serve vs. High-touch
- SMB-focused vs. Enterprise-focused
- Generalist vs. Specialist
- Speed/simplicity vs. Power/flexibility

Place the subject business and top 3-5 competitors on the map. Identify
white space or crowded zones.

---

### Phase 3: Grading & Synthesis

Produce an overall assessment with honest grades.

#### Competitive Advantages (what's working)
List the real, defensible advantages — things competitors can't easily copy.

#### Vulnerabilities (what's exposed)
List the biggest risks: competitive, operational, market, regulatory.

#### Market Position
Categorize the business:
- **Premium player** — high price, high value, brand-driven
- **Cost leader** — winning on price/efficiency
- **Niche specialist** — dominant in a narrow segment
- **Challenger** — attacking incumbents with a new model
- **Commodity** — undifferentiated, competing on execution alone
- **Pioneer** — creating a new category

#### Overall Grade

Grade on a simple A-F scale across these dimensions:

| Dimension | Grade | Rationale |
|---|---|---|
| **Defensibility** (7 Powers) | | |
| **Market Attractiveness** (Five Forces) | | |
| **Business Model Clarity** (Canvas) | | |
| **Competitive Position** | | |
| **Overall** | | |

#### Strategic Recommendations
3-5 concrete actions the business should consider, ranked by impact. Be
specific — "improve marketing" is useless; "build a self-serve onboarding
flow to reduce CAC from ~$X to ~$Y" is useful.

---

### Phase 4: Report Finalization

1. Do a final pass — ensure all frameworks are populated with real data, not placeholders
2. Present the report file to the user
3. Offer to dive deeper on any section

---

## Report Template

Use `references/report-template.md` as the starting structure for the output
document.

---

## Guardrails

- **Don't fabricate market data.** If you can't find a number, say so and
  provide your best estimate with reasoning, clearly labeled as an estimate.
- **Don't grade inflated.** The user benefits from honest assessment, not
  encouragement. A weak business should get a weak grade.
- **Don't skip research.** Every framework section should reference specific
  competitors or data points found during Phase 1.
- **Flag when you're uncertain.** If the market is niche and data is sparse,
  say that — it's itself a useful signal (small market, hard to validate).
- **Update the report incrementally.** Don't wait until the end. The user
  should be able to stop mid-conversation and have a useful partial report.
