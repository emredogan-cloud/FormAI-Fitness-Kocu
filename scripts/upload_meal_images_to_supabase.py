#!/usr/bin/env python3
"""Phase 2-A.3 · Upload the 293 recipe images to Supabase Storage `recipes_images`.

Requirements (read once from environment, not CLI args, so the service-role
key never lands in shell history):

    SUPABASE_URL                  — e.g. https://abc123.supabase.co
    SUPABASE_SERVICE_ROLE_KEY     — service_role JWT from Supabase Studio →
                                    Project Settings → API. Bypasses RLS
                                    so it can write into a bucket the
                                    anon role can only READ.

Properties:

    • Uploads ONLY the recipe corpus. The 5 `budget_cover_*.webp` files
      in photos/meals/ are excluded — they are UI tiles, not DB rows,
      and ship as bundled assets (see MEAL_ASSET_INVENTORY.md §2.2).

    • Preserves filenames verbatim. The Supabase object key for
      `acili_domates_corbasi.webp` is the same string.

    • Sets `Cache-Control: public, max-age=2592000, immutable` on every
      object. Slug → filename mapping is permanent, so `immutable` is
      safe; readers get 30-day edge caching.

    • Resumable-safe. On every successful upload, appends the filename
      to `scripts/.upload_meal_images_resume.log` (gitignored). On
      restart, the script skips anything already in that log AND
      anything that returns 409 (already exists in bucket) — collisions
      are *logged*, not retried.

    • Robust logging. Per-file outcome printed as one line:
        OK      <file>      <bytes>
        SKIP    <file>      <reason>
        COLLIDE <file>      409
        FAIL    <file>      <http_status> <truncated_response>

    • Single-threaded by default. Parallelism is more complexity than
      a one-shot 293-file migration warrants; 293 sequential uploads
      over a typical 50 Mbps uplink takes ~3-4 minutes. To override,
      run with --parallel 4 (uses concurrent.futures).

    • Non-destructive. Never deletes, never overwrites (unless
      --overwrite is passed, which is NOT recommended for prod runs).

Usage:

    export SUPABASE_URL='https://<ref>.supabase.co'
    export SUPABASE_SERVICE_ROLE_KEY='eyJhbGciOi...'   # paste — do NOT commit

    python3 scripts/upload_meal_images_to_supabase.py            # default
    python3 scripts/upload_meal_images_to_supabase.py --dry-run  # list, no upload
    python3 scripts/upload_meal_images_to_supabase.py --parallel 4

    # Resume after interruption (no flag needed — the log handles it):
    python3 scripts/upload_meal_images_to_supabase.py

Verification (post-upload):

    # Pick 3 random uploaded slugs and confirm public URLs render:
    grep '^OK' scripts/.upload_meal_images_resume.log | shuf -n 3 |
      awk '{print "https://<ref>.supabase.co/storage/v1/object/public/recipes_images/" $2}' |
      xargs -n 1 curl -sI | grep -E '^(HTTP|Content-Type|Cache-Control)'
    # Expected:
    #   HTTP/2 200
    #   Content-Type: image/webp
    #   Cache-Control: public, max-age=2592000, immutable
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import NamedTuple

REPO_ROOT = Path(__file__).resolve().parent.parent
SRC = REPO_ROOT / "photos" / "meals"
RESUME_LOG = REPO_ROOT / "scripts" / ".upload_meal_images_resume.log"
BUCKET = "recipes_images"
CACHE_CONTROL = "public, max-age=2592000, immutable"

# Files excluded from the migration corpus per MEAL_ASSET_INVENTORY.md §2.2.
# These are hardcoded UI category covers (nutrition_tab.dart) and stay
# bundled as local assets.
EXCLUDE_PREFIX = "budget_cover_"


class Outcome(NamedTuple):
    kind: str        # OK / SKIP / COLLIDE / FAIL
    filename: str
    detail: str


def _env(name: str) -> str:
    val = os.environ.get(name, "").strip()
    if not val:
        sys.stderr.write(
            f"ERROR: env var {name} is missing or empty.\n"
            f"       export it before running this script. See module docstring.\n"
        )
        sys.exit(2)
    return val.rstrip("/")


def _load_resume_set() -> set[str]:
    if not RESUME_LOG.exists():
        return set()
    done: set[str] = set()
    with RESUME_LOG.open("r", encoding="utf-8") as fp:
        for line in fp:
            parts = line.strip().split("\t")
            if len(parts) >= 2 and parts[0] == "OK":
                done.add(parts[1])
    return done


def _append_resume(outcome: Outcome) -> None:
    RESUME_LOG.parent.mkdir(parents=True, exist_ok=True)
    with RESUME_LOG.open("a", encoding="utf-8") as fp:
        fp.write(f"{outcome.kind}\t{outcome.filename}\t{outcome.detail}\n")


def _list_corpus() -> list[Path]:
    if not SRC.is_dir():
        sys.stderr.write(f"ERROR: {SRC} not found.\n")
        sys.exit(2)
    files = [
        p for p in sorted(SRC.iterdir())
        if p.suffix.lower() == ".webp" and not p.name.startswith(EXCLUDE_PREFIX)
    ]
    return files


def _upload_one(
    p: Path,
    base_url: str,
    key: str,
    overwrite: bool,
) -> Outcome:
    object_url = f"{base_url}/storage/v1/object/{BUCKET}/{p.name}"
    data = p.read_bytes()
    req = urllib.request.Request(
        object_url,
        data=data,
        method="POST",
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": "image/webp",
            "Cache-Control": CACHE_CONTROL,
            "x-upsert": "true" if overwrite else "false",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            # 200 OK on first upload; the response body is a small JSON
            # blob with { "Key": "<bucket>/<filename>" }
            body = resp.read().decode("utf-8", errors="replace")[:120]
            return Outcome("OK", p.name, f"{len(data)}B {resp.status} {body}")
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")[:200]
        if e.code == 409 or "already exists" in body.lower():
            return Outcome("COLLIDE", p.name, f"409 {body[:80]}")
        return Outcome("FAIL", p.name, f"{e.code} {body}")
    except urllib.error.URLError as e:
        return Outcome("FAIL", p.name, f"network: {e}")
    except OSError as e:
        return Outcome("FAIL", p.name, f"io: {e}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="List the corpus and skip-set; do not upload anything.",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Send `x-upsert: true`. Use only if you've confirmed via the "
             "precheck SQL that pre-existing slug-named files are intentional "
             "replacements. NOT recommended for the initial migration.",
    )
    parser.add_argument(
        "--parallel",
        type=int,
        default=1,
        help="Concurrent upload count (default 1 sequential). 4 is the safe "
             "ceiling for a typical home uplink.",
    )
    args = parser.parse_args()

    base_url = _env("SUPABASE_URL")
    key = _env("SUPABASE_SERVICE_ROLE_KEY")

    corpus = _list_corpus()
    done = _load_resume_set()
    pending = [p for p in corpus if p.name not in done]

    print(f"corpus:   {len(corpus)} files")
    print(f"done:     {len(done)} (from {RESUME_LOG.name})")
    print(f"pending:  {len(pending)}")
    print(f"bucket:   {BUCKET}")
    print(f"base_url: {base_url}")
    print(f"overwrite: {args.overwrite}")
    if args.dry_run:
        for p in pending[:10]:
            print(f"  WOULD UPLOAD {p.name}")
        if len(pending) > 10:
            print(f"  ... and {len(pending) - 10} more")
        return 0

    if not pending:
        print("Nothing to do. Exiting.")
        return 0

    counts = {"OK": 0, "SKIP": 0, "COLLIDE": 0, "FAIL": 0}

    def _handle(outcome: Outcome) -> None:
        counts[outcome.kind] = counts.get(outcome.kind, 0) + 1
        print(f"{outcome.kind:<7} {outcome.filename:<48} {outcome.detail[:120]}")
        _append_resume(outcome)

    if args.parallel <= 1:
        for p in pending:
            _handle(_upload_one(p, base_url, key, args.overwrite))
    else:
        with ThreadPoolExecutor(max_workers=args.parallel) as ex:
            futures = {
                ex.submit(_upload_one, p, base_url, key, args.overwrite): p
                for p in pending
            }
            for fut in as_completed(futures):
                _handle(fut.result())

    print("---")
    for k in ("OK", "SKIP", "COLLIDE", "FAIL"):
        print(f"  {k}: {counts.get(k, 0)}")
    print("---")
    print(f"resume log: {RESUME_LOG}")

    # Exit non-zero if any FAILs so a CI runner notices.
    return 0 if counts.get("FAIL", 0) == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
