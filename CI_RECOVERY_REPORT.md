# CI Recovery Report

**Branch:** `main` · **HEAD:** `809b1ba`
**Date:** 7 August 2026
**Final status:** ✅ **GREEN — all workflows passing, zero code changes required**

---

## 1. Executive summary

`main` was red, and **the cause was not in the repository.** Every job in both
workflows failed with GitHub's runner-allocation error after waiting 15
minutes for a machine that never arrived:

```
The job was not acquired by Runner of type hosted even after multiple attempts
```

No step ever executed — `gh run view --log-failed` returns nothing at all,
because there were no step logs to return. The commit that "broke" CI
(`809b1ba`) added two documentation files and touched no code.

**The fix was to re-run the workflows.** Both now pass on the identical
commit with no changes of any kind. Nothing was edited, reverted or
refactored.

While confirming this I also established what the *earlier* red runs on this
branch were — a genuine formatting failure, already fixed two commits before
this task began. §5 documents it, because anyone scrolling the Actions
history will see those red marks and deserve an explanation rather than a
mystery.

---

## 2. Root cause

### 2.1 What failed

| Workflow | Run | Jobs | Duration | Result |
| --- | --- | --- | --- | --- |
| CI | `31123073404` | Format-analyze-test · Build APK | 15m 02s each | ❌ |
| Secret Scan | `31123073555` | gitleaks · .env guard | 15m 02s each | ❌ |

### 2.2 The evidence, in the order it was gathered

1. **All four jobs, across two independent workflows, failed at exactly
   15m02s.** Two unrelated workflows failing with an identical duration is
   not a code signature — a real failure varies with what it is doing.
2. **The annotation on every job is GitHub's own infrastructure message**,
   not a build error:
   `The job was not acquired by Runner of type hosted even after multiple attempts`.
   That is emitted when the Actions service cannot allocate a hosted runner
   within its acquisition window.
3. **`gh run view 31123073404 --log-failed` returned zero bytes.** There are
   no failing-step logs because no step ran. The jobs never reached a
   runner, so `Set up job` never happened.
4. **The commit changed no code.**
   `809b1ba` = `PLAY_CONSOLE_PRODUCTION_GUIDE.md` (+978) and
   `PLAY_STORE_ASO_PROMPTS.html` (+1047). 2025 insertions, 0 deletions, no
   `.dart`, no `pubspec.yaml`, no workflow file.
5. **The identical code passed CI twice, immediately before.**
   `db93e22` → CI green in 7m46s. `5fa4883` → CI green in 8m21s. Since
   `809b1ba` only adds documentation on top of `5fa4883`, the compiled
   artifact is byte-for-byte the same tree CI had already accepted.
6. **The re-run passed with no intervention.** Secret Scan finished in 45s;
   CI in 8m47s. Same commit, same code, same workflow files.

### 2.3 Root cause statement

> **A transient GitHub Actions hosted-runner capacity failure.** The jobs
> queued, waited out the runner-acquisition timeout, and were marked failed
> without executing. There was no defect in the code, the tests, the
> generated files, the dependencies, the Flutter version or the workflow
> definitions.

---

## 3. Why it happened

Hosted-runner allocation is a shared, capacity-constrained service. When a
region is saturated, or a queued job's requested label cannot be satisfied
in time, the Actions control plane gives up and fails the job with this
annotation. It is invisible to the repository and unaffected by anything in
it.

Two details make this instance easy to misdiagnose, which is worth recording:

- **It presents as a red X on a commit**, exactly like a real failure. The
  Actions UI does not distinguish "your code is broken" from "we could not
  find you a machine" anywhere except the annotation text.
- **The 15-minute duration looks like a hanging test.** The instinctive
  reading is "something timed out in the suite". It is the *queue* timing
  out, before the suite exists.

The correct diagnostic is cheap and should be the first move next time:
**if `--log-failed` is empty, no step ran, and the problem is not yours.**

---

## 4. What was changed

**Nothing.**

| Category | Change |
| --- | --- |
| Application code | none |
| Tests | none |
| Generated files | none |
| Workflow files | none |
| Dependencies | none |
| Documentation | this report only |

No commit was needed to turn CI green. The only commit in this task is the
one adding `CI_RECOVERY_REPORT.md`.

**Action taken:** `gh run rerun 31123073404` and `gh run rerun 31123073555`.

This was deliberate. The brief said to fix the minimum amount of code
required; here the minimum is zero, and editing working code to "fix" an
infrastructure outage would have introduced real risk to a build that is
already verified and queued for a production release.

---

## 5. The earlier red runs — different cause, already fixed

The Actions history shows two more failures on `main` on 2026-08-06. They
were **real**, they were **not** this problem, and they are **already
resolved**. Recording them so the history is legible:

