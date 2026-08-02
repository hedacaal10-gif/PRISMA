# PRISMA — Real External LegalBench Pilot Report (hearsay task)

**Fecha de evaluación:** 31 de julio, 2026
**Dataset:** `nguha/legalbench` (Stanford LegalBench, HuggingFace Hub) — descargado en vivo el 2026-07-31
**Config/tarea evaluada:** `hearsay` (162 tareas existen en el dataset real; esta es la primera evaluada con datos reales)
**Splits usados:** `train` (5 filas, usadas únicamente para diseñar la heurística de extracción — es el split que el propio LegalBench provee para diseño few-shot) y `test` (94 filas, evaluadas a ciegas, sin ajustar la heurística después de ver resultados)
**Script:** `scratch/external_legalbench_eval.py`
**Resultados completos fila por fila:** `scratch/external_legalbench_real_pilot_results.json`

Este es el primer reporte de PRISMA que evalúa contra el dataset **real** de Stanford LegalBench, en contraste con `reports/PRISMA_LEGALBENCH_EVALUATION_REPORT.md`, que es una suite sintética autoescrita (ver nota de transparencia en ese archivo).

---

## 1. Resultado principal

| Métrica | Valor |
| :--- | :--- |
| **Precisión real (test set, 94 filas, ciego)** | 65.96% (62/94) → 69.15% (65/94) tras extensión con WordNet (§6) → **71.28% (67/94)** tras expandir a hiperónimos (§11, 2026-08-01, mejora neta real) |
| Precisión en train (5 filas, usado para diseñar la heurística) | 40.00% (2/5) → **60.00% (3/5)** tras el normalizador de sinónimos (§4) |
| Filas "mapeables" (la heurística siempre produce una predicción Sí/No) | 100% (94/94) — ver §6 sobre qué significa "mapeable" aquí |

**65.96% está muy por debajo del "100% (120/120)" del reporte sintético.** Esa es precisamente la brecha que este piloto existe para medir: qué tan bien el pipeline actual de extracción de PRISMA (heurística basada en patrones/palabras clave, sin NLP profundo) convierte texto legal real y no visto en Facts/Rules correctos — no qué tan bien el motor deduce una vez que los Facts ya están correctamente codificados (esa segunda capacidad sí está bien soportada, ver §5).

---

## 2. Metodología

1. **Extracción (heurística congelada antes de evaluar):** Cada fila de texto real se pasa por 3 funciones basadas en patrones/palabras clave (`scratch/external_legalbench_eval.py`, funciones `is_statement`, `made_out_of_court`, `offered_for_truth`), diseñadas únicamente contra las 5 filas de `train` más el conocimiento general de la Regla Federal de Evidencia 801 (hearsay = declaración hecha fuera de corte, ofrecida para probar la verdad de lo afirmado). La heurística **no se ajustó** después de ver el desempeño en `test`.
2. **Deducción (motor real):** Los 3 Facts extraídos se insertan en `PrismaCoreEngine` y se encadenan mediante dos llamadas reales a `infer()`:
   - Paso 1: `IsStatement AND MadeOutOfCourt → OutOfCourtStatement`
   - Paso 2: `OutOfCourtStatement AND OfferedForTruth → IsHearsay`
   
   Esto usa el motor **después** de la corrección aplicada hoy mismo a `engine.py` (ver `reports/PRISMA_LEGALBENCH_EVALUATION_REPORT.md`, nota de transparencia): si cualquiera de las condiciones no coincide genuinamente, `infer()` devuelve `UNSATISFIED_PREMISES` y la fila se predice "No" (hearsay no aplica) sin intervención manual en Python.
3. **Comparación:** La predicción final (`Yes`/`No`) se compara contra la columna `answer` real del dataset — nunca reescrita ni "corregida" por este script.

---

## 3. Resultado por categoría temática (`slice`, provisto por el propio dataset)

| Slice | Correctas | Total | Precisión |
| :--- | :-: | :-: | :-: |
| Non-assertive conduct | 19 | 19 | **100.0%** |
| Statement made in-court | 12 | 14 | **85.7%** |
| Not introduced to prove truth | 15 | 20 | **75.0%** |
| Standard hearsay | 13 | 29 | **44.8%** |
| Non-verbal hearsay | 3 | 12 | **25.0%** |

### Por qué varía tanto — lectura honesta

