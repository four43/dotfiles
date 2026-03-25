#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "click",
#   "requests",
#   "beautifulsoup4",
#   "lxml",
# ]
# ///
"""
Acquired Podcast Transcript Scraper
Source: podscripts.co/podcasts/acquired

Fetches full transcripts and automatically extracts the 7 Powers / strategy
analysis section from each episode (the segment at the end of every episode
where Ben & David apply Hamilton Helmer's framework to the company).

Usage:
  uv run acquired_transcripts.py fetch                       # Fetch all episodes
  uv run acquired_transcripts.py fetch --limit 5             # Fetch first 5 episodes
  uv run acquired_transcripts.py fetch --output ./data       # Custom output directory
  uv run acquired_transcripts.py fetch --list-only           # Just print episode index
  uv run acquired_transcripts.py fetch --no-skip-existing    # Re-download all episodes
  uv run acquired_transcripts.py reanalyze formula-1.json    # Re-run analysis on a transcript
"""

import json
import re
import time
from dataclasses import asdict, dataclass
from pathlib import Path

import click
import requests
from bs4 import BeautifulSoup

BASE_URL = "https://podscripts.co"
INDEX_URL = f"{BASE_URL}/podcasts/acquired"
HEADERS = {
    "User-Agent": "Mozilla/5.0 (compatible; AcquiredTranscriptScraper/1.0)"
}
DELAY_SECONDS = 1.5  # polite crawl delay

# Boilerplate suffix appended by PodScripts.co to the final transcript segment
_PODSCRIPTS_SUFFIX_RE = re.compile(
    r"\s*There aren't comments yet for this episode\..*$",
    re.DOTALL,
)

# Patterns to strip from slugs to get clean filenames
# e.g. "acquired-episode-15-exacttarget-..." -> "exacttarget-..."
#      "season-3-episode-7-venmo-..." -> "venmo-..."
_SLUG_PREFIX_RE = re.compile(
    r"^(?:acquired-)?(?:season-\d+-)?episode-\d+-"
)


def clean_slug(slug: str) -> str:
    """Strip episode/season numbering prefix from a slug."""
    return _SLUG_PREFIX_RE.sub("", slug)


# Title preamble: "Acquired - Episode 9: ", "Acquired - Season 3, Episode 5: ", or "Acquired - "
_TITLE_PREAMBLE_RE = re.compile(
    r"^Acquired\s*-\s*(?:Season\s+\d+,?\s*)?(?:Episode\s+\d+:\s*)?"
)


def clean_title(title: str) -> str:
    """Strip 'Acquired - Episode N:' preamble from a title."""
    return _TITLE_PREAMBLE_RE.sub("", title)


# Phrases that signal the start of the analysis section (Power / Playbook / Grading).
# Searched backwards from carve outs to find the nearest match.
ANALYSIS_ENTRY_PHRASES = [
    "seven powers",
    "7 powers",
    "tech themes",  # early episodes used this instead of "analysis"
]


@dataclass
class Episode:
    slug: str
    title: str
    date: str
    url: str
    transcript: list[dict]        # [{"timestamp": "HH:MM:SS", "text": "..."}]
    analysis_start: str | None    # timestamp (HH:MM:SS) where the 7 Powers analysis begins


MAX_RETRIES = 5
BACKOFF_BASE = 2  # seconds; doubles each retry


def fetch_soup(url: str) -> BeautifulSoup:
    for attempt in range(MAX_RETRIES):
        resp = requests.get(url, headers=HEADERS, timeout=15)
        if resp.status_code == 429:
            wait = BACKOFF_BASE * (2 ** attempt)
            retry_after = resp.headers.get("Retry-After")
            if retry_after and retry_after.isdigit():
                wait = max(wait, int(retry_after))
            click.echo(f"  Rate limited (429). Retrying in {wait}s... (attempt {attempt + 1}/{MAX_RETRIES})")
            time.sleep(wait)
            continue
        resp.raise_for_status()
        return BeautifulSoup(resp.text, "lxml")
    resp.raise_for_status()  # final attempt failed — raise the error


def get_episode_index(max_pages: int = 20) -> list[dict]:
    """Scrape all episode slugs, titles, and dates from the index pages."""
    episodes = []
    page = 1

    while page <= max_pages:
        url = INDEX_URL if page == 1 else f"{INDEX_URL}?page={page}"
        print(f"  Fetching index page {page}: {url}")
        soup = fetch_soup(url)

        # Each episode is an <a> with href /podcasts/acquired/<slug>
        links = soup.select("a[href^='/podcasts/acquired/']")
        # Filter to episode links only (exclude the base index link)
        episode_links = [
            a for a in links
            if a["href"] not in ("/podcasts/acquired/", "/podcasts/acquired")
        ]

        if not episode_links:
            break

        for a in episode_links:
            slug = a["href"].rstrip("/").split("/")[-1]
            title = a.get_text(strip=True)
            # Date is in a nearby element; grab from parent card
            parent = a.find_parent()
            date_el = parent.find(string=re.compile(r"\d{4}-\d{2}-\d{2}")) if parent else None
            date = date_el.strip() if date_el else ""

            if slug and title:
                episodes.append({
                    "slug": slug,
                    "title": title,
                    "date": date,
                    "url": f"{BASE_URL}{a['href']}",
                })

        # Check if there's a next page
        next_link = soup.find("a", string=str(page + 1))
        if not next_link:
            break

        page += 1
        time.sleep(DELAY_SECONDS)

    # Deduplicate by slug (preserving order)
    seen = set()
    unique = []
    for ep in episodes:
        if ep["slug"] not in seen:
            seen.add(ep["slug"])
            unique.append(ep)

    return unique


