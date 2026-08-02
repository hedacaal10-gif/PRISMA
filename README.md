# 🔮 PRISMA — Protocol for Reasoning, Inference and Semantic Memory Architecture

**Version:** Specification Protocol v4.0.0 | Core Engine v1.2.0 (CPython Reference Implementation)  
**Status:** Core deductive engine (Modus Ponens, cascade invalidation, temporal validity, HMAC provenance) verified via automated test suite. API, storage backends, and infrastructure layer are functional but under active hardening — coverage and known gaps are tracked in `reports/`.

---

## 📌 OVERVIEW

PRISMA is an open knowledge protocol and neuro-symbolic reasoning engine that converts logical deductions into immutable, cryptographically verifiable (SHA-256) memory objects with temporal validity and cascade invalidation, serving as a zero-hallucination verification layer between data and AI models.

---

## 📜 THE 5 PRINCIPLES OF PRISMA

1. **Principle 1: Truth Has Identity.** (Canonical RFC 8785 SHA-256 hashing).
2. **Principle 2: All Deductions Are Reproducible.** (Deterministic Horn Clause Modus Ponens).
3. **Principle 3: All Knowledge Is Revocable.** (Transitive BFS graph cascade invalidation).
4. **Principle 4: Memory Is Auditable.** (Immutable `Proof` trees linking premises to conclusions).
5. **Principle 5: AI Consumes Knowledge; PRISMA Certifies It.** (LLMs process natural language; PRISMA guarantees logical validity).

---

## 🚀 ACCESS & VERIFICATION

The core reasoning engine (`prisma_core`) and its verification/benchmark suites are proprietary and not distributed in this public repository. Verified results are published in two reports: the **Core Engine Upgrade Suite** and a **synthetic, self-authored** LegalBench-inspired suite (120 fixtures, 100% deductive accuracy on hand-written cases — see [reports/PRISMA_LEGALBENCH_EVALUATION_REPORT.md](reports/PRISMA_LEGALBENCH_EVALUATION_REPORT.md) for what that does and does not demonstrate), and a **real pilot against the actual Stanford LegalBench dataset** (71.28% honest accuracy on unseen real data, up from an initial 65.96% — [reports/PRISMA_LEGALBENCH_REAL_PILOT_REPORT.md](reports/PRISMA_LEGALBENCH_REAL_PILOT_REPORT.md)).

For the full normative specification, see the [Master Blueprint](PRISMA_MEGADOCUMENTO_COMPLETO_MASTER_BLUEPRINT.md).

---

## 📑 DOCUMENTATION INDEX FOR AGENTS & DEVELOPERS

