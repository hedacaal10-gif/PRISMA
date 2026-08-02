# 🤖 CLAUDE.md — Developer & Architecture Orientation Guide for Claude Code

Welcome, **Claude Code**! This file contains the complete project context, architecture invariants, repository structure, and execution instructions for continuing the development of **PRISMA**.

---

## 📌 1. PRISMA IN A NUTSHELL

> **"PRISMA (Protocol for Reasoning, Inference, and Semantic Memory Architecture) is an open knowledge protocol and neuro-symbolic reasoning engine that converts logical deductions into immutable, cryptographically verifiable (SHA-256) memory objects with temporal validity and cascade invalidation, serving as a zero-hallucination verification layer between data and AI models."**

### The 5 Core Principles (The Constitution of PRISMA)
1. **Principle 1: Truth Has Identity.** (Canonical RFC 8785 SHA-256 hashing).
2. **Principio 2: All Deductions Are Reproducible.** (Deterministic Horn Clause Modus Ponens).
3. **Principle 3: All Knowledge Is Revocable.** (Transitive BFS graph cascade invalidation).
4. **Principle 4: Memory Is Auditable.** (Immutable `Proof` trees linking premises to conclusions).
5. **Principle 5: AI Consumes Knowledge; PRISMA Certifies It.** (LLMs process natural language; PRISMA guarantees logical validity).

---

## 🗺️ 2. REPOSITORY STRUCTURE & KEY FILES

```
PRISMA/
├── PRISMA_MEGADOCUMENTO_COMPLETO_MASTER_BLUEPRINT.md  <-- MAIN MASTER SPECIFICATION
├── README.md                                         <-- General Project Overview
├── CLAUDE.md                                         <-- This Developer Guide
├── packages/
│   └── prisma-python/prisma_core/                    <-- Core Engine (CPython Reference Impl) -- GITIGNORED, not in git history
│       ├── types.py                                  <-- Dataclasses, LifecycleState, AuthorityLevel
│       ├── canonical.py                              <-- RFC 8785 Canonical JSON Stringification
│       ├── identity.py                               <-- SHA-256 Semantic Identity & Provenance Signatures
│       ├── validator.py                              <-- CoreValidator & Governance Rules
│       ├── engine.py                                 <-- PrismaCoreEngine & Lock-Free Snapshot Reader (infer() genuinely matches Rule antecedent vs Fact values as of 2026-07-31)
│       ├── ast_ingester.py                           <-- Python AST Ingester (0% LLM)
│       ├── formatter.py                              <-- Human Natural Language Projection Formatter
│       ├── server.py                                 <-- FastAPI REST API Gateway (Port 7777) -- ~9/32 endpoints covered by tests
│       ├── storage.py                                <-- SQLite storage (real, working)
│       ├── storage_postgres.py                       <-- In-memory stub with Postgres-shaped interface (NOT wired to a real DB)
│       └── storage_redis.py                          <-- Redis storage with silent in-memory fallback
├── scratch/                                          <-- Verification Test Suites & Benchmarks -- GITIGNORED, not in git history
│   ├── test_prisma_core_upgrades.py                  <-- Automated Engine Upgrade Verification Suite
│   ├── prisma_legalbench_suite.py                    <-- SYNTHETIC self-authored suite (120 hand-written cases, LegalBench-inspired naming only -- NOT the real dataset)
│   ├── external_legalbench_eval.py                   <-- REAL pilot against the actual `nguha/legalbench` dataset (hearsay task, 65.96% honest accuracy)
│   ├── demo_legalbench_responses.py                  <-- Demo Output Generator
│   └── ten_million_benchmark_and_evaluation.py       <-- 10M Operations Stress Test Script
├── docs/specs/
│   └── LEGALBENCH_PRISMA_SPEC.md                     <-- Original PRISMA predicate design, LegalBench-inspired (not a mapping of the real dataset)
└── reports/
    ├── PRISMA_LEGALBENCH_EVALUATION_REPORT.md        <-- Synthetic suite report (see transparency note in the file)
    └── PRISMA_LEGALBENCH_REAL_PILOT_REPORT.md        <-- Real dataset pilot report (honest accuracy, by task slice)
```

---

## 🚀 3. VERIFICATION COMMANDS FOR CLAUDE CODE

When making changes to `prisma_core`, always run the following verification scripts to ensure zero regression and 100% compliance:

### 1. Run Self-Analysis & Self-Audit (PRISMA Ingesting PRISMA)
```bash
python scratch/prisma_self_analysis_and_benchmarks.py
```
*Expected Output:* `Architecture State: VERIFIED_VALID` | Ingests 657+ AST facts from `prisma_core`.

### 2. Run Core Engine Upgrade Verification Suite
```bash
python scratch/test_prisma_core_upgrades.py
```
*Expected Output:*
`[SUCCESS] ALL 5 PRISMA CORE ENGINE UPGRADE TESTS PASSED PERFECTLY!`
Verifies: Lock-free snapshot concurrency, authority level governance, HMAC-SHA256 provenance signatures, graceful temporal disjoint handling, and BFS cascade invalidation.