def parse_transcript(soup: BeautifulSoup) -> list[dict]:
    """Extract timestamped transcript segments from an episode page."""
    segments = []

    # Transcripts use "Starting point is HH:MM:SS" as timestamp markers
    # The text content follows each marker
    full_text = soup.get_text(separator="\n")
    lines = full_text.splitlines()

    current_timestamp = None
    current_lines = []

    timestamp_pattern = re.compile(r"Starting point is\s+(\d{2}:\d{2}:\d{2})")

    for line in lines:
        line = line.strip()
        if not line:
            continue

        match = timestamp_pattern.search(line)
        if match:
            # Save previous segment
            if current_timestamp is not None and current_lines:
                segments.append({
                    "timestamp": current_timestamp,
                    "text": " ".join(current_lines).strip(),
                })
            current_timestamp = match.group(1)
            # Text may appear on the same line after the timestamp marker
            remainder = line[match.end():].strip().lstrip("·").strip()
            current_lines = [remainder] if remainder else []
        elif current_timestamp is not None:
            current_lines.append(line)

    # Don't forget the final segment
    if current_timestamp is not None and current_lines:
        segments.append({
            "timestamp": current_timestamp,
            "text": " ".join(current_lines).strip(),
        })

    # Strip PodScripts.co boilerplate from the last segment
    if segments:
        segments[-1]["text"] = _PODSCRIPTS_SUFFIX_RE.sub("", segments[-1]["text"]).strip()

    return segments


def _segment_has_entry_phrase(text: str) -> bool:
    """Return True if this segment contains a known analysis-section entry phrase."""
    lower = text.lower()
    return any(p in lower for p in ANALYSIS_ENTRY_PHRASES)


def find_analysis_start(segments: list[dict]) -> str | None:
    """
    Find the timestamp where the analysis section begins.

    The analysis section is the 2nd-to-last major section (carve outs is last).
    Strategy:
    1. Find the last segment containing "carve out" — this marks the end of analysis.
    2. Search backwards from carve outs for the nearest analysis entry phrase.
    3. If no carve outs found, search backwards from the end of the episode.
    4. Only search the back half of the episode.
    """
    if not segments:
        return None

    n = len(segments)
    halfway = n // 2

    # ── Step 1: find carve outs (search backwards from end) ──────────────
    carveout_idx = None
    for i in range(n - 1, halfway - 1, -1):
        if "carve out" in segments[i]["text"].lower():
            carveout_idx = i
            break

    # Search boundary: from carve outs back to halfway, or from end if no carve outs
    search_from = (carveout_idx if carveout_idx is not None else n) - 1

    # ── Step 2: search backwards for an analysis entry phrase ────────────
    for i in range(search_from, halfway - 1, -1):
        if _segment_has_entry_phrase(segments[i]["text"]):
            return segments[i]["timestamp"]

    return None


def fetch_episode(ep_info: dict) -> Episode:
    """Fetch and parse a single episode transcript."""
    soup = fetch_soup(ep_info["url"])

    # Try to get a clean title from the page <h1> if available
    h1 = soup.find("h1")
    title = clean_title(h1.get_text(strip=True) if h1 else ep_info["title"])

    # Try to extract date from page if not already found
    date = ep_info["date"]
    if not date:
        date_match = re.search(r"Episode Date:\s*(\w+ \d+, \d{4})", soup.get_text())
        if date_match:
            date = date_match.group(1)

    transcript = parse_transcript(soup)
    analysis_start = find_analysis_start(transcript)

    return Episode(
        slug=clean_slug(ep_info["slug"]),
        title=title,
        date=date,
        url=ep_info["url"],
        transcript=transcript,
        analysis_start=analysis_start,
    )


def save_episode(episode: Episode, output_dir: Path) -> None:
    """Save episode as JSON, stripping episode/season numbering from filename."""
    output_dir.mkdir(parents=True, exist_ok=True)
    path = output_dir / f"{clean_slug(episode.slug)}.json"
    with open(path, "w", encoding="utf-8") as f:
        json.dump(asdict(episode), f, indent=2, ensure_ascii=False)


def save_index(episodes: list[dict], output_dir: Path) -> None:
    """Save episode index as JSON."""
    output_dir.mkdir(parents=True, exist_ok=True)
    path = output_dir / "_index.json"
    with open(path, "w", encoding="utf-8") as f:
        json.dump(episodes, f, indent=2, ensure_ascii=False)
    print(f"Saved index with {len(episodes)} episodes → {path}")