* **[CLAUDE.md](CLAUDE.md)** — **Developer & Architecture Orientation Guide for Claude Code / LLM Agents.**
* **[PRISMA_MEGADOCUMENTO_COMPLETO_MASTER_BLUEPRINT.md](PRISMA_MEGADOCUMENTO_COMPLETO_MASTER_BLUEPRINT.md)** — **Single Source of Truth Master Blueprint & Normative Protocol Specification.**
* **[docs/specs/LEGALBENCH_PRISMA_SPEC.md](docs/specs/LEGALBENCH_PRISMA_SPEC.md)** — Stanford LegalBench AST Mapping Specification.
* **[reports/PRISMA_LEGALBENCH_EVALUATION_REPORT.md](reports/PRISMA_LEGALBENCH_EVALUATION_REPORT.md)** — Synthetic benchmark report (self-authored fixtures, LegalBench-inspired).
* **[reports/PRISMA_LEGALBENCH_REAL_PILOT_REPORT.md](reports/PRISMA_LEGALBENCH_REAL_PILOT_REPORT.md)** — Real pilot against the actual `nguha/legalbench` dataset (71.28% honest accuracy, hearsay task, up from an initial 65.96%).
* **[reports/PRISMA_LEGALBENCH_MULTI_TASK_REAL_PILOT_REPORT.md](reports/PRISMA_LEGALBENCH_MULTI_TASK_REAL_PILOT_REPORT.md)** — 3 more real LegalBench tasks: `diversity_1` (100% real accuracy), `contract_qa` (87.5%), `ucc_v_common_law` (53.2%).
* **[reports/PRISMA_ENGINE_STRUCTURAL_STRESS_TEST_REPORT.md](reports/PRISMA_ENGINE_STRUCTURAL_STRESS_TEST_REPORT.md)** — Engine isolated from extraction: hand-encoded real bar-exam scenarios testing FALSE-valued antecedents, OR logic, and 3-level chains (3/3 correct).
* **[reports/PRISMA_INFRASTRUCTURE_HARDENING_REPORT.md](reports/PRISMA_INFRASTRUCTURE_HARDENING_REPORT.md)** — SSRF vulnerability found & fixed in the URL-import endpoint, new auth/webhook test coverage, unsalted-password-hash finding flagged for a migration decision.
* **[reports/PRISMA_CODE_DOMAIN_REAL_PILOT_REPORT.md](reports/PRISMA_CODE_DOMAIN_REAL_PILOT_REPORT.md)** — General-domain expansion, starting with code: real Horn-clause rule over PRISMA's own real source (198 functions, 100% independently verified).
* **[reports/PRISMA_LUZ_SNELL_ARCHITECTURE_REPORT.md](reports/PRISMA_LUZ_SNELL_ARCHITECTURE_REPORT.md)** — "Luz" (bilingual EN/ES ingestion, WordNet + growing custom lexicon) and "Snell" (formal dependency-parse extraction engine): 74.47% real (70/94), including a nominalized-reporting-expression fix ("Bob's statement that X") found via aggregate diagnosis and a WordNet hypernym expansion — both with documented trade-offs, not test-row inspection.
* **[reports/PRISMA_LUZ_SPANISH_PILOT_REPORT.md](reports/PRISMA_LUZ_SPANISH_PILOT_REPORT.md)** — Spanish-specific Luz/Snell hypotheses (pro-drop, subjunctive, enclisis — now resolved without model fine-tuning, via surface-form recognition + full-subtree content-clause search) against a self-authored 20-row dataset (NOT a benchmark, pending university-professor review) — 85% on the team's own dataset, never comparable to the English 74.47% real figure.
* **[reports/PRISMA_NON_TECHNICAL_GENERALIZATION_REPORT.md](reports/PRISMA_NON_TECHNICAL_GENERALIZATION_REPORT.md)** — Self-authored (not a benchmark) probes: everyday non-legal-template sentences (found and fixed 2 real Snell bugs), and the core engine isolated in a non-legal domain (family relationships, discount eligibility, lease terms) — 100% deductive accuracy, confirming engine/extraction separation holds outside the legal domain too.
* **[reports/PRISMA_REAL_INGESTION_GAP_REPORT.md](reports/PRISMA_REAL_INGESTION_GAP_REPORT.md)** — Honest ingestion-quality gap on real statutory text (0% faithful extraction, systemic `\$` false-positive bug found).
* **[reports/PRISMA_EXTERNAL_EXAMSET_INGESTION_REPORT.md](reports/PRISMA_EXTERNAL_EXAMSET_INGESTION_REPORT.md)** — Same gap independently confirmed on real NCBE bar exam questions.
* **[docs/VERIFICATION_STANDARDS.md](docs/VERIFICATION_STANDARDS.md)** — Governance standard for how future benchmarks/tests must be sourced, scored, and reported.
* **[docs/CONSTITUTION.md](docs/CONSTITUTION.md)** — Formal System Invariants (`CP-001`–`CP-008`).
* **[reports/PRISMA_INFORME_TECNICO_MAESTRO_3PAGINAS.md](reports/PRISMA_INFORME_TECNICO_MAESTRO_3PAGINAS.md)** — Master Technical Report: statistical methodology, percentiles, 10M-scale results, competitive matrix, and SLA.

---

## 🔒 DATA TRANSPARENCY & COLLECTION POLICY (BETA PHASE)

To audit performance, improve text-extractor accuracy, and evaluate client behavior during these public phases, PRISMA logs only the following minimal telemetry:

1. **Data Collected:**
   - Submitted query text (`query_text`) and detected intent (`detected_intent`).
   - SHA-256 identifier of uploaded documents (`doc_sha256`).
   - Response latency metric (microseconds/milliseconds) and HTTP response code.
   - Voluntary user feedback (thumbs up/down votes).
2. **What We Do NOT Collect or Store:**
   - **No plaintext passwords are stored** (SHA-256 hashing is used).
   - **No unauthorized personally identifiable information (PII) is collected.**
   - Sensitive API keys are automatically masked in logs.
3. **Use of Information:**
   - Audit logs (`query_audit_logs`) are used exclusively for telemetry analysis, error detection, and improvement of the PRISMA reasoning engine.

---

## 🎨 ARCHITECTURE SUMMARY

```
                         Datos / Documentos
                                 │
                                 ▼
                         Formalización AST
                                 │
                                 ▼
                           PRISMA Engine
                       Facts   Rules   Proofs
                                 │
                                 ▼
                         Knowledge Objects
                       (Identidad SHA-256)
                                 │
                                 ▼
                          API / SDK / LLM
```

---
*PRISMA Protocol Specification v4.0.0 — Proprietary Enterprise License. Copyright (c) 2026 PRISMA Systems. All Rights Reserved. Intellectual Property Registration: Dirección Nacional de Derecho de Autor (DNDA) — Colombia, 2026.*
