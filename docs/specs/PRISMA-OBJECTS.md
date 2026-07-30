# PRISMA-OBJECTS: Knowledge Objects & Lifecycle Specification

**Document Identifier**: `PRISMA-OBJECTS`  
**Status**: Frozen Technical Specification v1.0  
**Supersedes**: PRISMA-000, PRISMA-001  

---

## 1. Ontological Tuple Definition

$$\kappa = \langle \text{id}, \text{type}, \text{expr}, \mathcal{C}, \mathcal{T}, \text{prov}, \text{dep} \rangle$$

Where:
- $\text{id} \in \{ \text{prisma:id:sha256:}[a-f0-9]^{64} \}$
- $\text{type} \in \{ \text{prisma:type:fact}, \text{prisma:type:rule}, \text{prisma:type:proof}, \text{prisma:type:materialized} \}$
- $\text{expr} \in \Sigma_{\text{PL\_AST}}$
- $\mathcal{C} \in \text{ContextID}$
- $\mathcal{T} = [\tau_{\text{start}}, \tau_{\text{end}}] \subseteq \text{ISO8601\_Interval}$
- $\text{prov} = \langle \text{issuer}, \text{method}, \text{signature} \rangle$
- $\text{dep} \subseteq \text{Array<KnowledgeObjectID>}$

---

## 2. Canonical Identity Rules (Normative Hash Interoperability)

To guarantee that two independent implementations (Team A and Team B) produce identical SHA-256 identity hashes (`PO-1`), the following formatting rules MUST be strictly enforced prior to RFC 8785 JSON canonicalization:

1. **String Normalization**: All string fields MUST be normalized to Unicode Normalization Form C (NFC).
2. **Date-Time Formatting**: Timestamps in `temporalValidity` MUST be formatted as ISO 8601 UTC extended format without fractional seconds (`YYYY-MM-DDTHH:mm:ssZ`) or `"INF"` / `"-INF"`.
3. **Dependency Sorting**: Array elements in `dependencies` MUST be sorted lexicographically by their string values prior to computing `PO-1`.

---

## 3. State Transition Matrix

$$\text{Transition}: S_i \times \text{Event} \to S_{i+1}$$

| Current State ($S_i$) | Event | Target State ($S_{i+1}$) | Validation Rule |
| :--- | :--- | :--- | :--- |
| `DRAFT` | `assert()` | `ASSERTED` | Verify PO-1 & Signature |
| `ASSERTED` | `materialize()` | `MATERIALIZED` | Verify PO-2 Lineage & Attach ProofID |
| `ASSERTED` | `supersede()` | `SUPERSEDED` | Attach New Version ID |
| `ASSERTED` | `invalidate()` | `INVALIDATED` | Triggered by Dep Failure or Contradiction |
| `MATERIALIZED` | `invalidate()` | `INVALIDATED` | Triggered by Dep Failure or Contradiction |

---

## 4. Proof Obligations

### PO-1: Identity Hash Determinism
$$\text{VerifyPO1}(\kappa) \iff \kappa.\text{id} == \text{SHA256}(\text{CanonicalJSON}(\kappa.\text{type}, \kappa.\text{expression}, \kappa.\text{context}, \kappa.\text{temporalValidity}))$$

### PO-2: Lineage Non-Invalidation
$$\text{VerifyPO2}(\kappa, \mathcal{K}) \iff \forall d \in \kappa.\text{dependencies}, \quad d \in \mathcal{K} \land \text{state}(d) \neq \text{INVALIDATED}$$
