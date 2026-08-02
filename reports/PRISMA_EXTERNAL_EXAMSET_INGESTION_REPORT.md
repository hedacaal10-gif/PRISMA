# PRISMA — External Bar Exam Material Ingestion Report

**Fecha de evaluación:** 31 de julio, 2026
**Pipeline evaluado:** el mismo de `reports/PRISMA_REAL_INGESTION_GAP_REPORT.md` (`TextIngestionEngine` → `PrismaMicroAIExtractor`)
**Script:** `scratch/external_examset_eval.py`
**Resultados completos:** `scratch/external_examset_eval_results.json`

---

## 1. Fuente y licencia (leer antes de reutilizar este material)

**Fuente:** National Conference of Bar Examiners (NCBE) — el organismo que efectivamente redacta el Multistate Bar Examination (MBE) en EE. UU. — "MBE Sample Test Questions":
`https://www.ncbex.org/sites/default/files/2023-05/MBE_Sample_Test_Questions_New_2023%20.pdf`

**Aviso de licencia encontrado en el propio documento:** *"Copyright © 2016, 2021 by the National Conference of Bar Examiners. All rights reserved."*

Este material es **gratuito y de acceso público** (el NCBE lo publica en su propio sitio oficial para que los aspirantes practiquen) pero **no tiene licencia abierta** — no es dominio público ni Creative Commons, a diferencia de los estatutos federales usados en la Fase 2. Por decisión explícita del usuario, se usaron únicamente **3 de las 21 preguntas** disponibles en el documento (una porción pequeña, no el examen completo), para evaluación técnica interna del pipeline de ingesta de PRISMA — un uso transformador/académico de bajo riesgo, no una redistribución del examen. Cada pregunta en `scratch/external_examset_eval.py` mantiene su atribución completa; no se debe quitar esa atribución si este archivo se reutiliza en otro contexto.

El texto se extrajo con la librería `pypdf` (`WebFetch` no pudo parsear el PDF correctamente) y se verificó línea por línea contra el PDF oficial.

---

## 2. Resultado principal

| Métrica | Valor |
| :--- | :--- |
| Preguntas reales usadas | 3 de 21 disponibles (autodefensa penal, modificación de contrato/UCC, hearsay/testimonio de jurado investigador) |
| Fragmentos evaluados | 7 |
| `accuracy_rate` autoreportado por el pipeline | 100.0% en las 3 preguntas |
| Fragmentos **fieles** (evaluación humana) | **0/7 (0%)** |
| Fragmentos **parcialmente útiles** | 3/7 (42.9%) |
| Fragmentos **no fieles** | 4/7 (57.1%) |

Estos números son consistentes con los de la Fase 2 (`PRISMA_REAL_INGESTION_GAP_REPORT.md`: 0% fiel, 44.4% parcial, 55.6% no fiel) — la brecha de ingesta no es un artefacto de un solo documento, se reproduce en un dominio de texto real completamente distinto (fact patterns de examen vs. texto estatutario).

---

## 3. Hallazgo clave: el mismo bug del símbolo `\$` se reproduce en una fuente independiente

La pregunta sobre modificación de contrato (`mbe_q18_contract_modification`, real doctrina UCC/consideration sobre un contrato de construcción de $100 millones) fue clasificada — otra vez — como `FinancialRiskAssessment`/`EvaluateCreditEligibility`, exactamente el mismo falso positivo documentado en la Fase 2, y por la misma razón: el patrón financiero dispara con cualquier `\$` en el texto, sin importar el dominio real. Esta es una confirmación independiente de que el bug no es un caso aislado — es sistemático en cualquier texto legal real que mencione una cifra en dólares, que es extremadamente común en derecho contractual, de daños, y probatorio.

Las otras dos preguntas (autodefensa penal, hearsay/jurado investigador) cayeron al fallback genérico, con el mismo patrón de la Fase 2: sujeto temáticamente razonable en las oraciones declarativas ("Father", "Defendant"), pero sujeto sin sentido en las oraciones interrogativas ("Trial" de "At trial...", "Should" de "How should the court rule..." — el heurístico de "primera palabra ≥4 letras" no distingue preguntas de afirmaciones).

---

## 4. Qué NO mide este reporte

Este reporte **no** evalúa si PRISMA puede seleccionar la respuesta correcta entre las 4 opciones de cada pregunta (C, D, B respectivamente según la clave oficial del NCBE). El motor no tiene hoy una capacidad de razonamiento comparativo multiple-choice — construir una demo que "eligiera una opción" sin esa capacidad real habría producido exactamente el tipo de número autoevaluado y engañoso que este roadmap existe para eliminar. Lo que se mide aquí es estrictamente lo mismo que en la Fase 2: extracción de texto real → Facts estructurados, usando la misma metodología para que ambos reportes sean directamente comparables.

---

## 5. Addendum (2026-07-31): fix aplicado y re-verificado

Mismo fix que en `PRISMA_REAL_INGESTION_GAP_REPORT.md` (se quitó `\$` como disparador financiero aislado en `slm_extractor.py`). Re-ejecutado `scratch/external_examset_eval.py` sobre las mismas 3 preguntas:

| | Antes del fix | Después del fix |
| :--- | :-: | :-: |
| Fiel | 0/7 (0%) | 0/7 (0%) |
| Parcial | 3/7 (42.9%) | **5/7 (71.4%)** |
| No fiel | 4/7 (57.1%) | **2/7 (28.6%)** |

Los 3 fragmentos de la pregunta de modificación de contrato ya no se clasifican como riesgo crediticio — ahora extraen `Company`/`Builder` (partes reales del contrato) en vez de `ApplicantRecord`. Los 2 casos "no fiel" restantes (`Trial`, `Should`) son del mismo patrón encontrado en el reporte de ingesta: el heurístico de "primera palabra ≥4 letras" agarra palabras interrogativas/procesales en oraciones que son preguntas, no afirmaciones — un problema distinto, no relacionado con el bug del `\$`.

## 6. Línea base para futuras verificaciones

Estos dos reportes (Fase 2 + Fase 3) juntos dan una **línea base reproducible**: 16 fragmentos de texto legal real evaluados (9 + 7), de 3 fuentes independientes (estatuto, regla procesal, exámenes de la barra), con **0% de extracción fiel** y un bug sistemático identificado (`\$` como disparador financiero aislado). Cualquier cambio futuro al extractor (`slm_extractor.py`) debe re-ejecutar `scratch/real_document_ingestion_eval.py` y `scratch/external_examset_eval.py` sobre el mismo material y comparar contra estos números — no contra una suite nueva, para que la comparación sea válida.
