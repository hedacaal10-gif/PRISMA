# PRISMA-001: Knowledge Objects Contract & Lifecycle Specification

**Identifier**: `PRISMA-001`  
**Tier**: Foundation  
**Status**: Ratified Technical Standard v1.0  

---

## 1. Normative Contract (8 Mandatory Attributes)

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "KnowledgeObjectContract",
  "type": "object",
  "required": [
    "id",
    "type",
    "expression",
    "context",
    "temporalValidity",
    "provenance",
    "dependencies",
    "integrityState"
  ],
  "properties": {
    "id": { "type": "string", "pattern": "^prisma:id:sha256:[a-f0-9]{64}$" },
    "type": { "type": "string", "pattern": "^prisma:type:(fact|rule|proof|materialized)$" },
    "expression": { "type": "object" },
    "context": { "type": "string" },
    "temporalValidity": {
      "type": "array",
      "items": { "type": "string" },
      "minItems": 2,
      "maxItems": 2
    },
    "provenance": {
      "type": "object",
      "required": ["issuer", "method"],
      "properties": {
        "issuer": { "type": "string" },
        "method": { "type": "string" },
        "signature": { "type": "string" }
      }
    },
    "dependencies": {
      "type": "array",
      "items": { "type": "string" }
    },
    "integrityState": {
      "type": "string",
      "enum": ["DRAFT", "ASSERTED", "MATERIALIZED", "SUPERSEDED", "INVALIDATED"]
    }
  }
}
```

---

## 2. State Transition Matrix

$$\text{Transition}: S_i \times \text{Event} \to S_{i+1}$$

| Current State ($S_i$) | Event | Target State ($S_{i+1}$) | Validation Rule |
| :--- | :--- | :--- | :--- |
| `DRAFT` | `assert()` | `ASSERTED` | Verify PO-1 & Signature |
| `ASSERTED` | `materialize()` | `MATERIALIZED` | Verify PO-2 Lineage & Attach ProofID |
| `ASSERTED` | `supersede()` | `SUPERSEDED` | Attach New Version ID |
| `ASSERTED` | `invalidate()` | `INVALIDATED` | Triggered by Dep Failure or Contradiction |
| `MATERIALIZED` | `invalidate()` | `INVALIDATED` | Triggered by Dep Failure or Contradiction |

---

## 3. Proof Obligations (PO Benchmark)

### PO-1: Identity Hash Determinism
$$\text{VerifyPO1}(\kappa) \iff \kappa.\text{id} == \text{SHA256}(\text{CanonicalJSON}(\kappa.\text{type}, \kappa.\text{expression}, \kappa.\text{context}, \kappa.\text{temporalValidity}))$$

### PO-2: Lineage Non-Invalidation
$$\text{VerifyPO2}(\kappa, \mathcal{K}) \iff \forall d \in \kappa.\text{dependencies}, \quad d \in \mathcal{K} \land \text{state}(d) \neq \text{INVALIDATED}$$
