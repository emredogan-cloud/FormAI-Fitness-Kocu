# FormAI — Public-Repository & Final Polish Sprint Report

**Date:** 2026-07-13 · **Repo:** PUBLIC (`emredogan-cloud/FormAI-Fitness-Kocu`) · **Tip:** `8fe1712`
**End state: every GitHub Actions workflow GREEN · repository secret-free (history included) · AI coach production-grade and device-verified.**

---

## Phase 0 — Public-repository security hardening ✅

Going public invalidated the earlier private-repo tradeoff (historical tokens
allowlisted + revocation ledgered). Actions taken:

- **Full audit re-run for public visibility:**
  - `.env` / `.env.local` — **never committed** (verified against all history).
  - No `.jks` / `.p12` / `.pem`(private) / `key.properties` / keystores /
    google-services / firebase configs / service-account JSONs / AWS / Anthropic /
    OpenAI / RevenueCat / OAuth / SSH material tracked **or anywhere in history**.
  - Only `.env.example` ships — a clean template, CI-guarded by
    `tool/check_env_no_secrets.sh`.
- **History rewritten** (`git filter-repo --invert-paths`, authorized "rewrite
  history only if necessary" — it was): purged from **all 392 commits**:
  - `logs.txt` — a committed adb logcat dump holding **real Google/Supabase
    session tokens** (tree-removed in `811aae5` long ago, but blobs survived in
    pre-history; public repo = public tokens).
  - `upload-cert.pem` — a public certificate (0 private lines), purged for hygiene.
  - A full **pre-rewrite backup bundle** (460 MB) was kept locally.
- **Force-pushed** the clean history (`+ 6784dd2...418f8df`).
- **Scanner made strict again:** the `.gitleaks.toml` allowlist for `logs.txt`
  was **removed** — if that file ever reappears, Secret Scan fails loudly.
- **Proof:** the strict gitleaks full-history scan ran in CI on the rewritten
  repo — **SUCCESS, three times in a row** (every post-rewrite push).
- Defense-in-depth remainder (already in `FINAL_FOUNDER_ACTIONS.md`): GitHub can
  cache unreachable commits until gc → revoking the old session tokens and
  optionally asking GitHub Support to run gc remains recommended.

## Phase 1 — Public repository quality ✅

- **README:** title de-branded ("SixPack AI · FormAI" → **"FormAI — Fitness
  Koçu"**), overview explains the internal `sixpack_ai` package name (kept for
  data-migration safety), and a **real legal inconsistency fixed** — the README
  displayed an **MIT badge while `LICENSE` is proprietary** all-rights-reserved
  → badge now says Proprietary.
- **LICENSE:** proprietary, correct and intentional for source-visible
  proprietary code → no CONTRIBUTING invited.
- **.gitignore:** already covers every secret class (verified by the audit).
- **Branches/tags:** exactly one branch (`main`), zero tags, no stale refs.
- Root doc sprawl (36 `.md` reports) noted as cosmetic; left in place —
  they're honest engineering history and reference each other.

## Phase 2 — CI: everything green on the public repo ✅

The billing block (private-repo minutes exhausted) disappeared with public
visibility (free minutes). Final board — **all green:**

| Workflow / run | Result |
|---|---|
| Secret Scan (strict, clean history) — 3 post-rewrite pushes | ✅ ×3 |
| CI push run — README commit (format/analyze/test + debug APK) | ✅ 8m41s |
| CI push run — coach-history commit | ✅ 8m08s |
| **Full `workflow_dispatch` run incl. Integration E2E (Android emulator)** | ✅ 10m37s (emulator job 10m33s) |

No flakes remain: gitleaks runs as the deterministic MIT binary (no license-API
call), the emulator job has the KVM udev rule + ~10 GB disk reclaim (proven on
this green run), and it runs on PRs/manual only so quota can't silently drown
(kept even now — it's just good hygiene).

## Phase 3 — Product improvements ✅

- **Conversation history across restarts** (the one missing premium-chat item):
  the last 30 turns persist to `SharedPreferences` (`sixpack.coach_turns_v1`)
  after every reply and restore on open; corrupt payloads degrade to a fresh
  greeting; timestamps ride along. **Device-verified:** message sent → app
  force-stopped → relaunched → full transcript (greeting 22:13, user 22:14,
  Claude reply 22:14) restored exactly.
- Already shipped in the prior sprints (and re-verified on this build): modern
  bubbles + left/right alignment, animated typing + "Form yazıyor…", typewriter
  streaming effect, timestamps, quick chips, **rich structured replies**
  (emoji-headed bold sections, neon bullets, `**bold**`) rendered by a
  deterministic parser, live Claude behind the secure Edge Function with
  rolling long-term memory (server-side `summarize` → ≤8 durable bullets,
  refreshed every 3 turns, token-minimal), and camera-to-coach context
  (today's real exercise names + last logged session's real reps/duration).
  The new on-device round-trip again produced a context-aware reply
  (referencing the run vs "bugün 6 egzersiz" conflict) — no generic advice.
- Collapsible sections: deliberately skipped — the persona caps replies at 2–3
  short scannable sections, so there is nothing worth collapsing; adding the
  affordance would be decoration.

## Phase 4 — Device pass ✅ (this build)

Release APK (fresh, stale-trap checked) on the Xiaomi: dashboard → coach card →
live LLM chat round-trip ✓ · history persistence kill/relaunch ✓ · timestamps ✓ ·
typing indicator ✓ · rich reply rendering ✓. Broader surfaces (nutrition
freemium both themes, profile, onboarding, camera/pose, light/dark) were
device-verified in the two prior sprints on this same build line; the
device-matrix sweep (tablet + Android 15/16) remains the founder QA item.

## Commits this sprint

| Commit | What |
|---|---|
| `418f8df` | security: purge logs.txt + upload-cert.pem from ALL history; strict gitleaks |
| `57bf4db` | docs(readme): FormAI title; MIT badge → Proprietary |
| `8fe1712` | feat(coach): conversation history survives app restarts |
| *(history)* | all 389 prior commits rewritten by filter-repo (same content, new SHAs) |

## Stop-condition checklist

✔ All commits pushed (`main` = `8fe1712`, tracking restored)
✔ Every GitHub Action green (incl. the full emulator dispatch)
✔ Every build succeeds (CI debug APK, emulator run, local release APK)
✔ Repository secure — strict secret scan green over the **entire rewritten history**
✔ No secrets remain (tracked or historical)
✔ No flaky workflows
✔ AI experience production-grade — live Claude + memory + rich UI + persistent
  history, all verified on a physical device

*Founder follow-ups live in `FINAL_FOUNDER_ACTIONS.md` (token revocation as
defense-in-depth, Anthropic spend cap, persona taste-pass, device-matrix QA).*
