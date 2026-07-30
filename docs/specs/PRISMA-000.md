# PRISMA-000: Theory of Knowledge Objects Specification

**Identifier**: `PRISMA-000`  
**Tier**: Foundation  
**Status**: Ratified Technical Standard v1.0  

---

## 1. Formal Definition

A Knowledge Object $\kappa \in \mathcal{K}$ is defined as the tuple:

$$\kappa = \langle \text{id}, \text{type}, \text{expr}, \mathcal{C}, \mathcal{T}, \text{prov}, \text{dep} \rangle$$

Where:
- $\text{id} \in \{ \text{prisma:id:sha256:}[a-f0-9]^{64} \}$
- $\text{type} \in \{ \text{prisma:type:fact}, \text{prisma:type:rule}, \text{prisma:type:proof}, \text{prisma:type:materialized} \}$
- $\text{expr} \in \Sigma_{\text{PL\_AST}}$
- $\mathcal{C} \in \text{ContextID}$
- $\mathcal{T} = [\tau_{\text{start}}, \tau_{\text{end}}] \subset \text{ISO8601\_Interval}$
- $\text{prov} = \langle \text{issuer}, \text{method}, \text{signature} \rangle$
- $\text{dep} \subseteq \text{Array<KnowledgeObjectID>}$

---

## 2. Invariants & Verifiable Theorems

### Theorem 1: Deterministic Identity Mapping
$$\text{id}(\kappa) \equiv \text{SHA256}(\text{CanonicalJSON}(\langle \text{type}, \text{expr}, \mathcal{C}, \mathcal{T} \rangle))$$
- **Validation**: Any two implementations evaluating $\kappa_1, \kappa_2$ with identical $\langle \text{type}, \text{expr}, \mathcal{C}, \mathcal{T} \rangle$ MUST generate identical $\text{id}$.

### Theorem 2: Non-Orphan Lineage
$$\forall \kappa \in \mathcal{K} \setminus \mathcal{F}_{\text{axiom}}, \quad |\text{dep}(\kappa)| \ge 1 \land \forall d \in \text{dep}(\kappa), d \in \mathcal{K}$$
- **Validation**: Rejection of any object whose dependencies are not present in $\mathcal{K}$.

### Theorem 3: Contextual Non-Contradiction
$$\forall \kappa_1, \kappa_2 \in \mathcal{K}, \quad (\text{expr}(\kappa_1) \equiv \neg \text{expr}(\kappa_2)) \land (\mathcal{C}_{\kappa_1} = \mathcal{C}_{\kappa_2}) \implies \bot_{\text{sem}}$$
- **Validation**: Contradiction flag triggered if and only if context intersection $\mathcal{C}_1 \cap \mathcal{C}_2 \neq \emptyset$.

---

## 3. Algebraic Edge Cases

| Edge Case | Input Condition | System Behavior | Test Criteria |
| :--- | :--- | :--- | :--- |
| **EC-01: Synonymy** | $\text{expr}_1 \neq \text{expr}_2 \land \text{AST}_1 \equiv \text{AST}_2$ | $\text{id}_1 == \text{id}_2$ | AST equivalence check pass |
| **EC-02: Ephemeral Validity** | $t > \tau_{\text{end}}$ | $\llbracket \kappa \rrbracket_t = \bot$ | Out-of-bounds evaluation returns $\bot$ |
| **EC-03: Invalidated Dep** | $\exists d \in \text{dep}(\kappa) : \text{state}(d) = \text{INVALIDATED}$ | $\text{state}(\kappa) \to \text{INVALIDATED}$ | Cascade invalidation execution |
