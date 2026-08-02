# PRISMA Future Sessions Roadmap — 2-3 Next Messages

**Status:** Phase 1/2 complete (2026-08-01). Ready to pick next sprint.

---

## Option A: Polish & Ship Nivel 1/2 Demo (1-1.5 hours)

**Goal:** Make the CSV→Facts CLI into a click-away demo for stakeholders.

### Tasks
1. **Wrapper script:** Create `run_demo.sh` (or `.bat` for Windows) that:
   - Checks dependencies (PyMuPDF, prisma_core in path)
   - Runs example on example_transit_violations.csv
   - Opens results.json in browser or text editor
   - **Result:** `./run_demo.sh` → see 10 drivers → 40 certified Facts in 15 seconds

2. **Web UI mockup (optional, but high-value):**
   - Simple HTML form: drag-drop CSV → click "Certify" → download JSON
   - No backend needed; JavaScript calls CLI locally (or render results if you want to show output)
   - **Why:** Looks more like a product than a CLI
   - **Time:** 45 min for basic version (file input, results display, SHA-256 highlight)

3. **Domain rule templates (optional):**
   - Add 2-3 more rule sets to `prisma_structured_ingestion.py`:
     - `insurance_underwriting` (age + risk factors → coverage tier)
     - `compliance_audit` (field thresholds vs. regulatory limits)
   - Include example CSVs for each
   - **Why:** Shows domain portability

### Deliverable
- Stakeholders can run ONE command and see structured data → SHA-256 facts
- Proof that Nivel 1/2 is production-ready
- **Fit for:** investor demo, internal "this is what we ship first" milestone

---

## Option B: Fix Colombian Corpus Balance (1.5-2 hours)

**Goal:** Get to 10 Yes / 10 No for statistical validity (currently 8 Yes / 4 No, N=12).

### Context
- Cases 1-5: PDFs not in cache (were downloaded from external URLs)
- Cases 6-12: Already fixed with verbatim quotes from boletines
- To reach 10/10: need to harvest more "No" rulings (structurally rarer in this corpus)

### Tasks
1. **Identify candidate "No" cases:**
   - Search Colombian court index for rulings mentioning "prueba de referencia" + "rechaza" / "inadmisible"
   - Target: 6 more "No" cases to reach 10 No total
   - Use `scratch/co_sentencia_pdf_harvester.py` (already built)

2. **Download & extract:**
   - For each candidate, run harvester to pull verbatim passages
   - Hand-curate gold labels (read the ruling, confirm what the Court actually decided)
   - Add to `prisma_colombia_prueba_referencia_real_cases.json`

3. **Re-evaluate:**
   - Run `scratch/co_prueba_referencia_eval.py`
   - Update report with new N=20 baseline (both stats and caveats)

4. **Document:**
   - Methodological note: why "No" cases are rarer (Court writes about prueba de referencia mostly to ADMIT it or spell its requirements, not to deny it)
   - This is a feature of the legal domain, not an error

### Deliverable
- N=20 dataset (10 Yes / 10 No) suitable for cross-validation
- Honest baseline on real Spanish court text (likely 45-55% range)
- **Fit for:** establishing credible Luz/Snell evaluation benchmark

---

## Option C: Luz Extraction Diagnostics & Tuning (2-2.5 hours)

**Goal:** Understand where Luz/Snell is losing accuracy on Spanish court text.

### Context
- Current: 50% on Colombian real text (6/12)
- English Snell: 74.47% on LegalBench (real, large N)
- Gap is real; need to diagnose root cause (extraction, interpretation, rule application, or corpus difficulty)

### Tasks
1. **Detailed error analysis:**
   - For each of 6 misclassifications, run Snell in debug mode:
     - What assertions did it extract?
     - Were they correct?
     - Did the engine infer wrong from correct assertions?
     - Or was the extraction itself faulty?
   - Output: CSV with `case_id | extracted_assertions | snell_output | engine_output | gold_label | miss_type`

2. **Categorize failures:**
   - **Extraction bug:** Snell extracted wrong → fix Snell
   - **Rule application bug:** Engine got correct assertions but inferred wrong → fix rule or check antecedent satisfaction
   - **Semantic gap:** Snell extracted plausible but slightly off interpretation of court language → document as "Spanish legal domain requires X" and revisit

3. **Targeted fix (if obvious):**
   - If one bug dominates, fix it and re-evaluate
   - If scattered, document the landscape for future prioritization

### Deliverable
- Root-cause breakdown of 50% accuracy
- Clear prioritization: which fixes would have highest ROI
- **Fit for:** roadmap item "why is Spanish harder than English?"

---

## Quick Decision Grid

| Option | Time | Impact | Risk | Best For |
|--------|------|--------|------|----------|
| **A** (Polish + Ship) | 1-1.5h | High visibility | Low | Showing stakeholders something works NOW |
| **B** (Corpus Balance) | 1.5-2h | Credibility | Low | Establishing a real benchmark |
| **C** (Diagnostics) | 2-2.5h | Future direction | Medium | Understanding the gap, long-term R&D |

---

## Recommendation Sequence (if doing multiple sessions)

1. **Session 1 (if busy):** Option A — 30 min wrapper + 15 min demo = instant showable progress
2. **Session 2:** Option B — Balance corpus to N=20 (can run partially in parallel with Session 1)
3. **Session 3:** Option C — Diagnostics (informed by B's real results)

Or **Session 1 (all-in):** A + B together (2.5-3h), then C later.

---

## Commands to Start Each Option

### Option A
```bash
cd scratch
python prisma_structured_ingestion.py example_transit_violations.csv --format csv --rules colombia_transit
# Then: Optional web UI mockup in new file (demo.html)
```

### Option B
```bash
# Identify candidate cases in Colombian court index (manual step)
# Then for each:
python scratch/co_sentencia_pdf_harvester.py <url-or-local-pdf> --context 700
# Hand-curate and add to prisma_colombia_prueba_referencia_real_cases.json
# Then:
cd scratch && python co_prueba_referencia_eval.py
```

### Option C
```bash
# Add debug mode to prisma_spanish_hearsay_eval.py or co_prueba_referencia_eval.py
# Output detailed extraction trace for each case
# Analyze misclassifications
```

---

## Files to Know

**Nivel 1/2 (Structured):**
- `scratch/prisma_structured_ingestion.py` — Main engine
- `scratch/example_transit_violations.csv` — Example data
- `scratch/README_STRUCTURED_DEMO.md` — User guide

**Spanish/Colombian (Luz/Snell):**
- `scratch/co_prueba_referencia_eval.py` — Evaluation script
- `scratch/prisma_colombia_prueba_referencia_real_cases.json` — Dataset
- `scratch/co_extract_verbatim_quotes.py` — PDF harvester
- `scratch/prisma_spanish_hearsay_eval.py` — Parallel Spanish pilot

**Reports:**
- `PHASE1_PHASE2_COMPLETION_REPORT.md` — What just finished
- `reports/PRISMA_LUZ_SPANISH_PILOT_REPORT.md` — Current Spanish baseline (to update)

---

## Important Reminders

- **Nivel 1/2 is done and vendible** — Don't over-engineer it
- **Colombian corpus now has real measurements** — Pace the expansion (10 more cases = 2-3 hours of careful reading)
- **Luz diagnostics matter for roadmap** — But don't rewrite the whole pipeline; identify the weak spot first
- **Document every measurement** — See `docs/VERIFICATION_STANDARDS.md` for the honesty standard

---

**Pick one, message me which, and I'll dive in.**
