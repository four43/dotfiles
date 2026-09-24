#!/usr/bin/env bash
# PreToolUse/Bash gate: force an approval prompt before any git command that
# creates, deletes, or pushes a tag.
#
# Tagging is a publish step — it is how a release becomes visible to anything
# downstream — so it always needs an explicit human yes, never an inherited
# allow rule. Tag *listing* (-l/-n/--list) is read-only and stays silent.
#
# Deliberately not filtered with `if: "Bash(git *)"`: that prefix does not match
# chained commands such as `cd /repo && git tag v1.0`, which must still prompt.
# So this runs on every Bash call and decides here.
#
# Exit 0 with no stdout = no opinion, normal permission flow continues.

cmd=$(jq -r '.tool_input.command // ""')

if printf '%s' "$cmd" | grep -Eq 'git[[:space:]]+tag([[:space:]]|$)' \
  && ! printf '%s' "$cmd" | grep -Eq 'git[[:space:]]+tag[[:space:]]+(-l|-n|--list)'; then
  why="creates or deletes a git tag"
elif printf '%s' "$cmd" | grep -Eq 'git[[:space:]]+push' \
  && printf '%s' "$cmd" | grep -Eq '(--tags|--follow-tags|refs/tags/|[[:space:]]v[0-9])'; then
  why="pushes a git tag"
else
  exit 0
fi

printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"Release gate: this %s. Tagging publishes a release and always needs explicit approval."}}' "$why"