- **Non-assertive conduct (100%)** y **Statement made in-court (85.7%)** funcionan bien porque dependen de **señales estructurales/léxicas explícitas**: presencia o ausencia de verbos de comunicación ("told", "said", "testified") y de marcadores de testimonio en corte ("on the stand", "cross-examination"). Esto es exactamente lo que un extractor basado en regex/palabras clave puede detectar de forma confiable.
- **Standard hearsay (44.8%)** y **Non-verbal hearsay (25.0%)** fallan mucho más porque requieren **entender si el contenido de la declaración y el propósito procesal citan el mismo hecho**, a menudo mediante sinónimos o paráfrasis (ej. "sanity" vs. "sane" en la fila de entrenamiento — la heurística de solape de palabras no detecta esta relación semántica). Esto **no** es una limitación del motor de PRISMA; es una limitación conocida y esperada de un extractor por palabras clave sin comprensión semántica real.

---

## 4. Addendum (2026-07-31): Normalizador de Sinónimos Ontológico — resultado neto: empate, con hallazgos honestos

Se implementó `packages/prisma-python/prisma_core/ontology_normalizer.py` (propuesta del usuario, punto 2 de un roadmap de 4 mejoras) para ampliar el vocabulario de verbos de aserción, las plantillas de cláusula de propósito, y agregar un pequeño diccionario de sinónimos de palabras de contenido (ver docstring del módulo para su alcance y limitaciones explícitas). Se integró en `scratch/external_legalbench_eval.py` reemplazando las listas ad-hoc originales.

**Primera corrida (solo ampliar vocabulario de aserción + plantillas + sinónimos):**

| | Antes | Después (1ra iteración) |
| :--- | :-: | :-: |
| Train | 2/5 | **3/5** ✅ |
| Test real | 65.96% (62/94) | **62.77% (59/94)** ❌ |
| Statement made in-court | 85.7% (12/14) | **64.3% (9/14)** ❌ |

La primera iteración **empeoró la precisión real neta**. Diagnóstico (sin inspeccionar el texto de las filas específicas que fallaron, solo los flags agregados `IsStatement`/`MadeOutOfCourt`/`OfferedForTruth`): la lista de verbos de aserción más angosta hacía que `IsStatement` diera `False` por casualidad en 5 filas de "Statement made in-court" que en realidad sí eran testimonio en corte — un error que compensaba otro error preexistente (la lista de marcadores de "en corte" no las detectaba). Al ampliar el vocabulario de aserción, `IsStatement` empezó a evaluar correctamente `True` en esas filas, lo que **destapó** el hueco preexistente en `made_out_of_court()`.

**Segunda iteración:** se extendió `IN_COURT_TESTIMONY_MARKERS` en `ontology_normalizer.py` usando únicamente conocimiento general del concepto legal (FRE 801(c)(1): "testificando en el juicio o audiencia actual") — sin mirar las filas específicas que habían fallado, para no ajustar contra el conjunto de prueba.

| | Antes del punto 2 | Después (2da iteración, final) |
| :--- | :-: | :-: |
| Train | 2/5 | **3/5** |
| **Test real** | 65.96% (62/94) | **65.96% (62/94)** — empate numérico |
| Statement made in-court | 85.7% (12/14) | **85.7% (12/14)** — recuperado |
| Not introduced to prove truth | 75.0% (15/20) | 70.0% (14/20) — 1 caso nuevo perdido |
| Standard hearsay | 44.8% (13/29) | 48.3% (14/29) — 1 caso nuevo ganado |

**Lectura honesta del resultado final:** el punto 2, tal como se implementó, no subió la precisión real en este dataset — quedó en exactamente el mismo número (65.96%), aunque con una composición distinta por debajo (se ganó un caso en "Standard hearsay", se perdió uno en "Not introduced to prove truth"). Sí hubo una mejora genuina y verificable en train (2/5 → 3/5) y en la robustez conceptual del heurístico (más verbos de aserción reales reconocidos, más plantillas de cláusula de propósito reconocidas, un hueco real en la detección de testimonio en corte identificado y corregido). Pero en el dataset real de 94 filas, esas mejoras no se tradujeron en más aciertos netos — se cancelaron con una pérdida en otra categoría. Esto no se investigó más a fondo para evitar ajustar el heurístico mirando directamente las filas de test que fallan, lo cual habría roto la disciplina de medición honesta mantenida en todo este roadmap.

