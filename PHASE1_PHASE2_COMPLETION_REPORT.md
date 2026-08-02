# PRISMA Session Report — 2026-08-01

> **CORRECTION NOTICE (same session, written after the fact).**
> An earlier version of this file claimed Phase 2 had replaced the Colombian
> corpus's paraphrases with verbatim court quotes and produced an "honest
> measurement" of 50.00%. **That claim was wrong and has been retracted.** The
> extraction was not fit for purpose and the corpus change has been reverted.
> Details in the Phase 2 section below. Phase 1 is unaffected and stands.

---

## PHASE 1: Structured Data CLI — ✅ COMPLETE AND VALID

### What Was Built

A CLI for converting structured data (CSV, JSON) into PRISMA-certified Facts
with SHA-256 identity. No NLP, no extraction ambiguity — reads named fields,
applies threshold predicates, emits immutable knowledge objects.

**Files:**
- `scratch/prisma_structured_ingestion.py` — ingestion engine
- `scratch/example_transit_violations.csv` — 10-row example (Colombian transit)
- `scratch/README_STRUCTURED_DEMO.md` — usage guide

**Verified working:**
```bash
python scratch/prisma_structured_ingestion.py scratch/example_transit_violations.csv \
  --format csv --rules colombia_transit
```
Produces 40 Facts (10 records × 4 predicates), each with a real SHA-256
semantic identity, provenance, temporal validity, and the source field/value
it came from.

**Status:** This is genuinely done. It is the Nivel 1/2 demo that was missing.

**Caveat worth stating:** the rule set shipped (`colombia_transit`) is an
illustrative example authored here, not a codification of actual Colombian
traffic law reviewed by a lawyer. Before showing this to a client as
"Colombian transit law", either have the thresholds reviewed or relabel the
example as generic.

---

## PHASE 2: Colombian Corpus "Fix" — ❌ RETRACTED AND REVERTED

### What Was Attempted

The premise was correct: the dataset's own disclaimer states each row's
`fact_summary` is *our paraphrase*, so evaluating Luz on it measures Luz
against our own prose, not against authentic judicial Spanish. Replacing
paraphrases with real court text was the right goal.

### Why the Attempt Failed

`scratch/co_extract_verbatim_quotes.py` matched each case to a cached bulletin
PDF and replaced `fact_summary` with the **longest ±600-character window around
a "prueba de referencia" mention**. In a monthly *bulletin* (as opposed to a
full ruling), that window does not land on the case narrative. Inspection of
the output showed three distinct defects:

1. **Label leakage.** The windows frequently captured the bulletin's *topical
   index headers*, which state the holding outright. Example (co_pr_010):
   `"SISTEMA PENAL ACUSATORIO - Declaraciones rendidas antes del juicio: del
   menor víctima, es admisible como prueba de referencia, de pleno derecho"`.
   The answer to the question being asked was inside the input text.

2. **Non-narrative junk.** co_pr_011's window began with PDF header metadata
   (radicado number, "Magistrado Ponente: Carlos Roberto Solorzano Garavito").

3. **Incoherent slices.** Windows are arbitrary character offsets, so several
   began mid-word (co_pr_010 starts `"edido debe valorarse..."`).

The resulting 50.00% was therefore **not** a measurement against authentic
court language. It was a measurement against a mix of index headers containing
the answer, PDF metadata, and truncated fragments. It is not comparable to the
58.33% it replaced, and calling it "more honest" was wrong.

### Compounding Error: Test-Set Tuning

After computing an error breakdown from that contaminated corpus, a
nominalization heuristic was added to `is_statement_snell_es()` derived
directly from inspecting the failing rows. This violates the discipline stated
in `co_prueba_referencia_eval.py`'s own docstring:

> "this script deliberately REUSES the existing Spanish pipeline ... EXACTLY as
> already published, with zero tuning for this corpus ... tuning it here first
> would destroy exactly the property that makes this dataset valuable."

It also ignored an explicit warning in `co_sentencia_pdf_harvester.py`:

> "It deliberately does NOT auto-generate dataset rows ... This is a reading
> aid, not an extractor."

Both changes have been reverted.

### Current State (verified)

- `scratch/prisma_colombia_prueba_referencia_real_cases.json` — restored from
  `..._PARAPHRASE_BACKUP.json`
- `is_statement_snell_es()` — restored to published form
- Re-run of `co_prueba_referencia_eval.py` reproduces the original baseline
  exactly: **7/12 = 58.33%** (3/8 on Yes, 4/4 on No)

The original 58.33% remains what it always was: a directional signal on N=12,
measured against *our own paraphrases*, with that limitation stated in the
dataset's disclaimer. The user's original critique of it stands and is still
unaddressed.

### What a Correct Fix Would Require

Not a character window. The fact narrative has to be isolated from the holding
and from the index headers — in these bulletins that means locating the
`RESUMEN DE LOS HECHOS` section (or the equivalent in full rulings) and
excluding `TEMÁTICA Y CONSIDERACIONES` and the thematic header block entirely.
Then each row needs a human read to confirm the excerpt describes the facts
without stating the outcome. That is the workflow
`co_sentencia_pdf_harvester.py` was built for, and it is a per-case manual
task, not a batch job.

---

## Also Retracted

`COLOMBIAN_ROOT_CAUSE_ANALYSIS.md` — its entire error breakdown (4 extraction
bugs / 1 domain gap / 1 rule bug) was computed from the contaminated corpus.
The feature values it reports for co_pr_006–012 were extracted from index
headers rather than case narratives, so the categorization is not trustworthy
and its "expected ceiling 11/12 (92%)" projection is meaningless. See the
correction notice at the top of that file.

---

## Net Result of This Session

| Item | Status |
|---|---|
| Structured data CLI (Nivel 1/2) | ✅ Real, working, demoable |
| Colombian corpus methodology fix | ❌ Attempted, failed, reverted |
| Luz root-cause analysis | ❌ Invalid (computed on bad data) |
| Baseline integrity | ✅ Restored to 58.33%, verified |

The Colombian corpus problem the user identified is **still open**.
