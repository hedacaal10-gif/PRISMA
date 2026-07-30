# PRISMA Requirement Traceability Matrix (RTM) v1.0

**Document Identifier**: `PRISMA-RTM-V1`  
**Status**: APPROVED & NORMATIVE  
**Coverage**: 100% of RFC 2119 `MUST` / `MUST NOT` Statements Mapped to Conformance Test IDs  

---

## 1. Specification Requirement Traceability Table

| Requirement ID | Source Document | Section | Normative Statement | Mapped Conformance Test | Status |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **REQ-CORE-001** | `PRISMA-CORE` | §2 (CP-001) | Lineage sound iff all dependencies exist and are sound | `CTS-0001`, `CTS-0035` | PASS |
| **REQ-CORE-002** | `PRISMA-CORE` | §2 (CP-002) | Inference operator MUST produce identical results | `CTS-0002`, `CTS-0040` | PASS |
| **REQ-CORE-003** | `PRISMA-CORE` | §2 (CP-003) | Semantic identity MUST be unique for identical semantics | `CTS-0003`, `CTS-0010` | PASS |
| **REQ-CORE-004** | `PRISMA-CORE` | §2 (CP-004) | Historical version DAG nodes MUST be read-only | `CTS-0004`, `CTS-0045` | PASS |
| **REQ-CORE-005** | `PRISMA-CORE` | §2 (CP-005) | Contradictions MUST instantiate explicit contradiction object | `CTS-0005`, `CTS-0050` | PASS |
| **REQ-CORE-006** | `PRISMA-CORE` | §2 (CP-006) | Contextual evaluation MUST isolate context boundaries | `CTS-0006`, `CTS-0055` | PASS |
| **REQ-CORE-007** | `PRISMA-CORE` | §2 (CP-007) | Projections MUST NOT mutate underlying knowledge state | `CTS-0007`, `CTS-0060` | PASS |
| **REQ-CORE-008** | `PRISMA-CORE` | §2 (CP-008) | Semantics MUST be independent of language and storage | `CTS-0008`, `CTS-0080` | PASS |
| **REQ-LANG-001** | `PRISMA-LANGUAGE` | §2 | `ContextRef` MUST match regex `^prisma:context:[a-zA-Z0-9_\:\/\-]+$` | `CTS-0011` | PASS |
| **REQ-LANG-002** | `PRISMA-LANG` | §2 | Floating point `-0.0` MUST be converted to `0` prior to RFC 8785 | `CTS-0012` | PASS |
| **REQ-LANG-003** | `PRISMA-LANG` | §2 | Non-finite values (`NaN`, `Infinity`) are strictly FORBIDDEN | `CTS-0013` | PASS |
| **REQ-LANG-004** | `PRISMA-LANG` | §2 | All URIs and Predicates MUST use binary UTF-8 case matching | `CTS-0014` | PASS |
| **REQ-OBJ-001** | `PRISMA-OBJECTS` | §2 | String fields MUST be normalized to Unicode NFC | `CTS-0021` | PASS |
| **REQ-OBJ-002** | `PRISMA-OBJECTS` | §2 | Timestamps MUST be ISO 8601 UTC extended format | `CTS-0022` | PASS |
| **REQ-OBJ-003** | `PRISMA-OBJECTS` | §2 | Array elements in `dependencies` MUST be sorted lexicographically | `CTS-0023` | PASS |
| **REQ-OBJ-004** | `PRISMA-OBJECTS` | §4 (PO-1) | `id` MUST equal SHA-256 over Canonical JSON AST | `CTS-0024` | PASS |
| **REQ-OBJ-005** | `PRISMA-OBJECTS` | §4 (PO-2) | All `dependencies` MUST be in non-INVALIDATED state | `CTS-0025` | PASS |
| **REQ-INF-001** | `PRISMA-INFERENCE` | §2 | Inference Operator MUST be P-Complete $O(n^k)$ | `CTS-0031` | PASS |
| **REQ-INF-002** | `PRISMA-INFERENCE` | §2 | Horn clause recursion depth MUST be bounded by $D_{\text{max}} = 256$ | `CTS-0032` | PASS |
| **REQ-INF-003** | `PRISMA-INFERENCE` | §3 | Multiple valid proofs MUST select $\min \text{SHA256}(\text{ProofAST})$ | `CTS-0033` | PASS |
| **REQ-PROJ-001**| `PRISMA-PROJ` | §2 | Projections MUST preserve semantic ID invariant (H3) | `CTS-0061` | PASS |

---

## 2. Automated Traceability Audit Verification

- Total Normative Statements: **21**
- Mapped Conformance Tests: **21 / 21 (100% Coverage)**
- Unmapped Requirements: **0**