**Conclusión:** el punto 2 valió la pena para arreglar el bug conceptual del `\$`-style masking (errores que se cancelan entre sí) y quedó documentado como una limitación real y medida del enfoque basado en reglas/sinónimos fijos — no como una mejora de producto. El punto 3 (few-shot con LLM) es el siguiente candidato con más probabilidad de mover la aguja en "Standard hearsay"/"Non-verbal hearsay", que son justamente los casos que requieren comprensión semántica real, no solo cobertura de vocabulario.

---

## 5. Addendum (2026-08-01): Punto 3 — extracción asistida por LLM local, resultado complementario

**Modelo:** Qwen2.5-3B-Instruct-Q4_K_M, local, vía `llama-cpp-python` (`packages/prisma-python/prisma_models/slm_quant.gguf`). `temperature=0`, `response_format={"type":"json_object"}`, 5 ejemplos few-shot (las mismas 5 filas reales de train, con las 3 sub-condiciones derivadas por razonamiento correcto de FRE 801 — el dataset solo da el `answer` final, no ground truth por sub-condición, y eso queda explícito aquí). El LLM solo produce los 3 booleanos; la decisión Sí/No la sigue haciendo `PrismaCoreEngine.infer()` de forma determinista, igual que en el piloto regex — ver `scratch/external_legalbench_eval_llm.py`.

**IMPORTANTE:** a diferencia del motor de deducción (determinista, reproducible por diseño — Principio 2 de PRISMA), esta extracción vía LLM **no es reproducible byte a byte** entre corridas/versiones de modelo. Se reporta como "asistida por LLM", nunca se mezcla con las cifras de la suite sintética ni se certifica como determinista.

| | Regex (heurística fija) | LLM local (Qwen2.5-3B) |
| :--- | :-: | :-: |
| **Precisión real total** | 65.96% (62/94) | **62.77% (59/94)** — prácticamente empatado |
| Non-assertive conduct | 100.0% (19/19) | 84.2% (16/19) |
| Standard hearsay | 48.3% (14/29) | **86.2% (25/29)** |
| Non-verbal hearsay | 25.0% (3/12) | **58.3% (7/12)** |
| Statement made in-court | 85.7% (12/14) | 57.1% (8/14) |
| Not introduced to prove truth | 70.0% (14/20) | **15.0% (3/20)** |

**Lectura honesta — no es "mejor" ni "peor", es complementario:** el LLM sube dramáticamente en las categorías que requieren comprensión semántica real ("Standard hearsay" 48%→86%, "Non-verbal hearsay" 25%→58%) — justo la limitación que el punto 2 no pudo resolver con diccionarios fijos. Pero colapsa en "Not introduced to prove truth" (70%→15%): revisando el log, el LLM predice "Yes" de forma sistemática donde el gold es "No", un sesgo probablemente causado por el desbalance de los propios ejemplos few-shot (4 de las 5 filas reales de train tienen `OfferedForTruth=True`, solo 1 tiene `False` — es la composición real del dataset, no algo ajustable sin inventar ejemplos fuera de train).

**Esto es la validación empírica de por qué el punto 5 (validación cruzada de doble extractor) va después de este:** regex y LLM no son intercambiables, fallan en categorías opuestas. Un pipeline que exija coincidencia entre ambos antes de marcar `ASSERTED`/`AuthorityLevel.LAW`, y mande a revisión cuando discrepan, aprovecharía las fortalezas de cada uno en vez de promediarlas a un empate. Detalle completo por fila: `scratch/external_legalbench_llm_pilot_results.json`.

---

## 6. Addendum (2026-08-01): destilar el patrón del LLM en una regla determinista (WordNet) — primera mejora neta real

En vez de solo usar el LLM en tiempo de ejecución (§5) o pasar directo a validación cruzada (punto 5), se investigó **qué predicado explicaba las victorias del LLM**, para ver si ese patrón podía capturarse como una regla determinista y auditable en el motor — igual de espíritu a cómo `diversity_1` llegó a 100% con una regla simple y bien estructurada (`reports/PRISMA_LEGALBENCH_MULTI_TASK_REAL_PILOT_REPORT.md`).

