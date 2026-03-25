#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TRANSCRIPTS_DIR="${1:-$SCRIPT_DIR/transcripts}"
PROMPT_FILE="$SCRIPT_DIR/analysis-prompt.md"
ANALYZER="$SCRIPT_DIR/acquired_transcripts.py"

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "Error: $PROMPT_FILE not found" >&2
  exit 1
fi

prompt="$(cat "$PROMPT_FILE")"
processed=0
skipped=0
failed=0

for file in "$TRANSCRIPTS_DIR"/*.json; do
  [[ "$(basename "$file")" == _index.json ]] && continue

  slug="$(basename "$file" .json)"

  # Skip files without analysis_start
  analysis_start="$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('analysis_start') or '')" "$file")"
  if [[ -z "$analysis_start" ]]; then
    echo "SKIP (no analysis_start): $slug"
    ((skipped++)) || true
    continue
  fi

  # Skip files already marked as not a company episode
  is_company="$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('is_company', True))" "$file")"
  if [[ "$is_company" == "False" ]]; then
    echo "SKIP (not a company):     $slug"
    ((skipped++)) || true
    continue
  fi

  # Skip files that already have a powers_analysis
  has_powers="$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print('yes' if 'powers_analysis' in d else '')" "$file")"
  if [[ -n "$has_powers" ]]; then
    echo "SKIP (already analyzed):  $slug"
    ((skipped++)) || true
    continue
  fi

  echo "ANALYZING: $slug (analysis @ $analysis_start)"
  if "$ANALYZER" analysis "$file" | claude -p "$prompt" | "$ANALYZER" save-powers "$file"; then
    ((processed++)) || true
  else
    echo "  FAILED: $slug" >&2
    ((failed++)) || true
  fi
done

echo ""
echo "Done: $processed processed, $skipped skipped, $failed failed"
