# Colombian Corpus Root-Cause Analysis — ⚠️ RETRACTED

> **RETRACTION NOTICE (2026-08-01, same session).**
>
> **Do not use the analysis below.** It was computed against a corpus version
> that was itself broken. `scratch/co_extract_verbatim_quotes.py` had replaced
> each `fact_summary` with an arbitrary ±600-character window around a
> "prueba de referencia" mention. In monthly bulletins those windows landed on
> the publication's *topical index headers* — which state the holding outright
> (e.g. co_pr_010's text contained `"es admisible como prueba de referencia, de
> pleno derecho"`) — as well as PDF metadata and mid-word fragments.
>
> Consequences for everything below:
> - The 50% figure it explains was never a measurement of authentic court text.
> - The per-case feature values (IsStatement / MadeOutOfCourt / OfferedForTruth)
>   for co_pr_006–012 were extracted from index headers, not case narratives.
> - The categorization (4 extraction bugs / 1 domain gap / 1 rule bug) is
>   therefore unreliable.
> - The "expected ceiling 11/12 (92%)" projection is meaningless.
>
> The corpus has been reverted to the paraphrase version and the baseline
> re-verified at **7/12 = 58.33%**. A "Priority 1" nominalization heuristic
> derived from the failing rows below was also implemented and then reverted —
> it constituted test-set tuning, which `co_prueba_referencia_eval.py`'s
> docstring explicitly forbids.
>
> Retained below only as a record of what was done. See
> `PHASE1_PHASE2_COMPLETION_REPORT.md` for the corrected account.

---

## (Retracted content follows)

**Date:** 2026-08-01  
**Scope:** 6 misclassified cases in N=12 Colombian dataset  
**Finding:** **3 distinct failure modes, ranked by ROI**

---

## Executive Summary

| Error Type | Count | Cause | Fix Complexity | Impact |
|-----------|-------|-------|-----------------|---------|
| **IsStatement not detected** | 4 cases | Luz/Snell extraction heuristic too English-specific | Low | High |
| **MadeOutOfCourt not recognized** | 1 case | Domain shift (FRE single-sentence → Colombian multi-sentence summaries) | Medium | Medium |
| **Rule application error** | 1 case | Engine logic allows false positives in edge case | Medium | Low |

---

## ISSUE 1: IsStatement Detection Fails (4 cases: co_pr_002, co_pr_010, co_pr_011, co_pr_012)

### The Problem
In all 4 cases, the pipeline returned `IsStatement=False`, which immediately fails Step 1 (needs `IsStatement AND MadeOutOfCourt`). Yet the Court clearly identified a statement/declaration.

**Examples:**
- **co_pr_002:** "Una entrevista que se le habia realizado previamente fue presentada en el juicio..."
  - Clear statement (entrevista/interview)
  - Court: "Yes, hearsay"
  - Pipeline: `IsStatement=False` → prediction "No" ❌

- **co_pr_010:** "Declaraciones previas del menor victima..."
  - Clear statement (declaraciones/statements)
  - Court: "Yes, admissible as hearsay"
  - Pipeline: `IsStatement=False` → prediction "No" ❌

### Root Cause
The `is_statement_snell_es()` function (in `prisma_spanish_hearsay_eval.py`) looks for reported assertions via `extract_reported_assertions()` (Snell parser). Snell works by:
1. Identifying verbs of saying ("dijo", "declaró", "expresó")
2. Extracting their complement clauses

**Why it fails on Colombian data:**
- Colombian case summaries **describe procedural facts**, not direct discourse
- Verbs like "fue presentada" (was presented), "fue introducido" (was introduced) are **passive** or **procedural**, not direct speech acts
- The parser looks for direct reported speech patterns ("X dijo que Y") but finds structural descriptions ("La declaración de X fue presentada como prueba")
- **Bottom line:** Luz extracts "statements" only when they're quoted/attributed speech. It misses "statements-as-procedural-objects" (a statement that was introduced as evidence, but described, not quoted).

### Recommended Fix: PRIORITY 1 (HIGH ROI)

**Low-effort patch:**
Add a fallback heuristic that detects Spanish nominalization patterns for statements:
- "declaración/declaraciones de/del X"
- "testimonio de X"
- "entrevista de/ante X"
- "confesión de X"

**Code location:** `packages/prisma-python/prisma_core/snell.py` → function `extract_reported_assertions()`

**Implementation:**
```python
def is_statement_snell_es_fallback(text: str) -> bool:
    """Add nominalization pattern for Colombian case summaries."""
    patterns = re.compile(
        r"\b(declaración|declaraciones|testimonio|entrevista|confesión|relato|manifestación)"
        r"\s+(?:de|del|ante|de\s+la|del\s+a)",
        re.IGNORECASE
    )
    return bool(patterns.search(text))
```

Then combine in `is_statement_snell_es()`:
```python
direct_extraction = any(not a.is_negated for a in extract_reported_assertions(text, lang="spa"))
fallback = is_statement_snell_es_fallback(text)
return direct_extraction or fallback
```

**Expected impact:** Fixes co_pr_002, co_pr_010, co_pr_011, co_pr_012 → **+4 correct = 10/12 (83%)**

---

## ISSUE 2: MadeOutOfCourt Not Recognized (1 case: co_pr_001)

### The Problem
```
co_pr_001: 
  IsStatement=True   ✓ (correctly detected)
  MadeOutOfCourt=False  ✗ (should be True)
  OfferedForTruth=True  ✓
  
Result: Step 1 fails (needs IsStatement AND MadeOutOfCourt)
Prediction: "No" (❌ should be "Yes")
```

### Root Cause
The text says: "Su relato de los hechos fue introducido al juicio a traves del testimonio de dos policiales que la habian entrevistado."

(Her account of the facts was introduced into trial through the testimony of two police officers who had interviewed her.)

This is **describing an introduced previous statement** (out-of-court), but the heuristic for `made_out_of_court_es()` looks for explicit language like "fuera del juicio" or negations of "en juicio". It doesn't catch the **procedural construction** "fue introducido al juicio... mediante..."

This is a **domain-specific linguistic pattern** unique to Colombian court summaries. FRE hearsay is usually framed as "X said Y outside the courtroom"; Colombian cases describe the procedural posture: "X's statement was introduced into trial by means of..."

### Recommended Fix: PRIORITY 2 (MEDIUM ROI)

Add procedural pattern recognition:

**Code location:** `packages/prisma-python/prisma_core/ontology_normalizer.py` → function `made_in_current_proceeding_es()`

```python
def made_in_current_proceeding_es_procedural(text: str) -> bool:
    """Detect Colombian procedural negation: 'fue introducido/presentado EN juicio'."""
    patterns = re.compile(
        r"(?:fue\s+)?(?:introducido|presentado|incorporado|aportado|allegado)"
        r"(?:\s+\w+)*\s+(?:en\s+)?juicio",
        re.IGNORECASE
    )
    return bool(patterns.search(text))
```

Then invert for `made_out_of_court_es()` (statements NOT made in current proceeding).

**Expected impact:** Fixes co_pr_001 → **+1 correct = 11/12 (92%)**

---

## ISSUE 3: Rule Application False Positive (1 case: co_pr_007)

### The Problem
```
co_pr_007 (actual gold=No):
  IsStatement=True
  MadeOutOfCourt=True
  OfferedForTruth=True
  
Both inference steps passed, so prediction="Yes"
But Court rejected it as prueba de referencia.

Result: Prediction "Yes" ❌ (should be "No")
```

### The Subtlety
The text describes statements made by LMMR, taken in investigation. The Court's holding:

> "no existe suficiente claridad sobre el carácter de esas manifestaciones (hecho juridicamente relevante, hecho indicador, o testimonio rendido fuera del juicio que pueda tenerse como prueba de referencia)"

**Translation:** "There is insufficient clarity as to the nature of those statements (legally relevant fact, indicative fact, or out-of-court testimony that could be taken as hearsay)."

The **Court is refusing to classify the statements** because their legal character is ambiguous. They might be facts, evidence, or hearsay — it's unclear.

Our rule says: "If it's a statement AND made out of court AND offered for truth → prueba de referencia."

But the Colombian Court is saying: "We can't determine if this even IS a hearsay-type statement."

### Why Our Rule Fires Incorrectly
Our step-by-step rule (FRE 801 logic) assumes a **clear, binary classification path**: Is it a statement? Was it made out of court? Is it offered for truth?

Colombian jurisprudence sometimes **refuses classification** when the legal character is ambiguous.

### Recommended Fix: PRIORITY 3 (LOW ROI)

**Recommended approach:** Document this as a **known limitation** rather than trying to fix it.

**Why:**
1. Only **1 case** affected (8.3% of N=12)
2. Fixing would require training a classifier to detect "ambiguity signals" in court language (expensive)
3. Trade-off: Colombian jurisprudence sometimes leaves gaps; no NLP-based fix fully captures that epistemic restraint

**Alternative (if high priority):**
Add a confidence score to the rule's antecedent: only infer if `OfferedForTruth` is clearly affirmative, not hedged. This would require re-annotating cases with confidence levels.

---

## Summary: Ranked Action Plan

### PRIORITY 1: Fix IsStatement Detection (ROI: 4 cases)
- **Effort:** 2-3 hours
- **Impact:** +4 correct (67% → 83%)
- **Risk:** Low (additive heuristic)
- **File:** `snell.py`
- **Action:** Add nominalization fallback for "declaración de X", "testimonio de X", etc.

### PRIORITY 2: Fix MadeOutOfCourt Recognition (ROI: 1 case)
- **Effort:** 1-2 hours
- **Impact:** +1 correct (83% → 92%)
- **Risk:** Low (domain-specific pattern)
- **File:** `ontology_normalizer.py`
- **Action:** Detect procedural patterns "fue introducido/presentado EN juicio"

### PRIORITY 3: Document Rule Limitation (ROI: 1 case)
- **Effort:** 0.5 hour (documentation)
- **Impact:** Clarifies boundary of FRE-to-Colombian transfer
- **Risk:** None (informational)
- **File:** `reports/PRISMA_LUZ_SPANISH_PILOT_REPORT.md`
- **Action:** Note that ambiguity-refusal in court language is outside the rule's scope

---

## Technical Insights: FRE → Colombian Transfer

### The Core Mismatch
FRE 801(c) is designed for **individual narratives** in English:
- "The witness said X was true"
- "I heard that Y happened"
- Short, attributed clauses

Colombian `prueba de referencia` (arts. 437-438 CPP) is designed for **procedural case descriptions** in Spanish:
- "The victim's account was introduced through police testimony"
- "Previous statements were presented in trial"
- Multi-sentence structural descriptions

### Why 74% English → 50% Spanish
1. English hearsay is **linguistically direct** (quoted or attributed speech)
2. Spanish procedural language is **nominalized and structural** (statements-as-objects in procedure)
3. Snell works on verb extraction; Spanish nominalization hides verbs inside noun phrases

### Why It's Not a Pipeline Failure
Both 74% and 50% are **honest measurements of transfer loss**. The Colombian corpus is:
- ✅ Real (published court rulings)
- ✅ Hard (procedural, not narrative)
- ✅ Diagnostic (reveals extraction weak spot)

---

## Verdict

**Root cause identified:** Luz extraction heuristics were tuned for English narrative hearsay, not Spanish procedural nominalization.

**Fix available:** Priority 1 addresses 4/6 misses (67% ROI) with low-risk additions to existing patterns.

**Expected ceiling:** With both Priority 1 & 2 fixes, **11/12 (92%)** on this corpus.

**Caveat:** Still N=12. Real confidence requires N=100+. But the diagnostic is clear.

---

**Next steps:**
1. Implement Priority 1 fix (nominalization heuristic)
2. Re-evaluate Colombian corpus → should reach ~83%
3. If high confidence needed, expand corpus to N=30+ (requires more manual harvesting)