@click.group(help="Acquired podcast transcript scraper")
def cli():
    pass


@cli.command(help="Fetch transcripts from podscripts.co")
@click.option("--output", default="./transcripts", help="Output directory.", show_default=True)
@click.option("--limit", type=int, default=None, help="Limit number of episodes to fetch.")
@click.option("--list-only", is_flag=True, help="Only print episode index, don't fetch transcripts.")
@click.option("--skip-existing/--no-skip-existing", default=True, help="Skip episodes already downloaded.", show_default=True)
def fetch(output: str, limit: int | None, list_only: bool, skip_existing: bool):
    output_dir = Path(output)

    click.echo("=== Acquired Podcast Transcript Scraper ===")
    click.echo(f"Output directory: {output_dir.resolve()}")
    click.echo()

    # Step 1: Build episode index
    click.echo("Building episode index...")
    episodes = get_episode_index()
    click.echo(f"Found {len(episodes)} episodes\n")

    if limit:
        episodes = episodes[:limit]
        click.echo(f"Limiting to {limit} episodes\n")

    save_index(episodes, output_dir)

    if list_only:
        for i, ep in enumerate(episodes, 1):
            click.echo(f"  {i:3}. [{ep['date']}] {ep['title']}")
        return

    # Step 2: Fetch transcripts
    click.echo(f"\nFetching {len(episodes)} transcripts...")
    success, skipped, failed = 0, 0, 0

    for i, ep_info in enumerate(episodes, 1):
        out_path = output_dir / f"{clean_slug(ep_info['slug'])}.json"
        if skip_existing and out_path.exists():
            click.echo(f"  [{i:3}/{len(episodes)}] SKIP  {ep_info['title']}")
            skipped += 1
            continue

        click.echo(f"  [{i:3}/{len(episodes)}] Fetching: {ep_info['title']}")
        try:
            episode = fetch_episode(ep_info)
            save_episode(episode, output_dir)
            seg_count = len(episode.transcript)
            analysis_note = f", analysis @ {episode.analysis_start}" if episode.analysis_start else ", no analysis found"
            click.echo(f"           → {seg_count} segments{analysis_note} → {out_path.name}")
            success += 1
        except Exception as e:
            click.echo(f"           ✗ FAILED: {e}")
            failed += 1

        time.sleep(DELAY_SECONDS)

    click.echo("\n=== Done ===")
    click.echo(f"  Success:  {success}")
    click.echo(f"  Skipped:  {skipped}")
    click.echo(f"  Failed:   {failed}")
    click.echo(f"  Output:   {output_dir.resolve()}")


@cli.command(help="Re-run analysis extraction on existing transcript JSON files.")
@click.argument("files", nargs=-1, required=True, type=click.Path(exists=True, path_type=Path))
def reanalyze(files: tuple[Path, ...]):
    for path in files:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)

        transcript = data.get("transcript", [])
        old_start = data.get("analysis_start")
        data["analysis_start"] = find_analysis_start(transcript)
        data.pop("analysis_section", None)

        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)

        click.echo(f"  {path.name}: {old_start} → {data['analysis_start']}")


@cli.command(help="Print the analysis section text from a transcript JSON file.")
@click.argument("file", type=click.Path(exists=True, path_type=Path))
def analysis(file: Path):
    with open(file, encoding="utf-8") as f:
        data = json.load(f)

    transcript = data.get("transcript", [])
    analysis_start = data.get("analysis_start")

    if not analysis_start:
        click.echo(f"No analysis_start found in {file.name}", err=True)
        raise SystemExit(1)

    # Collect segments from analysis_start through the end (or until carve outs)
    in_analysis = False
    for seg in transcript:
        if seg["timestamp"] == analysis_start:
            in_analysis = True
        if in_analysis:
            if "carve out" in seg["text"].lower():
                break
            click.echo(f"[{seg['timestamp']}] {seg['text']}\n")


@cli.command("save-powers", help="Save a 7 Powers analysis (JSON from stdin) into a transcript file.")
@click.argument("file", type=click.Path(exists=True, path_type=Path))
def save_powers(file: Path):
    raw = click.get_text_stream("stdin").read().strip()
    if not raw:
        click.echo("Error: no JSON provided on stdin", err=True)
        raise SystemExit(1)

    # Strip markdown code fences if present (e.g. ```json ... ```)
    fence_match = re.search(r"```(?:json)?\s*\n(.*?)```", raw, re.DOTALL)
    analysis_json = fence_match.group(1).strip() if fence_match else raw

    try:
        powers_data = json.loads(analysis_json)
    except json.JSONDecodeError as e:
        click.echo(f"Error: invalid JSON on stdin: {e}", err=True)
        raise SystemExit(1)

    with open(file, encoding="utf-8") as f:
        data = json.load(f)

    if powers_data.get("is_company") is False:
        data["is_company"] = False
        label = "is_company=false"
    else:
        data["is_company"] = True
        data["powers_analysis"] = powers_data
        label = "powers analysis"

    with open(file, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

    click.echo(f"Saved {label} → {file.name}")


if __name__ == "__main__":
    cli()
