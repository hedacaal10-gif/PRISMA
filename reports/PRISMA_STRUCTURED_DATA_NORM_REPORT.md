# PRISMA — Structured-Data Ingestion & Reusable "Norm" Modules (Nivel 1 + Nivel 2)

**Status:** Nivel 1 complete. Nivel 2 (basic version) complete. Nivel 3 deferred (see §4).
**Scope:** All code in this track lives under `scratch/` (gitignored, prototype-only) except where noted. Nothing here touches `packages/prisma-python/prisma_core/snell.py`, `ontology_normalizer.py`, or any file covered by the pytest/npm regression suites — verified by running the full guard after each step (§3).

---

## 1. Motivation

Luz's free-text extraction (Snell) is the hard, low-accuracy-ceiling case. Structured documents — CSV exports, JSON API responses, XML feeds, filled PDF forms with named AcroForm fields — are a fundamentally easier ingestion path: field names and types are already known, so mapping to certified `Fact`s is a deterministic threshold/comparison problem, not an NLP problem. This track proves that pipeline end-to-end and demonstrates it generalizes across formats and across new data without re-coding.

## 2. Nivel 1 — Format-agnostic adapter (CSV / JSON / XML / PDF forms)

- `scratch/structured_facts_adapter.py`: generic `read_csv_records()`, `read_json_records()`, `read_xml_records(path, record_tag)`, `read_pdf_form_fields(path)` (via `fitz`/PyMuPDF), plus `ThresholdRule` + `apply_threshold_rules()`.
- `scratch/demo_equipment_sensor_monitoring.py`: same threshold rules + same `PrismaCoreEngine` reasoning applied to 6 identical machine-sensor records encoded in `sample_equipment_sensors.{csv,json,xml}` — confirmed **CSV == JSON == XML results: True**.
- `scratch/demo_pdf_form_to_facts.py`: generates 3 sample filled PDF permit forms (stand-in for "arrived externally"), reads real AcroForm widget fields back with PyMuPDF, maps to Facts via the same adapter, correct `RequiresSeniorReview` verdicts for all 3.
- Earlier prototype `scratch/structured_data_to_facts_demo.py` (beam compliance, CSV-only) still runs unchanged; it is the source Nivel 2 extracts from.

## 3. Nivel 2 (basic) — Norm/data separation, reusable module

Per the user's instruction to do "lo más básico" first: extracted the beam-compliance Rules out of the Nivel 1 prototype into a standalone module that is written once and never touched again by new data batches.

- **`scratch/norms/beam_compliance_norm.py`** — exposes `register_rules(engine)` (called once) and `evaluate_beam(engine, rules, beam_id, span_m, load_kn, material, has_certification)` (called per record, from any source format). Contains an explicit honesty disclaimer: thresholds (`SPAN_LIMIT_M=6.0`, `LOAD_LIMIT_KN=50.0`) are a toy stand-in, not a real cited building code — same discipline as `docs/VERIFICATION_STANDARDS.md` applies to legal/linguistic claims.
- **`scratch/norms/demo_new_beam_batch.py`** — feeds 5 brand-new beams (`BEAM-D1`–`D5`, never in the original `sample_beam_inspection_data.csv`) through the unmodified norm module. Expected outcomes were derived independently from the stated thresholds *before* running the engine, then compared:

```
All 5 new-batch results match independently-derived expectations: True
```

  Confirms the "encode the norm once, reuse across any future data" claim — zero edits to `beam_compliance_norm.py` were needed for the new batch.

### 3.1 Full regression guard (run after Nivel 1 and again after Nivel 2)

| Check | Result |
|---|---|
| `pytest tests/ -q` (packages/prisma-python) | 93 passed |
| `npm test` (packages/core) | 26 passed |
| `scratch/test_prisma_core_upgrades.py` | 5/5 PASSED |
| `scratch/prisma_legalbench_suite.py` (synthetic) | 100.00% (120/120) |
| `scratch/external_legalbench_eval_snell.py` (real, blind) | 74.47% (70/94) — unchanged |

Zero regressions from either Nivel 1 or Nivel 2 additions.

## 4. Nivel 3 — deferred

Free-text-heavy technical documents (inspection narratives, incident reports written in prose rather than structured fields) are explicitly deferred per the user: *"El paso tres queda pendiente a medida que conseguimos alguna forma de avanzar más rápido."* Not started; no code exists for it yet.