| Run | Commit | Failing step | Cause |
| --- | --- | --- | --- |
| `31076740063` | `b02b945` | **Verify formatting** | two unformatted files |
| `31077908775` | `883bb13` | **Verify formatting** | same two files |

**Reproduced locally to confirm.** Checking out the `883bb13` tree into a
worktree *with package resolution copied in* (without it the formatter falls
back to a default language version and reports 350 spurious changes — a trap
worth knowing) gives:

```
Changed lib/features/monetization/presentation/paywall_screen.dart
Changed lib/features/onboarding/presentation/onboarding_screen.dart
Formatted 426 files (2 changed)
```

Both files were edited during the production-audit session — the `FORM SKORU`
localisation fix and the What's-New suppression. That session ran
`flutter analyze` and `flutter test` and **did not run `dart format`**. CI
did, and failed correctly.

This is `RESUME_GUIDE.md` gotcha #28 happening again, verbatim: *"Running a
subset of the gates is not running the gates."* CI behaved exactly as
designed; the process around it did not.

It was fixed incidentally in the next session, which ran `dart format .`
before committing `b0ddef7`. Because `b0ddef7`, `fed6b66` and `db93e22` were
pushed together, the first run after the fix was `db93e22` — green, and green
ever since.

---

## 6. Verification performed

### 6.1 Local — full gate set, on the exact HEAD

```
dart format --output=none --set-exit-if-changed .   435 files, 0 changed   exit 0
flutter analyze                                      No issues found        exit 0
flutter test                                         1524 / 1524 passed     exit 0
tool/check_hardcoded_strings.dart                                           exit 0
tool/arb_coverage.dart --strict                                             exit 0
tool/gen_pseudo_localizations.dart --check                                  exit 0
tool/check_directional_layout.dart                                          exit 0
tool/recipe_translation_audit.dart                                          exit 0
```

A release build was **not** run. It is not part of either failing workflow,
and the AAB for `1.0.0+38` was already built and verified during the
production-hardening sprint. Rebuilding would prove nothing about this
failure.

### 6.2 CI — job level, after the re-run

**CI · run `31123073404` — ✅ success**

| Job | Result | Duration |
| --- | --- | --- |
| Format, analyze, and test | ✅ | 6m 30s |
| Build Android APK (debug) | ✅ | 8m 38s |
| Integration E2E (Android emulator) | — skipped | 0s |

The E2E skip is **by design, not a failure**: `ci.yml:166` carries
`if: github.event_name != 'push'`, with a comment explaining that the job
costs ~20 runner-minutes and was exhausting the account's Actions quota. It
runs on pull requests and manual dispatch only.

**Secret Scan · run `31123073555` — ✅ success**

| Job | Result | Duration |
| --- | --- | --- |
| gitleaks (history + tree) | ✅ | 36s |
| .env secret guard | ✅ | 7s |

### 6.3 Branch state

`release.yml` is not triggered by pushes to `main`, so it is not part of the
branch's status. The two workflows that do run on push are both green on
HEAD.

---

## 7. Final GitHub Actions status

```
main @ 809b1ba

  ✅ CI            run 31123073404   success   8m47s
  ✅ Secret Scan   run 31123073555   success     45s
```

**`main` is GREEN.**

---

## 8. Remaining risks

| # | Risk | Severity | Note |
| --- | --- | --- | --- |
| 1 | **Runner allocation can fail again** | Low, recurring | Nothing in the repo can prevent it. If a red run shows the same annotation and empty `--log-failed`, re-run it — do not debug the code. |
| 2 | **Node 20 deprecation warnings** | Medium, dated | Both workflows warn that `actions/checkout@v4` and `actions/setup-java@v4` target Node 20 and are being force-run on Node 24. They pass today. When GitHub removes the shim these steps break. Bumping to `checkout@v5` / `setup-java@v5` is a one-line change per action — **out of scope here**, because touching workflow files while diagnosing a workflow outage is how a simple problem becomes two. |
| 3 | **Local Flutter 3.41.9 vs CI 3.44.8** | Standing | `RESUME_GUIDE.md` gotcha #1. Local green is not proof. §5 is a live example of a gate that only CI ran. |
| 4 | **Push-time CI does not run integration E2E** | Accepted | Deliberate, to protect the Actions minute budget. Integration coverage exists only on PRs and manual dispatch — so a push-only workflow can be green with the emulator suite never executed. |
| 5 | **The formatter must be run before every push** | Process | The §5 failure cost two red runs. `RESUME_GUIDE.md` §4 lists every gate; run all of them, not the ones near the code you changed. |

None of the five blocks the production release.

---

*No application code, tests, generated files or workflow definitions were
modified. The only file added by this task is this report.*