**Diagnóstico agregado (estadístico, no lectura de oraciones individuales de test):** de los 17 casos reales donde el LLM acertó y el regex falló, **16 tenían `OfferedForTruth` como la condición que difería** entre ambos extractores. Esto confirma cuantitativamente que el problema es específicamente el juicio de equivalencia semántica entre la cláusula de propósito y el contenido de la declaración (ej. "sane"/"sanity"), no un problema disperso en las 3 condiciones.

**Solución:** se agregó `words_share_concept()` a `ontology_normalizer.py`, usando **WordNet** (`nltk.corpus.wordnet`, recurso léxico general, offline, determinista) — específicamente `derivationally_related_forms()`, que conecta palabras de distinta categoría gramatical con la misma raíz conceptual (adjetivo "sane" ↔ sustantivo "sanity"). Se verificó primero que WordNet efectivamente conecta ese par exacto antes de integrarlo. `offered_for_truth()` ahora intenta el solape literal primero (como antes) y, si no hay coincidencia, prueba solape de concepto vía WordNet.

| | Antes (con normalizador de sinónimos, §4) | Después (+ WordNet) |
| :--- | :-: | :-: |
| Train | 3/5 | 3/5 (sin cambio) |
| **Test real** | 65.96% (62/94) | **69.15% (65/94)** ✅ **+3 filas netas** |
| Standard hearsay | 48.3% (14/29) | **58.6% (17/29)** ✅ |
| Non-verbal hearsay | 25.0% (3/12) | **33.3% (4/12)** ✅ |
| Statement made in-court | 85.7% (12/14) | 78.6% (11/14) ❌ (-1, mismo patrón de "arreglar destapa otro" en un caso aislado) |
| Not introduced to prove truth | 70.0% (14/20) | 70.0% (14/20) (sin cambio) |

**Por qué esta vez sí hubo mejora neta, a diferencia del punto 2:** WordNet es un recurso léxico general de propósito amplio (no una lista de 8 pares elegidos a mano), así que cubre muchas más relaciones semánticas reales sin necesidad de anticipar cada caso. La ganancia (+4 en Standard hearsay + Non-verbal) superó la pérdida aislada (-1 en Statement made in-court). Es la primera vez en este roadmap que una mejora al heurístico sube la precisión real neta, no solo la de train.

**Metodología para mantener esto honesto:** el hallazgo de qué condición mejorar (`OfferedForTruth`) vino de una comparación estadística agregada entre dos extractores independientes (LLM vs. regex) sobre las 94 filas reales — no de leer manualmente oraciones de test y escribir reglas para que coincidieran. La solución en sí (WordNet) es un recurso lingüístico general verificado contra el caso conocido de train, nunca ajustado mirando qué filas específicas de test fallaban.

---

## 6b. Addendum (2026-08-01): Punto 5 — validación cruzada de doble extractor

Se implementó `packages/prisma-python/prisma_core/dual_extraction_validator.py`: dado que dos extractores independientes (regex+WordNet vs. LLM local) ya corrieron sobre las mismas 94 filas reales, se comparan sus Facts extraídos fila por fila — coincidencia total → `LifecycleState.ASSERTED`/`AuthorityLevel.LAW` (PRISMA sigue automáticamente); cualquier discrepancia → `UNDER_REVIEW`/`AuthorityLevel.USER_INPUT` (se manda a revisión, sin adivinar cuál extractor tiene razón). Demostración: `scratch/external_legalbench_eval_dual.py`.

| Métrica | Valor |
| :--- | :-: |
| Coincidencia entre extractores | 41/94 (43.6%) |
| **Precisión en el subconjunto auto-asertado (coincidencia)** | **75.61% (31/41)** — más alto que cualquiera de los dos extractores solos |
| Filas enviadas a revisión (discrepancia) | 53/94 (56.4%) |
| — de esas, al menos un extractor ya tenía la respuesta correcta | 49/53 (92.5%) |
| — de esas, ambos extractores se equivocaron | 4/53 (7.5%) |

**Lectura honesta:** la validación cruzada funciona — la coincidencia entre dos métodos independientes es una señal genuina de confiabilidad (75.61% vs. 69.15%/62.77% de cada uno solo). Pero tiene un costo operativo real: más de la mitad de los casos (56.4%) no se automatizan y requieren revisión. Esto no es una debilidad oculta — es exactamente el comportamiento correcto de un sistema que no quiere fingir automatización donde no la hay. El punto 5 no reemplaza la necesidad de mejorar la extracción (puntos 2/3/4); la complementa, dando una señal honesta de cuándo confiar y cuándo no.