### 3. Run pytest suite (packages/prisma-python/tests/)
```bash
cd packages/prisma-python && python -m pytest tests/ -q
```
*Expected Output (as of 2026-07-31):* 38 passed, 0 failed. (Earlier that day, 3 tests failed due to real bugs since fixed: `invalidate()` ignored `mode` for cascade dependents, `supersede()` re-invalidated the object it had just marked `SUPERSEDED`, and `/api/v1/infer` crashed with a `NoneType` error instead of a clean 400 when premises were invalid. If any of these 3 regress, check `engine.py`'s `invalidate`/`supersede` and `server.py`'s `/api/v1/infer` handler first.)

### 4. Run Synthetic LegalBench Suite (120 self-authored cases -- NOT the real dataset)
```bash
python scratch/prisma_legalbench_suite.py
```
*Expected Output:*
`Overall Deductive Accuracy: 100.00% (120/120)` | `P50 Latency: 50.10 us`
⚠️ This is a self-authored fixture suite (see transparency note in `reports/PRISMA_LEGALBENCH_EVALUATION_REPORT.md`). It demonstrates the engine deduces correctly given hand-encoded Facts/Rules -- it does NOT demonstrate performance on the real Stanford LegalBench dataset or on unseen legal text.

### 5. Run REAL LegalBench Pilot (actual `nguha/legalbench` dataset)
```bash
python scratch/external_legalbench_eval.py
```
*Expected Output:* Overall real accuracy ~65.96% (62/94) on the `hearsay` task, scored blind against the dataset's own labels. See `reports/PRISMA_LEGALBENCH_REAL_PILOT_REPORT.md` for the full breakdown by task slice and honest discussion of where the extraction heuristic is weak.

### 6. Run 10M Operations Benchmark
```bash
python scratch/ten_million_benchmark_and_evaluation.py
```

---

## 🏛️ 4. ARCHITECTURAL INVARIANTS & CODING RULES

1. **RFC 8785 Canonical JSON Hashing:** Always use `stringify_canonical` before hashing `KnowledgeObject` payloads with SHA-256. Do NOT use `json.dumps()` directly.
2. **Unified `KnowledgeObject` Dataclass:** Facts, Rules, Proofs, and Materializations MUST inherit from or be instances of `KnowledgeObject` with valid `id`, `type`, `expression`, `context`, `temporalValidity`, `provenance`, `dependencies`, and `integrityState`.
3. **Lock-Free Read Pattern:** Reads and `infer()` queries MUST operate on `self._snapshot` (Copy-On-Write) to avoid blocking REST API readers during graph invalidation sweeps.
4. **Authority Governance Check:** Always check `CoreValidator.validate_authority_governance(fact)` when evaluating inferences to reject `DRAFT` or unverified inputs when strict authority is required.
5. **Graceful Temporal Interval Handling:** If premise intervals are disjoint ($\max(S_A, S_B) > \min(E_A, E_B)$), return `InferenceResult(status=InferenceStatus.TEMPORALLY_INVALID)` instead of throwing unhandled exceptions.
6. **Genuine Antecedent Satisfaction (added 2026-07-31):** `infer()` MUST verify that `fact_a`/`fact_b`'s `PredicateAssertion` (`operator`+`value`) actually match every condition in the Rule's `antecedent` list before producing a derived fact. If any condition is unmatched, return `InferenceResult(status=InferenceStatus.UNSATISFIED_PREMISES)`. Do not reintroduce the earlier pattern of deciding rule satisfaction in caller code (e.g. a Python `if` before calling `infer()`) -- that logic belongs inside the engine. See `packages/prisma-python/tests/test_core.py::test_infer_rejects_unsatisfied_antecedent` for the regression test.
7. **No unverified claims in reports/README:** Every benchmark or accuracy claim must state whether it was measured against real external data (cite dataset ID/source) or self-authored fixtures (label explicitly as synthetic). Never blend "engine deduces correctly given correct Facts" with "PRISMA's extraction pipeline correctly derived those Facts from raw text" into a single number -- they are different, currently very different in maturity, claims. Full standard: [docs/VERIFICATION_STANDARDS.md](docs/VERIFICATION_STANDARDS.md).

---

## 📑 5. KEY DOCUMENTATION REFERENCES

* **Full Master Specification:** Read [PRISMA_MEGADOCUMENTO_COMPLETO_MASTER_BLUEPRINT.md](PRISMA_MEGADOCUMENTO_COMPLETO_MASTER_BLUEPRINT.md) for the complete blueprint, Big-O tables, Colombian Transit Law case study, and Go-To-Market ICP strategy.
* **LegalBench AST Mapping (original design, not a real-dataset mapping):** Read [docs/specs/LEGALBENCH_PRISMA_SPEC.md](docs/specs/LEGALBENCH_PRISMA_SPEC.md).
* **Synthetic Benchmark Report:** Read [reports/PRISMA_LEGALBENCH_EVALUATION_REPORT.md](reports/PRISMA_LEGALBENCH_EVALUATION_REPORT.md).
* **Real Dataset Pilot Report:** Read [reports/PRISMA_LEGALBENCH_REAL_PILOT_REPORT.md](reports/PRISMA_LEGALBENCH_REAL_PILOT_REPORT.md) for honest accuracy against the actual `nguha/legalbench` dataset.
