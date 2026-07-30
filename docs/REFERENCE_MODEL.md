# PRISMA Conceptual Reference Model

**Document Identifier**: `PRISMA-REFERENCE-MODEL`  
**Status**: Reference Model  
**Target Audience**: Software Architects, System Designers, Ontologists  

---

## 1. Visión General

El Modelo de Referencia de PRISMA define la taxonomía conceptual y la estructura de relaciones entre las entidades fundamentales de la arquitectura. Funciona como una especificación estructural agnóstica de lenguaje (similar a un metamodelo UML conceptual).

---

## 2. Jerarquía de Objetos de Conocimiento (`Knowledge Object`)

Todo elemento interpretable en PRISMA desciende del concepto abstracto `Knowledge Object`.

```text
                     ┌──────────────────────────┐
                     │     Knowledge Object     │
                     └────────────┬─────────────┘
                                  │
         ┌────────────────────────┼────────────────────────┐
         │                        │                        │
┌────────┴─────────┐     ┌────────┴─────────┐     ┌────────┴─────────┐
│       FACT       │     │       RULE       │     │      PROOF       │
└──────────────────┘     └──────────────────┘     └──────────────────┘
                                                           │
                                                  ┌────────┴─────────┐
                                                  │   MATERIALIZED   │
                                                  │    KNOWLEDGE     │
                                                  └──────────────────┘
```

---

## 3. Descripción de los Componentes Conceptual

### 3.1 `Knowledge Object` (Contrato Base)
Entidad abstracta primaria. Posee obligatoriamente:
- **Identity**: Identificador semántico único determinista.
- **Version**: Grafo acíclico de versión y linaje.
- **Provenance**: Trazabilidad del origen y emisor.
- **Temporal Validity**: Intervalo de validez en tiempo semántico ($\mathcal{T}$).
- **Context**: Espacio contextual ($\mathcal{C}$) en el que la afirmación o regla es aplicable.
- **Semantic Type**: Clasificación dentro del sistema de tipos ontológico.
- **Dependencies**: Grafo de premisas de las que depende el objeto.
- **Integrity State**: Estado auditado de consistencia.

### 3.2 `FACT` (Hecho)
Declaración atómica o compuesta sobre una entidad, propiedad o relación observada o postulada en un contexto dado.
- *Ejemplo*: `En Colombia, la mayoría de edad es a los 18 años.`

### 3.3 `RULE` (Regla)
Implicación lógica o condicional que permite derivar nuevos hechos a partir de premisas existentes.
- *Ejemplo*: `SI persona.edad >= 18 Y persona.jurisdiccion = Colombia ENTONCES persona.esMayorDeEdad = True.`

### 3.4 `PROOF` (Prueba)
Árbol acíclico dirigido de derivación deductiva que justifica mecánicamente por qué una conclusión se deduce de un conjunto de `FACT` y `RULE`.

### 3.5 `MATERIALIZED KNOWLEDGE` (Conocimiento Materializado)
Inferencia previamente validada y almacenada en memoria indexada para acelerar futuras consultas sin necesidad de re-evaluar la prueba lógica completa.

---

## 4. Diagrama Conceptual de Relaciones

```text
  ┌───────────┐      evalúa      ┌───────────┐
  │   Query   ├─────────────────>│   Logic   │
  └─────┬─────┘                  └─────┬─────┘
        │                              │ produce
        │ consume                      ▼
        │                        ┌───────────┐
        │                        │   PROOF   │
        │                        └─────┬─────┘
        ▼                              │ referencia
┌───────────────┐  recupera /    ┌─────┴───────────────┐
│    Memory     |<───────────────┤ MATERIALIZED KNOWL. │
└───────┬───────┘  persiste      └─────────────────────┘
        │
        │ administra
        ▼
┌───────────────┐
│ KnowledgeObj  │ (FACT / RULE)
└───────────────┘
```