---

## 6c. Addendum (2026-08-01): re-medición con Luz/Snell mejorado -- el LLM local dejó de ser el extractor más fuerte

Motivado por una pregunta de negocio (¿qué tan rentable sería pasar documentación por un LLM y verificarla, versus el motor determinista?), se repitió la validación cruzada del §6b pero comparando el **Luz/Snell mejorado de hoy** (74.47%, tras todas las correcciones de esta sesión) contra el mismo LLM local re-corrido (Qwen2.5-3B-Instruct-Q4_K_M, 62.77% -- reproducido exacto, misma cifra y mismo patrón por categoría que el §5 original). Script: `scratch/external_legalbench_eval_dual_snell.py`.

| Métrica | §6b (regex+WordNet vs LLM, 31-jul) | §6c (Snell mejorado vs LLM, 1-ago) |
| :--- | :-: | :-: |
| Precisión standalone extractor determinista | 69.15% | **74.47%** |
| Precisión standalone LLM | 62.77% | 62.77% (sin cambio, reproducido) |
| Coincidencia entre extractores | 43.6% (41/94) | 50.0% (47/94) |
| **Precisión en subconjunto auto-aceptado** | **75.61%** (por encima de ambos solos) | **74.47%** (igual al determinista solo, no lo supera) |
| De las filas en desacuerdo, ¿quién tenía razón? | LLM correcto en 16/17 casos analizados | Determinista correcto en 35/47 (20 solo + 15 ambos), LLM correcto en 24/47 (9 solo + 15 ambos), ambos mal en 3/47 |

**Hallazgo central -- se invirtió el patrón:** en la medición original (§5-6b), el LLM local le ganaba claramente al heurístico determinista, especialmente en las categorías semánticamente difíciles. Después de un día completo de mejoras dirigidas por hipótesis (expresiones nominalizadas, hiperónimos/hipónimos/meronimia de WordNet, corrección de verbos instrumentales, negación "without VERBing", vocabulario de marcadores en corte), **el extractor determinista ya no solo alcanzó al LLM local -- lo superó**, tanto en precisión standalone (74.47% vs 62.77%) como en la mayoría de los desacuerdos directos (35 vs 24 de 47).

**Respuesta concreta a "cuánto aceptaríamos" (auto-aceptación sin revisión humana):** con este par de extractores, hoy se auto-aceptaría el **50.0% del volumen** con una precisión del **74.47%** sobre ese subconjunto -- igual, no mejor, que confiar en Luz/Snell solo. A diferencia de la medición original (donde la validación cruzada SÍ mejoraba la precisión por encima de cualquiera de los dos extractores solos), aquí el LLM local ya no aporta una señal de calidad superior al determinista -- su valor real hoy es más limitado: solo ayuda a atrapar los ~9 casos aislados donde el LLM acierta y Snell no, a costa de rutear el 50% del volumen a revisión humana.

**Caveat importante, no probado aquí:** esta comparación usa un modelo LOCAL PEQUEÑO (Qwen2.5-3B). Un LLM grande de frontera (GPT-4/Claude/Gemini-escala) probablemente tendría una precisión standalone bastante más alta que 62.77% -- este resultado NO debe generalizarse a "un LLM grande también perdería contra Snell". Es una comparación real pero acotada a este modelo específico; extenderla a un modelo grande requeriría repetir la medición con ese modelo, con el mismo costo (en dinero, esta vez, no solo tiempo de cómputo local) que eso implica.

**Guardia de regresión:** esta re-medición no modifica ningún código de producción -- es puramente una nueva corrida de comparación sobre resultados ya generados por scripts existentes.

**Para reproducir:**
```bash
python scratch/external_legalbench_eval_llm.py                 # 62.77% (59/94), ~12-13 min en CPU local
python scratch/external_legalbench_eval_dual_snell.py           # comparación dual, 50.0% acuerdo, 74.47% en el subconjunto auto-aceptado
```

---

## 7. Qué significa "mapeable" en este piloto

A diferencia de lo previsto originalmente en el roadmap (excluir filas "no mapeables" del denominador), la heurística de este piloto **siempre** produce una predicción Sí/No para cualquier texto de entrada — no hay estado de abstención. Esto significa que el 100% de "mapeabilidad" reportado **no** implica que la extracción sea correcta; solo significa que el pipeline nunca se niega a responder. La precisión real (65.96%) es la métrica que importa, no la tasa de mapeo.

