---
name: project-planning
description: >
  Use this skill whenever a user wants to plan a project, create a project spec,
  write a project brief, scope out work, define requirements, or kick off any
  initiative of meaningful complexity. Trigger on phrases like "help me plan",
  "let's scope out", "I want to build/create/launch X", "write a spec for",
  "project kickoff", "define requirements", or any time the user describes a
  goal that will require coordinated effort. This skill ensures thorough
  discovery via clarifying questions and produces a living spec document that
  gets updated incrementally throughout the conversation. Always use this skill
  even if the user just says "let's plan a project" without more detail — the
  discovery phase will gather what's needed.
---

# Project Planning Skill

This skill guides Claude through a structured project planning conversation that
produces a high-quality, living spec document. The spec is written and updated
incrementally — never all at once at the end.

---

## Core Principles

1. **Ask before assuming.** Never invent scope. Always surface ambiguity as a
   question.
2. **Write back to the spec continuously.** After each meaningful exchange,
   update the spec file. The user should be able to stop at any point and have
   a useful document.
3. **Single source of truth.** All decisions, requirements, and open questions
   live in the spec. Refer back to it, don't restate things from memory.
4. **Scope creep prevention.** When new ideas arise mid-conversation, flag them
   as "Out of Scope / Future" rather than silently expanding the project.
5. **SMART goals.** Objectives must be Specific, Measurable, Achievable,
   Relevant, and Time-bound.

---

## Workflow

### Phase 1: Discovery (Clarifying Questions)

Before writing anything, ask targeted questions to understand the project.
Batch related questions together — don't ask one at a time. Aim for 2–3 rounds
of questions max before starting the spec draft.

**Round 1 — The Big Picture** (always ask these):
- What is the goal? What does success look like in concrete terms?
- Who are the key stakeholders and end users?
- What's the rough timeline or deadline?
- Are there known constraints (budget, team size, tech stack, regulatory)?

**Round 2 — Depth** (ask based on Round 1 answers):
- What's explicitly out of scope?
- What are the top 3 risks or unknowns?
- What does the team already have (existing systems, prior work, assets)?
- Who is the decision-maker / project owner?

**Round 3 — Validation** (ask only if still unclear):
- Are there similar projects or references to learn from?
- What's the definition of "done" for Phase 1?
- What would cause this project to be cancelled?

Do not ask all questions at once. Read the user's level of detail and skip
questions that are clearly already answered.

---

### Phase 2: Write the Spec (Incremental)

Create the spec file at the start of Phase 2. Use the path:
`/mnt/user-data/outputs/project-spec.md`

Populate sections as information becomes available. Use `[TBD]` placeholders
for unanswered sections — do not leave them blank. After each major piece of
information is confirmed, update the file using `str_replace`.

**Spec structure** (see `references/spec-template.md` for the full template):

```
# Project Spec: [Project Name]
_Last updated: [date]_

## 1. Overview
## 2. Goals & Success Metrics
## 3. Stakeholders
## 4. Scope
   ### In Scope
   ### Out of Scope / Future
## 5. Requirements
   ### Functional Requirements
   ### Non-Functional Requirements
## 6. Timeline & Milestones
## 7. Risks & Mitigations
## 8. Open Questions
## 9. Decisions Log
```

---

### Phase 3: Iterative Refinement

As the conversation continues, keep the spec live:

- When the user clarifies something → update the relevant section
- When a new requirement emerges → add it to Functional or Non-Functional
  Requirements
- When something is deferred → move it to Out of Scope / Future
- When a decision is made → log it in the Decisions Log with a short rationale
- When a question is resolved → remove it from Open Questions (or move to
  Decisions Log)

Announce spec updates briefly: _"I've added that to the spec under Risks."_

---

### Phase 4: Wrap-Up

When the user signals they're done (or after a natural stopping point):

1. Do a final pass over the spec — check for `[TBD]` items and ask about
   any that are blocking
2. Present the spec file using `present_files`
3. Offer a brief summary: what's solid, what's still open

---

## Guardrails

- **Never expand scope silently.** If a user adds a new idea, ask: _"Should
  I add this to scope, or log it as a future consideration?"_
- **Avoid documentation debt.** Don't let more than 2–3 exchanges pass without
  updating the spec.
- **Flag contradictions.** If new information conflicts with something already
  in the spec, surface it: _"This seems to conflict with the deadline we noted
  earlier — want to revisit that?"_
- **Keep requirements testable.** Vague requirements like "fast" or "easy to
  use" should be challenged: _"Can we define a specific performance target?"_

---

## Reference Files

- `references/spec-template.md` — Full blank spec template to copy at project
  start
- `references/questions-bank.md` — Extended question bank by project type
  (software, marketing, operations, research)
