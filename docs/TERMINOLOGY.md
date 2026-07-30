# PRISMA Terminology Standard

**Document Identifier**: `PRISMA-TERMINOLOGY`  
**Status**: Standard Terminology Specification  

---

## 1. Reglas de Uso del Lenguaje Normativo

Para garantizar la precisión e imperturbabilidad de las especificaciones y modelos de PRISMA, se adopta estrictamente la convención [IETF RFC 2119 / RFC 8174]:

- **MUST / SHALL**: Indica un requisito absoluto e inquebrantable de la especificación.
- **MUST NOT / SHALL NOT**: Indica una prohibición absoluta.
- **SHOULD / RECOMMENDED**: Indica que pueden existir razones válidas bajo circunstancias particulares para ignorar el elemento, pero las implicaciones completas deben ser comprendidas antes de optar por un camino diferente.
- **SHOULD NOT / NOT RECOMMENDED**: Indica que la conducta o práctica es altamente desaconsejada.
- **MAY / OPTIONAL**: Indica que un elemento es completamente opcional.

---

## 2. Taxonomía de Entidades Lógicas

### 2.1 Afirmación (`Assertion`)
Toda declaración declarativa expresada dentro de la sintaxis PRISMA que asigna un valor o relación a un sujeto dentro de un contexto.

### 2.2 Invariante (`Invariant`)
Una condición o propiedad matemática que debe mantenerse verdadera en todo momento durante el ciclo de vida de un objeto o durante la ejecución de una transformación semántica.

### 2.3 Objeto de Conocimiento Materializado (`Materialized Knowledge Object`)
Un objeto derivado de un árbol de derivación lógica (`PROOF`) cuyo resultado ha sido persistido e indexado en memoria con la garantía constitucional de invalidación en caso de cambio de premisas originarias.