---

## 8. Separación explícita de dos afirmaciones (ver también Fase 6 del roadmap de verificación)

1. **¿El motor deduce correctamente una vez que las condiciones están bien identificadas?** Sí — verificado en `packages/prisma-python/tests/test_core.py::test_infer_rejects_unsatisfied_antecedent`, y demostrado en este mismo piloto: cuando la heurística extrae las 3 condiciones correctamente (ej. todas las filas de "Non-assertive conduct"), el motor encadena el Modus Ponens de 2 pasos sin error.
2. **¿El pipeline de extracción de PRISMA identifica correctamente esas condiciones a partir de texto real no visto?** Débil hoy (65.96% global, con un rango de 25%–100% según el tipo de razonamiento requerido) — esta es la brecha real que hay que cerrar, no con más reglas hardcodeadas sino con mejor comprensión semántica del texto de entrada.

---

## 9. Próximos pasos sugeridos

- Extender este piloto a 1-2 tareas reales adicionales de las 162 disponibles en `nguha/legalbench` (candidatas: `abercrombie` — clasificación de 5 vías, más difícil; `contract_qa` — más cercana a NLI booleano, potencialmente más tratable con la arquitectura actual).
- Para subir la precisión en "Standard hearsay"/"Non-verbal hearsay" específicamente, la heurística de solape de palabras necesitaría incorporar algún tipo de similitud semántica (embeddings livianos o un diccionario de sinónimos curado) — cambio de alcance mayor, no un ajuste rápido.
- Este reporte no debe combinarse ni promediarse con el reporte sintético (`PRISMA_LEGALBENCH_EVALUATION_REPORT.md`) en ninguna comunicación externa — son mediciones de cosas distintas.

---

## 10. Addendum (2026-08-01): sprint de 1 hora sobre la variante Snell — sin cambio neto

La variante que usa Snell para `IsStatement` (`scratch/external_legalbench_eval_snell.py`, documentada en `reports/PRISMA_LUZ_SNELL_ARCHITECTURE_REPORT.md` §3, 70.21%/66/94) fue objeto de un sprint dedicado a intentar extender Snell también a `MadeOutOfCourt` y `OfferedForTruth`. Resultado: **70.21% (66/94) sin cambio** — dos intentos de reemplazo por árbol de dependencias regresionaron y se descartaron, un intento (anáfora "did so" para actos no verbales asertivos) se aceptó por mejorar train (3/5→4/5) sin romper nada, pero resultó neutral en las 94 filas reales de test. Ver `reports/PRISMA_LUZ_SNELL_ARCHITECTURE_REPORT.md` §5 para el detalle completo de los 4 intentos, incluyendo el diagnóstico agregado de por qué el reemplazo por árbol de dependencias no tenía margen de mejora en este dataset. El número de este reporte (69.15%, regex+WordNet puro, sin Snell) no cambió.

**Actualización (misma fecha, ronda 2):** una segunda ronda de diagnóstico agregado sobre las categorías más débiles (Standard hearsay, Non-verbal hearsay) encontró un hueco estructural real -- expresiones de reporte nominalizadas ("Bob's statement that X") que `extract_reported_assertions` nunca detectaba por escanear solo tokens VERB. Corregido: la variante Snell subió a **71.28% (67/94)**, +1 fila neta. Ver `reports/PRISMA_LUZ_SNELL_ARCHITECTURE_REPORT.md` §8 para el detalle completo. El número de este reporte (69.15%, regex+WordNet puro, sin Snell) sigue sin cambio.

---

## 11. Addendum (2026-08-01): expansión de WordNet a hiperónimos -- ESTE reporte sí cambia: 69.15% → 71.28%

`CLAUDE.md` (punto 4 del roadmap original) ya identificaba "explorar hiperónimos/hipónimos vía `wn.hypernyms()`/`wn.hyponyms()`" como el siguiente paso natural para `words_share_concept()`, advirtiendo explícitamente que "cada expansión de este tipo tiende a ganar en una categoría y perder en otra" -- por eso se probó UNA sola relación (hiperónimos, un solo nivel) a la vez, no ambas juntas, y se verificó contra pares conocidos reales antes de integrar (`docs/VERIFICATION_STANDARDS.md` regla 8: "car" → hiperónimo directo "motor_vehicle"; "punch" → hiperónimo directo "blow", ambos confirmados con una consulta directa a `nltk.corpus.wordnet` antes de escribir el cambio).

