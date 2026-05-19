# PROJECT_DOCUMENTATION Duplicate Audit — T1.4

> **Branch:** `feature/cdn-meal-migration`
> **Date:** 2026-05-19
> **Action:** Deep-diff of `docs/PROJECT_DOCUMENTATION.md` (English, Phase 58, current) vs `docs/PROJECT_DOCUMENTATION1.md` (Turkish, Phase 39, 2026-04-24).
> **Decision:** ARCHIVE (not delete) — partial unique value confirmed.

---

## 1. Files compared

| File | Lines | Language | Phase | Date | Status |
|---|---:|---|---|---|---|
| `docs/PROJECT_DOCUMENTATION.md` | 1,940 | English | 58 | 2026-04-28 | Current canonical doc |
| `docs/PROJECT_DOCUMENTATION1.md` | 422 | Turkish | 39 | 2026-04-24 | Older PM post-mortem |

Size ratio: the English version is **4.6× larger**. It is not a translation; it is a more granular successor.

---

## 2. Structural comparison

### Sections in TR (older) and not in EN (current) — by *section title*:

```
## 10. Dar Boğazlar ve Ölçeklenebilirlik   (Bottlenecks & Scalability)
###   10.1 Supabase Kapasitesi             (Supabase Capacity)
###   10.2 Client-Side Dar Boğazlar        (Client-side Bottlenecks)
###   10.3 Cold Start
## 11. Kırık / Dummy Butonlar ve Vaat Edilen Özellikler
                                            (Broken / Dummy Buttons & Promised Features)
## 12. Monetizasyon ve RevenueCat Stratejisi
                                            (Monetization & RevenueCat Strategy)
###   12.1 Mevcut Durum (Fallback Mode)
###   12.2 Launch Öncesi Yapılacaklar
###   12.3 Pricing Modeli Önerileri
###   12.4 LTV / CAC Hesabı
## 13. Güvenlik ve QA                      (Security & QA)
###   13.1 Supabase Row-Level Security (RLS)
###   13.2 Veri Hijyeni
###   13.3 Crash Reporting / Observability
###   13.4 QA Otomasyonu
###   13.5 Secret Yönetimi
```

### How those sections are covered today

| Turkish (TR) section | Covered in… | Source |
|---|---|---|
| §10 Bottlenecks & Scalability | partial (architecture sections of EN; observability comments in code) | EN §2.x |
| §11 Broken Buttons audit | indirectly (phase reports cover the *fixes* but not the original audit list) | reports/archive/phase98_black_screen_root_cause.md and similar |
| §12 Monetization Strategy | **`docs/MONETIZATION_LAUNCH_GUIDE.md`** | dedicated doc |
| §13 Security & QA | partial (RLS in `supabase/migrations/`; QA in operator runbooks) | `docs/OPERATOR_REVIEWER_ACCESS.md` + RLS migrations |

**Partial unique value:** §11 (the broken-buttons / promised-features audit) and §10 (the original capacity-bottleneck assumptions for ~10k+ MAU) **are not duplicated in any current doc**. They captured specific Phase-39 product/PM observations that informed later work but were never re-stated.

---

## 3. References in the current English doc

The current `docs/PROJECT_DOCUMENTATION.md` **explicitly cites the Turkish version 9 times**, drawing facts from it:

```
Line  56: Section 7.3   — user demographic data
Line 1097: Section 1    — tech stack motivation
Line 1570: §10.1        — Supabase capacity threshold (~10k+ MAU)
Line 1580: §1.1         — stack rationale
Line 1680: §3           — directory structure original
Line 1711: §5.3         — onboarding funnel estimate (30%+ from 13→9 trim)
Line 1722: PM post-mortem framing
Line 1728: §4 / §9 / §10 — checklist citations
```

The English doc **treats the Turkish doc as a source-of-truth for specific facts**. Removing the Turkish doc would orphan 9 citations.

---

## 4. Decision per the user's rule

> **IF fully obsolete:** delete
> **ELSE IF partial unique value:** archive or merge
> **ELSE:** keep

This is the **ELSE IF** path. Specifically:

- §11 (Broken Buttons / Promised Features) is **unique content not in any other doc**.
- §10 (Scalability assumptions) is referenced by the English doc but is also the most-cited source.
- §12 / §13 are largely superseded by `MONETIZATION_LAUNCH_GUIDE.md` and the operator runbook, but the older versions remain useful as a "Phase 39 snapshot of what we thought".

**Action: archive, do not delete.**

---

## 5. What was done

```bash
$ git mv docs/PROJECT_DOCUMENTATION1.md \
         docs/archive/old-doc-snapshots/PROJECT_DOCUMENTATION_TR_phase39.md
```

The file is renamed in the move to clarify its provenance:

| Old path | New path |
|---|---|
| `docs/PROJECT_DOCUMENTATION1.md` (cryptic "1" suffix) | `docs/archive/old-doc-snapshots/PROJECT_DOCUMENTATION_TR_phase39.md` (language + phase label explicit) |

### Cross-references updated

All 9 references in `docs/PROJECT_DOCUMENTATION.md` updated:

```diff
- (per `PROJECT_DOCUMENTATION1.md` Section 7.3)
+ (per `archive/old-doc-snapshots/PROJECT_DOCUMENTATION_TR_phase39.md` Section 7.3)

  …and 8 similar replacements.

- ├── PROJECT_DOCUMENTATION1.md            # Phase 39 (2026-04-24) PM post-mortem (Turkish)
+ ├── docs/archive/old-doc-snapshots/PROJECT_DOCUMENTATION_TR_phase39.md   # Phase 39 (2026-04-24) PM post-mortem (Turkish), archived 2026-05-19
```

Result: **zero orphan references**, **zero knowledge loss**, **clearer file naming**, **non-active doc out of the active `docs/` surface**.

---

## 6. Verification

```
$ grep -n "PROJECT_DOCUMENTATION1" docs/PROJECT_DOCUMENTATION.md
(no output — clean)

$ ls docs/archive/old-doc-snapshots/
PROJECT_DOCUMENTATION_TR_phase39.md

$ ls docs/PROJECT_DOCUMENTATION1.md
(file does not exist — moved)

$ git status | grep PROJECT_DOC
renamed:    docs/PROJECT_DOCUMENTATION1.md -> docs/archive/old-doc-snapshots/PROJECT_DOCUMENTATION_TR_phase39.md
modified:   docs/PROJECT_DOCUMENTATION.md
```

All clean.

---

## 7. Status

**APPLIED.** PROJECT_DOCUMENTATION1.md is archived (not deleted), references updated, knowledge preserved. T1.4 complete.
