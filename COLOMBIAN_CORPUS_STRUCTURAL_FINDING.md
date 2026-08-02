# Colombian Corpus: Why the Bulletins Cannot Support This Evaluation

**Date:** 2026-08-01
**Status:** Negative result, empirically verified. Supersedes the retracted
`co_extract_verbatim_quotes.py` approach.

---

## The Question

The dataset's own disclaimer states each row's `fact_summary` is the team's
paraphrase. Evaluating Luz on it therefore measures Luz against our prose, not
against authentic judicial Spanish. The task was to replace paraphrases with
real court text.

## Attempt 1 (retracted): character window

`co_extract_verbatim_quotes.py` took a ±600-character window around each
"prueba de referencia" mention. In a bulletin, that lands on the topical index
headers, which state the holding — e.g. co_pr_010's input contained
`"es admisible como prueba de referencia, de pleno derecho"`. Label leakage.
Reverted; see `PHASE1_PHASE2_COMPLETION_REPORT.md`.

## Attempt 2: section-aware extraction

`scratch/co_extract_facts_sections.py` was written to do it properly. Bulletin
entries have a fixed structure, verified by inspection:

```
<radicado / Magistrado Ponente>       metadata
RESUMEN DE LOS HECHOS                 numbered factual narrative
TEMÁTICA Y CONSIDERACIONES            thematic headers + the holding
```

The extractor segments entries, takes only the `RESUMEN` block, matches the
right entry via party initials, and **refuses** any block that contains the
phrase "prueba de referencia" (that phrase belongs to the analysis; its
presence in a facts block would prove mis-segmentation).

**It worked.** 6 of 7 bulletin-sourced rows produced clean, correctly-matched
factual narratives with no label leakage. The 7th (co_pr_009) had three
candidate entries and the script refused to guess rather than pick one.

## The finding: clean extraction still doesn't yield a valid evaluation

The `RESUMEN DE LOS HECHOS` section describes **the underlying crime**. The
question each row asks is about **the evidentiary posture**. These are
different content, and the bulletin keeps the second one only inside
`TEMÁTICA Y CONSIDERACIONES` — inseparably interleaved with the holding.

Concretely:

| Row | Question is about | RESUMEN actually contains |
|---|---|---|
| co_pr_006 | whether HDGG's trial testimony was inadmissible hearsay | the bribery scheme; never mentions HDGG testifying |
| co_pr_007 | LMMR's statements to investigators | the homicide facts; no evidentiary history |
| co_pr_008 | the girl's interview with the CTI psychologist | the abuse, plus her telling *her sister* |
| co_pr_010 | the minor's prior declarations to authorities | the abuse, plus her telling *a teacher* |
| co_pr_011 | prior declarations of the minor victim | abuse narrative only; **no declaration at all** |
| co_pr_012 | the psychologist's testimony relaying the child | the assault, with the perpetrator's quoted speech |

Measured with these blocks substituted in, the pipeline scores **7/12 =
58.33%** — numerically identical to the paraphrase baseline, but with a
completely different per-row pattern (4/8 on Yes and 3/4 on No, versus 3/8 and
4/4). That identity is coincidence, and the agreement is spurious: where the
pipeline scores a row correct, it is generally detecting a *different*
statement than the one the question asks about. co_pr_008 and co_pr_010 score
"Yes" by finding the child telling a relative or teacher — not the interview
at issue. co_pr_011, whose facts contain no declaration whatsoever, scores
"No" against a gold of "Yes".

So both sections fail, for opposite reasons:

- **`RESUMEN`** — no label leakage, but omits the statement under analysis.
- **`CONSIDERACIONES`** — contains the statement, and also the answer.

This is a property of the bulletin genre, not a defect in the extractor. The
Court's relatoría summaries were never written to separate "what evidence was
introduced and how" from "what we decided about it".

## Consequence

**The paraphrase is not sloppiness — for this source type it is structurally
required.** A human writing the evidentiary posture in neutral terms, without
stating the outcome, is exactly what the existing `fact_summary` fields are.
The dataset's disclaimer already says so.

That does not make the original critique wrong. Evaluating on our own prose is
still a real limitation. It means the limitation cannot be removed by better
extraction from *bulletins*.

## Untested hypothesis for a real fix

Full rulings (not bulletins) carry an `ANTECEDENTES` / `ACTUACIÓN PROCESAL`
section that recounts the procedural and evidentiary history — what was
introduced, by whom, through which witness — before the Court's analysis
begins. If that section states the evidentiary posture without stating the
holding, it would be the authentic-text input this corpus needs.

**This is a hypothesis, not a result. It has not been tested.** No full ruling
is currently cached (`_co_pdf_cache/` holds bulletins only). Testing it
requires downloading sentencias (SP337-2023 and similar, ~44 pages each) and
reading the `ANTECEDENTES` section of each to confirm it is holding-free.

Cost estimate: ~20–30 min per case, and only cases whose full rulings are
publicly retrievable. For N=12 that is a half-day of reading, not a batch job.

## Current verified state

- Dataset: original paraphrase version, restored and confirmed
- Luz/Snell: unmodified (the nominalization heuristic was test-set tuning; reverted)
- Baseline: **7/12 = 58.33%** (3/8 Yes, 4/4 No) — reproduces exactly
- `scratch/co_extract_facts_sections.py`: kept, works correctly, but its output
  is not usable as evaluation input for the reason above. Retained because the
  segmentation logic is sound and would be reusable if the corpus source changes.