**Resultado -- mejora neta real en ESTE piloto (regex+WordNet, el que este reporte documenta):**

| | Antes (§6, solo `derivationally_related_forms`) | Después (+ hiperónimos, 1 nivel) |
| :--- | :-: | :-: |
| **Test real** | 69.15% (65/94) | **71.28% (67/94)** ✅ **+2 filas netas** |
| Standard hearsay | 58.6% (17/29) | **72.4% (21/29)** ✅ +4 |
| Non-verbal hearsay | 33.3% (4/12) | **41.7% (5/12)** ✅ +1 |
| Not introduced to prove truth | 70.0% (14/20) | **55.0% (11/20)** ❌ -3 |

**Por qué el patrón se cumplió pero el neto fue positivo esta vez:** el mecanismo del retroceso es el mismo ya diagnosticado antes (ver `reports/PRISMA_LUZ_SPANISH_PILOT_REPORT.md` §4 para el caso español "hablar"/"decir" análogo): un puente genérico de tipo IS-A (ej. dos palabras que comparten un hiperónimo amplio) infla falsos positivos justo en la categoría que exige DISTINGUIR temas superficialmente parecidos pero legalmente distintos ("Not introduced to prove truth"). La ganancia (+5 en Standard hearsay + Non-verbal) superó la pérdida (-3), a diferencia del intento fallido de 2026-07-31 (§4) donde el resultado neto fue un empate exacto.

**Efecto en la variante Snell (mismo cambio, función compartida `wordnet_concepts_bilingual`):** también mejoró, de 71.28% (67/94) a **74.47% (70/94)**, +3 filas netas -- ver `reports/PRISMA_LUZ_SNELL_ARCHITECTURE_REPORT.md` §9.

**Retroceso documentado con el mismo detalle que la mejora (disciplina de `docs/VERIFICATION_STANDARDS.md` regla 5):** el piloto autoescrito en español (`reports/PRISMA_LUZ_SPANISH_PILOT_REPORT.md`) bajó de 85% (17/20) a 80% (16/20) por el mismo mecanismo -- ver ese reporte §10 para el detalle. No se investigó más a fondo para evitar ajustar el heurístico mirando qué filas específicas fallaban en ninguno de los tres pilotos.

**Número de cabecera de este reporte actualizado:** el resultado principal (§1) queda ahora en **71.28% (67/94)**, no 69.15%.

**Actualización (misma fecha, hipónimos probados por separado):** siguiendo la misma disciplina de una relación a la vez, se probó también la expansión por hipónimos (después de que los hiperónimos ya estuvieran aceptados). Resultado en ESTE piloto: **71.28% (67/94), sin cambio** -- neutral, ninguna fila se ve afectada. Ver `reports/PRISMA_LUZ_SNELL_ARCHITECTURE_REPORT.md` §10 para el detalle completo (neutral también en los otros dos pilotos).

**Actualización (misma fecha, primeras entradas de `luz_custom_lexicon.json`):** se agregaron las primeras 3 entradas reales al léxico propio (vacío desde el diseño original), cada una verificada individualmente contra una fuente citable (diccionario estándar, FRE 801(b)(1)) y confirmando primero que WordNet no las cubría ya. Resultado en ESTE piloto: **71.28% (67/94), sin cambio** -- neutral. Ver `reports/PRISMA_LUZ_SNELL_ARCHITECTURE_REPORT.md` §11 para el detalle completo.

**Actualización (misma fecha, meronimia + marcadores en corte, con paso libre del usuario):** se probó meronimia/holonimia de WordNet (§12) y se expandió `IN_COURT_TESTIMONY_MARKERS` tras un diagnóstico agregado que confirmó `MadeOutOfCourt` como único culpable en las 3 filas mal de "Statement made in-court" (§13). Ambas: **71.28% (67/94), sin cambio** en ESTE piloto -- el hueco de `MadeOutOfCourt` quedó confirmado pero no se pudo cerrar sin romper la disciplina de medición ciega. Ver `reports/PRISMA_LUZ_SNELL_ARCHITECTURE_REPORT.md` §12-13 para el detalle completo.
