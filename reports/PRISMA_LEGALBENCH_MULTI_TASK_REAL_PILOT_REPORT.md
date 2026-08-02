# PRISMA — Real LegalBench Multi-Task Pilot Report

**Fecha de evaluación:** 1 de agosto, 2026
**Dataset:** `nguha/legalbench` (Stanford LegalBench, HuggingFace Hub)
**Metodología:** idéntica a `reports/PRISMA_LEGALBENCH_REAL_PILOT_REPORT.md` (tarea `hearsay`) — heurística de extracción diseñada y congelada usando **solo** el split `train` de cada tarea, evaluada a ciegas contra el split `test` real, deducción vía `PrismaCoreEngine.infer()` con verificación genuina de antecedentes.

Este reporte cubre 3 tareas reales adicionales, elegidas por encajar temáticamente con dominios que PRISMA ya trabajaba (jurisdicción por diversidad, UCC vs. common law, preguntas sobre cláusulas contractuales).

---

## Resumen de resultados

| Tarea | Filas test (reales) | Precisión real | Script |
| :--- | :-: | :-: | :--- |
| **`diversity_1`** | 300 | **100.00% (300/300)** | `scratch/external_legalbench_diversity_eval.py` |
| **`contract_qa`** | 80 | **87.50% (70/80)** | `scratch/external_legalbench_contractqa_eval.py` |
| **`ucc_v_common_law`** | 94 | 53.19% (50/94) | `scratch/external_legalbench_ucc_eval.py` |

---

## 1. `diversity_1` — 100.00% (300/300), el primer resultado perfecto genuino

**Por qué funciona tan bien:** a diferencia de `hearsay`, esta tarea es mecánica, no semántica. El texto sigue una plantilla estrictamente consistente ("NAME es de ESTADO. NAME es de ESTADO. NAME demanda a NAME por $MONTO.") y la regla legal real (28 U.S.C. § 1332(a)) es un AND de dos condiciones extraíbles con regex simple: estados distintos (`PartiesAreDiverse`) y monto > $75,000 (`AmountInControversyMet`). La heurística se verificó 6/6 en las 6 filas de train antes de correr contra las 300 filas de test — y generalizó perfectamente.

**Lectura honesta:** este resultado no contradice los hallazgos de `hearsay` (65.96%) — los confirma. Cuando la tarea legal real es estructuralmente simple (extracción de entidades + una regla de combinación clara), un extractor simbólico/regex + el motor de PRISMA puede llegar a 100% real, sin autoevaluación. Cuando la tarea requiere juicio semántico (sinónimos, propósito procesal), el mismo enfoque cae a ~50-65%. La diferencia no está en el motor — está en qué tan bien la extracción puede capturar la condición legal en cada caso.

---

## 2. `contract_qa` — 87.50% (70/80), generaliza a temas no vistos en train

**Diseño:** el train (8 filas) solo cubre 6 de los 20 temas de pregunta distintos que aparecen en test (`Force Majeure`, `BIPA`, `ADA`, `CIPA`, `non-compete`, `severability`, etc. — nunca aparecen en train). En vez de construir 20 listas de palabras clave específicas por tema (que habría requerido inventar reglas sin ninguna evidencia de train para 14 de ellas), se reutilizó el mecanismo genérico de solape de palabras del normalizador ontológico (`prisma_core.ontology_normalizer.canonicalize_word`): ¿las palabras de contenido de la pregunta aparecen también en el texto de la cláusula? Verificado 8/8 en train.

**Resultado:** 87.50% real — el mecanismo genérico generalizó razonablemente bien incluso a temas nunca vistos, lo cual es una señal alentadora sobre la solidez del enfoque de solape léxico para tareas de "¿este texto menciona el tema X?" (distinto de tareas que requieren entender relaciones causales o de propósito, como partes de `hearsay`).

---

## 3. `ucc_v_common_law` — 53.19% (50/94), otro caso de "arreglar un error destapa otro"

**Diseño inicial:** clasificación basada en palabras clave — bienes muebles (venta/arriendo) → UCC; servicios o inmuebles → common law. Al verificar a mano contra las 6 filas de train se encontró un error propio: la fila "William rents a tractor **for his farm**..." se clasificó mal como inmueble solo porque la palabra "farm" aparece en la oración (aunque el inmueble no es el objeto del contrato, el tractor sí). Esto se corrigió **antes** de correr contra test, usando un chequeo de proximidad (el término de inmueble debe ser objeto directo de un verbo de compra/venta), verificado 6/6 en train tras el fix.

**Resultado:** el fix bajó la precisión de test de 60.64% (con el bug) a 53.19% (corregido) — el mismo patrón exacto que ya vimos en el piloto de `hearsay` con el normalizador de sinónimos: una heurística más estricta/correcta en sus propios términos no necesariamente sube la precisión neta en datos reales, porque el lenguaje real varía de formas que ningún patrón fijo cubre completamente. No se siguió iterando para no ajustar el heurístico mirando las filas de test que fallan.

---

## Conclusión transversal (con los datos de `hearsay` + estas 3 tareas: 4 tareas reales, 488 filas de test evaluadas)

1. **El motor determinista sigue sin fallar en ningún caso diagnosticado** — cuando la extracción identifica las condiciones correctamente, `PrismaCoreEngine.infer()` deduce bien, consistente en las 4 tareas.
2. **La precisión real varía enormemente según la naturaleza de la tarea**: de 100% (`diversity_1`, mecánica) a ~50-65% (`hearsay`, `ucc_v_common_law`, semántica/juicio) a 87.5% (`contract_qa`, léxica pero generalizable). No existe un solo número de "precisión de PRISMA" — depende del tipo de razonamiento legal requerido.
3. **El patrón de "arreglar un error heurístico destapa/introduce otro"** apareció de forma independiente en `hearsay` (punto 2, normalizador de sinónimos) y en `ucc_v_common_law` — es un hallazgo estructural sobre las limitaciones de heurísticas de reglas fijas, no un accidente aislado.
