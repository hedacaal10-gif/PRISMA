# PRISMA -- Piloto de hearsay en español (Luz/Snell)

> ⚠️ **AVISO DE TRANSPARENCIA -- LEER ANTES DE CUALQUIER NÚMERO DE ESTE REPORTE.** Este reporte evalúa contra `scratch/prisma_spanish_hearsay_dataset.json`, un conjunto de 20 filas **autoescrito íntegramente por el equipo de PRISMA** -- NO el dataset real `nguha/legalbench` (que es solo inglés), ni ningún otro dataset externo publicado. No existe hoy ningún dataset real en español para esta tarea en ningún repositorio académico conocido por este equipo. Los `gold_answer` reflejan el propio análisis del equipo bajo FRE 801, no una fuente independiente. Un profesor universitario del área (lingüística legal en español) revisará más adelante la estructura gramatical de cada fila -- ver el campo `professor_reviewed` (actualmente `false` en las 20 filas) y `review_notes` en el dataset. **Incluso después de esa revisión, esto sigue siendo un conjunto sintético revisado por un experto, no un dataset externo publicado independientemente**, y no debe compararse numéricamente con el 70.21% del piloto real de inglés (`reports/PRISMA_LUZ_SNELL_ARCHITECTURE_REPORT.md`) como si tuvieran el mismo peso probatorio. Ver `docs/VERIFICATION_STANDARDS.md`, reglas 1 y 2.

**Fecha:** 1 de agosto, 2026
**Dataset:** `scratch/prisma_spanish_hearsay_dataset.json` (20 filas, autoescrito, gitignored)
**Script:** `scratch/prisma_spanish_hearsay_eval.py`
**Resultados fila por fila:** `scratch/prisma_spanish_hearsay_pilot_results.json`

---

## 1. Por qué este reporte existe

El sprint anterior (`reports/PRISMA_LUZ_SNELL_ARCHITECTURE_REPORT.md` §5) mejoró la pista de inglés sin cambio neto. El usuario pidió entonces un conjunto de hipótesis bilingüe, señalando que inglés y español manejan estructuras gramaticales distintas -- inglés depende del orden de palabras y verbos auxiliares (poca morfología), español codifica persona/número/tiempo/modo directamente en la conjugación del verbo (sujeto tácito, clíticos pegados al verbo, subjuntivo). Exploración confirmó que Luz/Snell tiene un andamiaje bilingüe real pero mucho más delgado en español (`REPORTING_VERB_LEMMAS["spa"]`: 25 vs 35; `NONVERBAL_ASSERTIVE_LEMMAS["spa"]`: 3 vs 6; `ontology_normalizer.py`: 0% cobertura en español; `luz_custom_lexicon.json`: vacío) -- y que **no existe ningún dataset real en español** en este repositorio (la demo "Colombia" es Facts hardcodeados, no un pipeline de extracción sobre texto real). Este reporte documenta el resultado de atacar esos huecos, con la disciplina de honestidad que exige evaluar sin dataset real: verificación estructural contra oraciones de ejemplo antes de cada cambio, luego una primera lectura contra el dataset propio (nunca contra un test ciego externo, porque no existe).

---

## 2. Resultado principal

| Iteración | Precisión (autoescrita, NO benchmark) |
| :--- | :-: |
| Primera lectura (Snell base + vocabulario nuevo H5/H7/H8/H9, sin H10/H11) | 65.00% (13/20) |
| + negación vía `advmod` ("nunca") + gate de cláusula responsiva más estricto | 75.00% (15/20) |
| + comparación por lema (no cadena de superficie) + anáfora "lo hizo" | **85.00% (17/20)** |

**Todas las cifras de esta tabla son sobre el propio dataset autoescrito del equipo -- ninguna es comparable al 70.21% real de inglés.**

---

## 3. Hipótesis verificadas y su resultado

Todas se verificaron primero contra oraciones de ejemplo (inspección directa del árbol de dependencias de spaCy), nunca "a ojo" contra el dataset completo, siguiendo la misma disciplina que el resto de este proyecto.

### H5 -- Recuperación de sujeto tácito (pro-drop) -- ACEPTADA

Español omite el sujeto con enorme frecuencia ("Dijo que..." no tiene ningún hijo `nsubj`). Verificado: `es_core_news_sm` sí conserva `Person`/`Number` en el propio verbo ROOT aunque no haya sujeto explícito. Nueva función `_find_declarant_morph()` en `snell.py`, nuevo campo `declarant_person_number` en `ReportedAssertion` (separado de `declarant`, para no confundir "el texto nombra al declarante" con "inferimos esto de la morfología"). Verificado con test dedicado (`test_spanish_pro_drop_subject_recovered_from_verb_morphology`).

### H6 -- Clíticos fusionados (enclisis) -- CONFIRMADO REAL, inicialmente NO arreglado, **RESUELTO más adelante en §12**

Verificado con oraciones gramaticalmente válidas (la enclisis española solo ocurre en infinitivo/gerundio/imperativo, nunca en indicativo conjugado -- un primer intento con "Dijoselo" resultó ser gramaticalmente inválido y se descartó): `es_core_news_sm` etiqueta formas como "decírselo", "diciéndoselo", "dígaselo" como **NOUN** (con el lema siendo la palabra fusionada entera, no "decir") -- una falla de tokenización/POS-tagging, no algo que una función de árbol de dependencias en `snell.py` pueda arreglar, porque ocurre ANTES de cualquier lógica de dependencias. En su momento se documentó con un test explícito que fijaba el comportamiento de fallo. **Actualización 2026-08-01, misma sesión:** resuelto sin fine-tuning y sin tocar el tokenizador -- ver §12 para la solución completa (reconocimiento por forma superficial + búsqueda de subárbol completo en `_find_content_span`).

### H7 -- Modo subjuntivo como señal -- ACEPTADA

Verificado: "hubiera mentido" (compuesto) tiene `Mood=Sub` en el auxiliar "hubiera", no en el participio "mentido"; "mintiera" (simple) tiene `Mood=Sub` directamente en el verbo. Nueva función `_content_clause_is_subjunctive()` revisa AMBOS casos. Nuevo campo `content_is_subjunctive` en `ReportedAssertion`.

### H8 -- Cerrar el hueco de vocabulario no-verbal -- PARCIALMENTE ACEPTADA

Se agregaron `sacudir` (shake) y `levantar` (raise) a `NONVERBAL_ASSERTIVE_LEMMAS["spa"]`, verificados contra oraciones de ejemplo con el mismo patrón de cláusula responsiva (`advcl`) que los 3 lemas preexistentes. `gesticular` (gesture) se probó pero **se excluyó**: en la oración de prueba, la misma construcción "cuando + pregunta" se etiquetó como `ccomp` en vez de `advcl` -- una inconsistencia del modelo pequeño de español que no se consideró suficientemente confiable para agregar sin más investigación.

### H9 -- Cobertura española en `ontology_normalizer.py` -- ACEPTADA

Nuevas constantes/funciones `_ES`: `ASSERTION_VERBS_SPA`, `PURPOSE_CLAUSE_OPENERS_SPA`, `IN_COURT_TESTIMONY_MARKERS_SPA`, `is_assertion_es()`, `split_purpose_and_statement_es()`, `made_in_current_proceeding_es()`. Cada una verificada individualmente contra una oración de ejemplo antes de darse por buena (mismo estándar que el par WordNet "sane"/"cuerdo" del reporte anterior).

---

## 4. Hallazgos adicionales de la primera lectura (diagnóstico libre -- dataset propio, no test ciego)

A diferencia del piloto de inglés (donde nunca se lee texto+gold de una fila de test juntos), este dataset lo escribió el propio equipo -- diagnosticar por qué falla una fila específica no es "ajustar contra el test", es exactamente el propósito de escribir el dataset. Estos hallazgos surgieron así, no de una hipótesis previa a la primera corrida:

- **Negación vía `advmod`:** "nunca" en español se etiqueta `dep_="advmod"`, NO `dep_="neg"` (a diferencia de "never" en inglés, que sí recibe `dep_="neg"` -- confirmado en el propio piloto de inglés). `_find_negation()` solo revisaba `dep_=="neg"`, así que "Juana nunca le dijo..." no se detectaba como negado. Corregido: ahora también revisa hijos `advmod` cuyo lema esté en `{"nunca", "jamás", "tampoco"}`.
- **Cláusula de propósito confundida con cláusula responsiva:** "Martín levantó la mano **para pedir un taxi**" y "...**cuando le preguntaron** si lo hizo" tienen la MISMA forma de dependencia (`advcl`) -- el chequeo original de `_find_governing_clause` (¿tiene algún hijo `advcl`?) no distinguía "propósito" de "pregunta respondida". Corregido con `_advcl_is_responsive_question()`: exige que el verbo de la cláusula `advcl` sea ÉL MISMO un verbo de reporte (ej. "preguntar"), lo cual "pedir" (solicitar) no es. Verificado que esto no rompe ningún test de inglés existente (donde "asked" sí es un verbo de reporte).
- **Comparación por lema, no por cadena de superficie:** "mintió" (pretérito) y "mentido" (participio) son la MISMA raíz ("mentir") pero cadenas de texto completamente distintas -- la comparación de palabras por regex (heredada del enfoque de inglés) nunca las conecta. Corregido: `_lemma_content_words_es()` lematiza con spaCy antes de comparar. Esta es la validación empírica más concreta de la tesis lingüística que motivó todo este sprint: la morfología rica del español necesita comparación a nivel de lema donde el inglés (morfología pobre) podía salir adelante con cadenas crudas.
- **Anáfora "lo hizo"**: mismo fenómeno que la anáfora "did so" ya aceptada en inglés (§5.3 del reporte de arquitectura) -- "cuando le preguntaron si **lo hizo**" no comparte ninguna palabra literal con la cláusula de propósito, pero afirma directamente la proposición preguntada. Agregado como regex `_ANAPHORIC_ACTION_PROFORM_ES`.
- **Retroceso documentado (mismo nivel de detalle que una mejora):** el cambio a comparación por lema **rompió** `es_hearsay_016` (antes correcta, ahora incorrecta) -- "hablar" (hablaba italiano) y "decir" (dijo "Buongiorno") comparten un cúmulo enorme de conceptos WordNet genéricos de "acto de habla" (`talk.n.01`, `speaking.n.01`, `utterance.n.01`...), produciendo un falso positivo de "mismo tema" análogo al caso "soccer"/"soccer team" del piloto de inglés original. La ganancia neta (+3: filas 009, 010, 012) superó esta pérdida aislada (-1: fila 016) -- mismo patrón "gana una categoría, pierde otra" ya documentado para la integración de WordNet en inglés (`reports/PRISMA_LEGALBENCH_REAL_PILOT_REPORT.md` §6). No se investigó más para evitar ajustar el heurístico mirando específicamente esta fila.
- **Clíticos no fusionados ("se lo confirmó al abogado") -- NO arreglado:** a diferencia de la enclisis (H6), aquí el verbo SÍ se detecta correctamente, pero el contenido de la declaración queda enteramente pronominalizado ("se"/"lo" no llevan contenido léxico propio) -- resolver esto requeriría resolución de correferencia genuina (a qué se refiere "lo"), fuera de alcance de esta sesión. Fila `es_hearsay_015` queda como fallo conocido, sin intentar un parche ad hoc.

---

## 5. Resultado final por fenómeno lingüístico (estado en este punto de la sesión -- ver §9-12 para adendas posteriores)

| Fenómeno | Correctas/Total |
| :--- | :-: |
| Sujeto tácito (pro-drop) | 2/3 |
| Clíticos fusionados (enclisis, limitación conocida) | 0/1 -- **resuelto en §12, ver tabla actualizada ahí** |
| Clíticos no fusionados (correferencia, no arreglado) | 0/1 |
| Subjuntivo | 1/1 |
| Vocabulario nuevo (sacudir/levantar) | 3/3 |
| Actos no verbales responsivos | 3/3 |
| Actos no verbales sin contexto (control negativo) | 2/2 |
| Negación | 2/2 |
| En corte / proceso previo | 5/5 |

---

## 6. Guardia de regresión (inglés, dado que los cambios tocan `snell.py`/`ontology_normalizer.py` compartidos)

Todos los cambios de esta sesión viven en módulos compartidos entre inglés y español. Verificado que el piloto real de inglés no cambió ni un solo punto:

| Comando | Resultado |
| :--- | :-: |
| `pytest tests/ -q` | 67 passed (61 + 6 tests nuevos de español) |
| `npm test` | 26 passed |
| `test_prisma_core_upgrades.py` | 5/5 |
| `prisma_legalbench_suite.py` | 120/120 |
| `external_legalbench_eval_snell.py` (inglés) | **70.21% (66/94) -- idéntico, sin cambio** |
| `external_legalbench_eval.py` | 69.15% (65/94) -- idéntico |
| `external_legalbench_diversity_eval.py` | 100.00% (300/300) -- idéntico |
| `external_legalbench_contractqa_eval.py` | 87.50% (70/80) -- idéntico |
| `external_legalbench_ucc_eval.py` | 53.19% (50/94) -- idéntico |
| `code_domain_real_pilot.py` | 10/10 MATCH, 0 MISMATCH (conteo de funciones subió de 211 a 217 por las funciones nuevas, todas documentadas -- esperado, no regresión) |
| `_internal_ncbe_full21_ingestion_eval.py` | 0.0% mal-clasificación financiera -- idéntico |

---

## 7. Próximos pasos

1. **Revisión de profesor (pendiente, bloqueante para cualquier afirmación más fuerte):** enviar `scratch/prisma_spanish_hearsay_dataset.json` a un profesor universitario de lingüística legal/español para confirmar que las 20 filas -- especialmente `es_hearsay_012` (matiz de subjuntivo) -- son gramaticalmente y jurídicamente correctas.
2. ~~**Enclisis (H6):** investigar reglas de excepción de tokenizador para sufijos enclíticos comunes, o evaluar `es_core_news_md`/`lg`.~~ Hecho parcialmente -- ver §9: `es_core_news_md` mejora el POS-tagging pero NO el lema; el sufijo enclítico sigue siendo el siguiente paso real (reglas de excepción de tokenizador/lematizador).
3. **Correferencia de clíticos no fusionados:** fuera de alcance actual; requeriría resolución de correferencia real, no un parche de regex.
4. **Dataset real en español:** buscar/proponer un dataset externo publicado análogo a LegalBench pero en español, para eventualmente reemplazar la evaluación autoescrita por una medición real y ciega -- ningún hallazgo de este reporte debe presentarse como "precisión real" hasta que eso exista.

---

## 9. Addendum (2026-08-01): upgrade a `es_core_news_md` -- corrige "gesticular", NO corrige la enclisis

Se evaluó subir de `es_core_news_sm` a `es_core_news_md` (~13MB -> ~42MB) como posible solución de una sola vez para varios huecos ya diagnosticados en §3/§4, en vez de parchar cada síntoma por separado.

**Verificado ANTES de cambiar el modelo por defecto** (re-inspección de todas las hipótesis ya aceptadas contra el modelo mediano, sentencia por sentencia, no asumido): H5 (pro-drop), H7 (subjuntivo), H8 (sacudir/levantar), H9 (marcador "en el estrado"), la corrección de negación por `advmod`, y el gate de cláusula responsiva más estricto -- los seis se sostienen **idénticos** bajo `es_core_news_md`. Ningún riesgo de regresión oculto.

**Lo que SÍ corrige:** la inconsistencia de "gesticular" documentada en §3 (H8) -- bajo el modelo pequeño, "cuando le preguntaron..." se etiquetaba a veces como `advcl` y a veces como `ccomp` para la misma construcción; bajo el modelo mediano, se etiqueta consistentemente como `advcl`, igual que sacudir/levantar/asentir. **Agregado** a `NONVERBAL_ASSERTIVE_LEMMAS["spa"]`.

**Lo que NO corrige:** la enclisis (H6). El modelo mediano mejora el POS-tagging de 2 de 3 formas de prueba (NOUN -> VERB correcto para "decírselo"/"dígaselo"), pero el **lema sigue siendo la forma fusionada** ("decírselo", no "decir") en las 3 -- así que `REPORTING_VERB_LEMMAS` sigue sin encontrar coincidencia, sin importar que el POS ya esté bien. Es un fallo del lematizador, no del etiquetador POS ni de ninguna lógica de árbol de dependencias en este módulo. `test_spanish_enclitic_reporting_verb_is_a_known_limitation` se actualizó para reflejar este matiz y se mantiene en verde (sigue fallando, como se espera).

**Resultado en el dataset autoescrito:** 85.00% (17/20) -- sin cambio, porque ninguna de las 20 filas usa "gesticular" (el hallazgo es real pero este dataset de 20 filas no lo ejercita, mismo patrón "mejora genuina, neutral en este test" ya visto con la anáfora "did so" de inglés).

**Diligencia paralela en inglés (documentada en `reports/PRISMA_LUZ_SNELL_ARCHITECTURE_REPORT.md` §7):** se comparó `en_core_web_sm` vs `en_core_web_md` sobre las 8 oraciones de prueba de H1-H4 -- solo 2 diferencias triviales de `dep_`, ninguna relevante para la lógica de extracción. Inglés se dejó en el modelo pequeño.

**Guardia de regresión tras el cambio:** `pytest tests/ -q` -> 68 passed (67 + 1 test nuevo de "gesticular"); todo el resto de Nivel A/B sin cambio (ver tabla §6, que ya reflejaba el estado post-cambio).

---

## 10. Addendum (2026-08-01): expansión de WordNet a hiperónimos (inglés) -- retroceso real en este piloto, documentado con el mismo detalle que una mejora

`wordnet_concepts_bilingual()` en `packages/prisma-python/prisma_core/luz_lexicon.py` -- compartida entre los pilotos de inglés y este piloto español vía `offered_for_truth_es`/`words_share_concept_bilingual` -- se extendió para expandir un nivel de hiperónimos WordNet (`syn.hypernyms()`), verificado antes contra pares reales conocidos ("car"→"motor_vehicle", "punch"→"blow"). El cambio fue un pedido explícito para los pilotos de inglés (ver `reports/PRISMA_LUZ_SNELL_ARCHITECTURE_REPORT.md` §9 y `reports/PRISMA_LEGALBENCH_REAL_PILOT_REPORT.md` §11, donde produjo una mejora neta real: +2 y +3 filas respectivamente), pero al ser una función compartida, también afecta a este piloto.

**Resultado en este dataset autoescrito -- retroceso real, no oculto:**

| | Antes | Después (+ hiperónimos) |
| :--- | :-: | :-: |
| **Lectura autoescrita (NO benchmark)** | 85.00% (17/20) | **80.00% (16/20)** ❌ -1 fila |
| Not introduced to prove truth | 50.0% (1/2) | **0.0% (0/2)** ❌ -1 |
| Standard hearsay | 66.7% (4/6) | 66.7% (4/6) (sin cambio neto, composición distinta por debajo) |
| Resto de fenómenos | — | sin cambio |

**Mismo mecanismo ya diagnosticado en §4 para "hablar"/"decir":** un hiperónimo directo compartido crea un puente temático genérico entre dos palabras, lo que infla falsos positivos justo en "Not introduced to prove truth" -- la categoría que por diseño requiere que el heurístico NO encuentre solape de concepto entre propósito y contenido, aunque estén superficialmente relacionados.

**Por qué se aceptó el cambio de todos modos:** la decisión se tomó a nivel de los pilotos de inglés (donde el cambio es una mejora neta real, medida contra `nguha/legalbench`, un dataset externo publicado), no a nivel de este piloto. Este dataset de 20 filas es autoescrito, pendiente de revisión de profesor, y su propio aviso de transparencia (inicio de este reporte) ya establece que nunca debe pesar lo mismo que un benchmark real en ninguna decisión. Documentar el retroceso aquí, con el mismo detalle que cualquier mejora, es la disciplina correcta -- no ocultarlo ni minimizarlo solo porque la decisión final no dependió de este número.

**No investigado más a fondo** para no ajustar el heurístico mirando específicamente qué frase de esas 2 filas falló -- consistente con la disciplina de todo este proyecto, aplicada aquí también aunque el dataset sea propio.

---

## 11. Addendum (2026-08-01): expansión de WordNet a hipónimos -- NEUTRAL en este piloto

Siguiendo la misma disciplina de una relación por vez (§10), se probaron los hipónimos por separado, después de que los hiperónimos ya estuvieran aceptados. **Resultado: 80.00% (16/20), sin cambio** -- neutral, ninguna de las 20 filas se ve afectada. Ver `reports/PRISMA_LUZ_SNELL_ARCHITECTURE_REPORT.md` §10 para el detalle completo (neutral también en los dos pilotos de inglés). Aceptado de todos modos por ser una capacidad genuina y verificada, sin ningún riesgo de regresión medido.

---

## 11b. Addendum (2026-08-01): primeras entradas reales en `luz_custom_lexicon.json` -- NEUTRAL

Se agregaron las primeras 3 entradas reales al léxico propio (vacío desde el diseño original), incluyendo el par español `declarante`/`hablante` (equivalente de FRE 801(b)(1)), cada una verificada individualmente y confirmando primero que WordNet no las cubría ya. **Resultado en este piloto: 80.00% (16/20), sin cambio** -- neutral. Ver `reports/PRISMA_LUZ_SNELL_ARCHITECTURE_REPORT.md` §11 para el detalle completo (también neutral en los dos pilotos de inglés).

## 11c. Addendum (2026-08-01): meronimia WordNet + marcadores en corte (inglés) -- NEUTRAL en este piloto

Con paso libre del usuario para seguir probando: meronimia/holonimia de WordNet (parte-todo, ej. "gun"/"trigger") y una expansión de `IN_COURT_TESTIMONY_MARKERS` en inglés (no aplica directamente a este piloto español, que usa `IN_COURT_TESTIMONY_MARKERS_SPA` por separado). **Resultado en este piloto: 80.00% (16/20), sin cambio** en ambos casos. Ver `reports/PRISMA_LUZ_SNELL_ARCHITECTURE_REPORT.md` §12-13 para el detalle completo.

## 12. Addendum (2026-08-01): H6 (enclisis) RESUELTO -- sin fine-tuning, sin tocar el tokenizador

Retomando el trabajo de la sesión paralela sobre el spec de fine-tuning (`docs/specs/SPANISH_ENCLISIS_PARSER_FINETUNING_SPEC.md`): esa sesión propuso una excepción de tokenizador (`nlp.tokenizer.add_special_case`) para dividir formas fusionadas en tokens separados. Verificado independientemente en este entorno real (spaCy 3.8.13, es_core_news_md 3.8.0): **dividir el token activamente CORROMPE el árbol de dependencia** en algunos casos (ej. dividir "Dígaselo" convierte "juez" en el ROOT de toda la oración) y en otros desplaza la cláusula de contenido al verbo gobernante equivocado (un efecto secundario de la división, no un fenómeno gramatical real -- confirmado comparando la misma oración con y sin clíticos fusionados).

**Solución final adoptada -- sin ninguna cirugía de tokenizador:**

1. **`_FUSED_CLITIC_FORMS`** (nuevo en `snell.py`): diccionario de forma-superficial → lema real (`"decírselo": "decir"`, `"diciéndoselo": "decir"`, `"confirmárselo": "confirmar"`, `"contárselo": "contar"`, etc.), verificado individualmente contra oraciones construidas. El token NUNCA se divide -- se reconoce por su texto exacto, sin importar qué POS/lema le haya asignado el etiquetador estadístico (que a veces sí acierta el POS pero nunca el lema, y a veces falla ambos).
2. **`_find_content_span` con 3 niveles** (antes 1 solo): nivel 1 sin cambio (hijo directo ccomp/xcomp); nivel 2 nuevo -- busca en TODO el subárbol del verbo (no solo hijos directos), porque la fila real `es_hearsay_013` reveló que el contenido a veces cuelga como `acl` de un sustantivo NIETO del verbo (ej. "jurado"), no de un hijo directo; nivel 3 nuevo, acotado solo a formas fusionadas -- si el contenido se promovió hasta el verbo gobernante (modal/aspectual), busca ahí, excluyendo explícitamente al propio nodo gobernante de auto-seleccionarse (bug real encontrado y corregido durante la verificación: el nodo raíz de la búsqueda puede tener él mismo `dep_=="acl"`, y como `subtree` se incluye a sí mismo, se seleccionaba a sí mismo como "el contenido").
3. Se agregó **"contar"** a `REPORTING_VERB_LEMMAS["spa"]` (verbo de reporte legítimo que faltaba, equivalente directo del inglés "recount"/"narrate" ya existente).

**Verificación exhaustiva antes de integrar:** 16 oraciones construidas (incluyendo controles negativos: sin cláusula, sin verbo de reporte, clitic climbing sin fusión) + las 6 oraciones oficiales del spec original + la fila real `es_hearsay_013` -- las 23 correctas tras el arreglo final.

**Resultado en el piloto español: 80.00% (16/20) → 85.00% (17/20), +1 fila neta.** `es_hearsay_013` (antes "enclitic_known_limitation", ahora "enclitic_resolved") pasa de 0% a 100%. Ninguna fila que antes pasaba se rompió.

**Guardia completa verificada en verde, incluyendo el piloto de inglés (misma función compartida `_find_content_span`):** 92 pytest (86 + 6 tests nuevos, incluyendo un test de regresión explícito confirmando que el nivel 2 nuevo NO cambia ningún caso de inglés que ya funcionaba vía nivel 1), 26 npm, 5/5, 120/120, Snell inglés sin cambio en 74.47% (70/94), regex inglés sin cambio en 71.28% (67/94), y el resto de Nivel B sin cambio. El test que documentaba la limitación conocida (`test_spanish_enclitic_reporting_verb_is_a_known_limitation`) se actualizó a `test_spanish_enclitic_reporting_verb_now_resolved` -- exactamente como estaba planeado desde que se escribió originalmente ("this test will start failing, which is the point").

**Alcance, honesto:** cubre "decir"/"confirmar"/"explicar"/"contar" con clíticos de 3ª persona ("se"+"lo"/"la"). No cubre 1ª/2ª persona ("me"/"te"/"nos") ni el resto de `REPORTING_VERB_LEMMAS["spa"]` -- extender de la misma forma, un verbo a la vez, verificando cada forma nueva antes de agregarla a `_FUSED_CLITIC_FORMS`. El spec de fine-tuning (`docs/specs/SPANISH_ENCLISIS_PARSER_FINETUNING_SPEC.md`) queda como referencia histórica de la vía descartada, no como trabajo pendiente -- este enfoque de código puro la reemplaza por completo para el alcance ya cubierto.

**Para reproducir:**
```bash
cd packages/prisma-python && python -m pytest tests/ -q          # 92 passed
python scratch/prisma_spanish_hearsay_eval.py                       # 85.00% (17/20), autoescrito, H6 resuelto
python scratch/external_legalbench_eval_snell.py                   # 74.47% (70/94), inglés, sin cambio
```

## 13. Comandos para reproducir desde cero

```bash
python -m spacy download es_core_news_md                                    # ~42MB, requerido desde 2026-08-01
cd packages/prisma-python && python -m pytest tests/ -q                    # 92 passed
python scratch/external_legalbench_eval_snell.py                            # 74.47% (70/94), inglés, mejora por hiperónimos WordNet
python scratch/prisma_spanish_hearsay_eval.py                                # 85.00% (17/20), autoescrito, H6 resuelto §12
```

## 14. Addendum (2026-08-01): búsqueda de un benchmark español real -- RAE DPEJ + jurisdicción colombiana

**Motivación:** el usuario preguntó si, de confirmarse el 85% autoescrito por un profesor, superaría el 74.47% real de inglés. Respuesta honesta dada: no, ni antes ni después de esa revisión -- N=20 autoescrito por nosotros mismos no es comparable a N=94 externo e independiente (`nguha/legalbench`), sin importar cuán bien redactado esté gramaticalmente. Esto llevó a una búsqueda extensa de: (a) un benchmark español real equivalente, y (b) si no existiera, "algo cercano" con respaldo institucional real.

**(a) No existe un benchmark de hearsay en español.** Confirmado revisando LEXTREME, Multi-Legal-Bench, MultiLegalPile y el propio LegalBench (HuggingFace): ninguno tiene una tarea de "prueba de referencia"/hearsay en español. Razón estructural: hearsay es una doctrina de common law; la mayoría de países hispanohablantes (derecho civil) nunca adoptaron una regla de exclusión equivalente.

**(b) Hallazgo real, mejor de lo esperado: Colombia sí tiene el equivalente institucional.** El sistema penal acusatorio colombiano (Ley 906 de 2004, arts. 437-438 CPP) copió explícitamente la doctrina de hearsay bajo el nombre "prueba de referencia", con jurisprudencia real de la Corte Suprema de Justicia (Sala de Casación Penal) interpretándola caso por caso. Es un análogo institucional real (no autorado por nosotros), aunque no viene como dataset etiquetado listo para usar -- solo como sentencias y doctrina, que hay que curar a mano.

**Recolección (en curso):** `scratch/prisma_colombia_prueba_referencia_real_cases.json` -- 4 casos reales, con radicado citado, paráfrasis propia de los hechos (no copia literal), y la etiqueta que la propia Corte le dio a cada uno:

*Casos "Sí" (admitida como prueba de referencia):*
- **SP512-2023 (rad. 55465):** declaración de víctima de tentativa de feminicidio, introducida vía testimonio de policías, por control coercitivo del procesado (excepción residual, art. 438).
- **Rad. 54937 (13-09-2023):** entrevista de testigo fallecido, presentada como sustituto de su testimonio directo (imposibilidad de práctica directa, art. 438).

*Casos "No" (rechazada/no admitida):*
- **AP1393-2020 (rad. 53838):** la Fiscalía intentó introducir declaraciones previas de una testigo que invocaba su garantía de no autoincriminación (art. 33 Constitución); la Corte negó la incorporación porque invocar esa garantía no es un "evento similar" del art. 438 -- admitirla forzaría indirectamente a la testigo a declarar.
- **SP4382-2021 (rad. 59825):** una menor se retractó en juicio de acusaciones previas de abuso contra su padre; la Fiscalía intentó usar sus declaraciones previas sin agotar el trámite procesal requerido (sin solicitud expresa ni demostración formal del cambio de versión ante el juez); la Corte concluyó que no era ni prueba de referencia ni testimonio adjunto válidamente incorporado.

**Disciplina de búsqueda equitativa (instrucción explícita del usuario):** la primera pasada de recolección solo encontró casos "Sí", con el riesgo de sesgar el conjunto hacia un solo lado. Para la segunda pasada se usaron términos de búsqueda deliberadamente NEUTRALES (fraseo de índices jurisprudenciales y de reglas doctrinales -- p. ej. "líneas jurisprudenciales prueba de referencia", "declaración anterior testigo contrainterrogado") en vez de queries que solo buscaran "rechaza"/"no admite", que habrían corrido el riesgo de traer fragmentos genéricos no representativos (como pasó en un intento anterior). Los 2 casos "No" resultantes se apoyan además en **fundamentos jurídicos distintos entre sí** (uno sobre garantía de no autoincriminación; otro sobre incumplimiento de trámite procesal) para no sesgar tampoco el lado negativo hacia un único tipo de razonamiento.

**Balance actual:** 2 Sí / 2 No (N=4). Sigue siendo una muestra pequeña -- **no se calcula ningún porcentaje de precisión con N=4**; el conjunto sigue en construcción, ahora con la disciplina explícita de seguir ampliándolo sin buscar solo el lado que falte en cada momento.

**RAE -- Diccionario panhispánico del español jurídico (DPEJ):** gratuito, verificado por la RAE + ~400 juristas de España e Hispanoamérica (`dpej.rae.es`). Se usó para confirmar (no para inventar) que el vocabulario ya existente en `ASSERTION_VERBS_SPA` (`ontology_normalizer.py`) -- raíces como "declar", "testific", "afirm" -- coincide con las definiciones jurídicas reales de "declarante" y "testimonio". No se cambió ningún término: la verificación confirmó que ya estaban bien elegidos. Cambio aplicado: solo un comentario nuevo en el código citando la fuente real (documentación, no comportamiento) -- ver `ontology_normalizer.py` líneas ~222-241. No se agregaron pares nuevos a `luz_custom_lexicon.json` porque ninguno de los términos del DPEJ llena hoy un hueco real que algún llamador del código ejerza (el lexicon existente solo se consulta con pares del mismo idioma, `words_share_concept("eng","eng")`/equivalente español; un par cruzado español-inglés como "prueba de referencia"/"hearsay" no tendría ningún punto de entrada que lo use todavía -- se documenta aquí para no perder la idea, pero no se agregó por disciplina de no-especulación).

**Guardia de regresión tras el cambio de comentario:** `pytest tests/ -q` → 93 passed (sin cambio, como se esperaba de una edición de solo comentarios).

**Próximos pasos (pendientes, no iniciados):** seguir buscando 1-2 casos reales de rechazo/inadmisión para balancear el conjunto; considerar ampliar la muestra antes de cualquier lectura de precisión.

## Addendum (2026-08-01): cosecha masiva de PDFs oficiales -- dataset real de Colombia de N=4 a N=12

**Se pidieron 10 casos de cada etiqueta. Se lograron 8 "Sí" / 4 "No" (N=12). El objetivo NO se alcanzó y esto se documenta como hallazgo, no como fracaso silencioso.**

**Desbloqueo del método.** La recolección llevaba dos rondas estancada porque WebFetch devolvía los PDFs de tribunales colombianos como binario comprimido ilegible. Se diagnosticó que era una limitación de WebFetch, **no** de los PDFs: descargarlos con `urllib` y parsearlos localmente con PyMuPDF extrae texto perfectamente limpio. Verificado sobre SP337-2023: 44 páginas, 53.525 caracteres, 21 menciones del término.

**Herramientas nuevas (reusables):**
- `scratch/co_sentencia_pdf_harvester.py` -- una sentencia completa: descarga, cachea, extrae y aísla los pasajes que discuten "prueba de referencia".
- `scratch/co_boletin_batch_harvest.py` -- lote sobre los **Boletines Jurisprudenciales** oficiales de la Sala Penal. Los boletines resultaron ser la fuente eficiente: son la relatoría de la propia Corte, con encabezados temáticos que condensan el holding (ej. *"SISTEMA PENAL ACUSATORIO - Testimonio: acerca de lo percibido directamente por el testigo no es prueba de referencia"*), mucho más densos en holdings claramente etiquetados que una sentencia de 44 páginas.

**Cobertura procesada:** 18 boletines mensuales oficiales (2025-01 a 2026-07, todos descargados y parseados con éxito) + 1 sentencia completa. 23 pasajes relevantes encontrados. De ahí se curaron a mano `co_pr_005` a `co_pr_012`.

**Disciplina mantenida:** ninguna de las dos herramientas asigna etiquetas automáticamente. Ambas solo aíslan pasajes para lectura humana; la `gold_label` es lo que la Corte realmente decidió, leído y confirmado caso por caso. Auto-etiquetar habría fabricado un dataset cuyo "gold" es en realidad la conjetura del script.

**Por qué no se llegó a 10/10 (hallazgo estructural real):** los holdings "No" son **mucho más raros** en este corpus. La Corte escribe sobre prueba de referencia casi siempre para analizar su **admisión** o sus requisitos, no para declarar que algo simplemente no lo es. Forzar el conteo a 10/10 habría exigido inventar casos o reetiquetar los mixtos — exactamente el sesgo que este dataset existe para evitar, y sobre el que el propio usuario advirtió explícitamente en una ronda anterior ("que no vayamos a... siempre tentar hacia un lado"). Para llegar a 10 "No" habría que ampliar a boletines 2012-2024 (disponibles en el mismo índice oficial) y/o a sentencias de tribunales superiores, aceptando más lectura por caso.

**Casos "No" obtenidos, sobre fundamentos jurídicos distintos entre sí** (para no sesgar tampoco el lado negativo hacia un solo razonamiento):
- `co_pr_003` — invocar la garantía de no autoincriminación no es "evento similar" del art. 438.
- `co_pr_004` — fallo de trámite procesal (sin solicitud expresa ni demostración del cambio de versión).
- `co_pr_006` — el testimonio sobre lo percibido **directamente** no es prueba de referencia; la Corte corrigió a la defensa por confundir ambas cosas.
- `co_pr_007` — versiones recogidas en actos de investigación: "Prueba de referencia: improcedencia".

**Nota de transparencia sobre un caso mixto:** `co_pr_012` es intrínsecamente ambiguo — la Corte sostuvo que el mismo testimonio del psicólogo es prueba de referencia *sobre lo dicho por el menor* pero prueba **directa** *sobre las percepciones propias del profesional*. Se etiquetó "Sí" con la pregunta restringida explícitamente a la parte relatada, y la ambigüedad quedó documentada en la propia fila en vez de esconderse tras una etiqueta limpia.

**N=12 sigue siendo insuficiente para calcular ningún porcentaje de precisión.** El conjunto no se ha corrido contra Luz todavía y no debe presentarse como equivalente al piloto real de inglés.

## Addendum (2026-08-01): primera corrida contra el corpus REAL colombiano -- RESULTADO NEGATIVO, por debajo del baseline

**Resultado: 7/12 = 58.33%. El baseline de clase mayoritaria (responder siempre "Sí") da 8/12 = 66.67%. El pipeline quedó POR DEBAJO de no hacer nada.** Se reporta con el mismo detalle que se reportaría una mejora, según `docs/VERIFICATION_STANDARDS.md`.

Script: `scratch/co_prueba_referencia_eval.py`. Reutiliza el pipeline español **sin ningún ajuste** (mismas `is_statement_snell_es`/`made_out_of_court_es`/`offered_for_truth_es`, misma cadena Horn de 2 pasos) — el objetivo era medir cómo transfiere el pipeline ya congelado a lenguaje judicial real que nunca ha visto. El campo `question` se excluyó a propósito de las features: contiene la frase "constituye prueba de referencia", que filtraría la etiqueta.

### Desglose que revela el problema

| | Aciertos |
| :--- | :-: |
| Filas "Sí" (8) | **3/8 (37.5%)** |
| Filas "No" (4) | 4/4 (100%) |
| Total | 7/12 (58.33%) |

El pipeline predijo "No" en **9 de 12** filas. No es ruido aleatorio: es un sesgo sistemático a sub-detectar.

### Causa raíz diagnosticada (nivel agregado, no fila por fila)

Dos fallos estructurales, ambos consecuencia del **cambio de género textual**, no de un bug:

1. **`MadeOutOfCourt` colapsa en resúmenes de caso.** `made_in_current_proceeding_es` busca marcadores como "en el juicio", "juicio oral", "durante el juicio". En una oración estilo LegalBench, esos marcadores significan *"la declaración se hizo en el estrado"*. Pero en un **resumen de caso** esas frases aparecen constantemente porque el resumen **describe el contexto procesal** ("no compareció al juicio oral", "declaró en juicio narrando lo que..."). El marcador se dispara por el género del texto, no por dónde se hizo la declaración. Devolvió `False` (= sí fue en corte) en 6 de 12 filas, bloqueando la regla del paso 1.

2. **`IsStatement` falla en párrafos multi-oración.** Snell fue diseñado y medido sobre **una oración** con un verbo de reporte identificable. Los `fact_summary` son párrafos de 3-5 oraciones con estructura procesal densa; en 5 de 12 filas Snell no encontró ninguna aserción reportada no-negada, pese a que el caso trata precisamente de declaraciones.

### Interpretación honesta

Esto **no** significa que Luz esté roto ni que el motor falle. Significa que el pipeline español está sobreajustado a un género textual muy específico (oración corta, narrativa, estilo LegalBench) y **no transfiere** a prosa judicial real. Era un riesgo anticipado y escrito explícitamente en el docstring del script *antes* de correrlo — pero anticiparlo no lo hace menos real: es la primera evidencia externa genuina de que el 85% autoescrito **no predice** el desempeño sobre texto real, exactamente el tipo de brecha que el aviso de transparencia de este reporte lleva advirtiendo desde el principio.

### Lo que deliberadamente NO se hizo

No se tocó ni una línea del pipeline para mejorar este número. Ajustar los marcadores o el extractor ahora, después de ver los resultados, sería sobreajustar contra el único conjunto externo real que existe en español en este proyecto — destruyendo justo la propiedad que lo hace valioso. Cualquier mejora futura debe diseñarse desde conocimiento general del género judicial y verificarse estructuralmente ANTES de volver a correr este conjunto.

### Advertencia estadística

N=12 (8 Sí / 4 No). Una sola fila vale 8.3 puntos. El 58.33% es una **señal direccional**, no una medición con peso estadístico, y no debe citarse como "la precisión de PRISMA en español". El piloto de inglés (`nguha/legalbench`, 94 filas ciegas) sigue siendo el único resultado de este proyecto con peso estadístico real.

## Addendum (2026-08-01): sonda de español cotidiano + paradigma de conjugación completo -- 85.11% -> 100%

**Origen.** Tras la corrida real colombiana (58.33%, bajo el baseline), el usuario preguntó si adaptar Luz a prosa judicial no lo volvería propenso a fallar en otros textos españoles. Al analizar ese riesgo se detectó un hueco de verificación grave: **no existía ninguna prueba de español no-jurídico**. El inglés sí tiene una (`scratch/non_technical_hearsay_probe.py`, 15 oraciones cotidianas, 14/15); la única evaluación española era el piloto de hearsay, que es legal. Es decir: un parche futuro que degradara el español cotidiano habría sido **indetectable**.

**Guardia nueva:** `scratch/spanish_everyday_conjugation_probe.py` -- 47 oraciones cotidianas autoescritas (41 con verbo de reporte + **6 controles negativos**, tan importantes como los positivos: un extractor que dijera "sí" a todo también sacaría 100% sin ellos). Centrada en conjugación por petición explícita del usuario: 8 tiempos, 7 personas, voseo, pro-drop, subjuntivo, imperativo, clíticos y negación.

**Primera lectura: 40/47 (85.11%).** Los 7 fallos se agruparon en un solo patrón, y la causa raíz resultó ser **la misma clase de fallo que la enclisis (H6)**: el lematizador de `es_core_news_md` **inventa no-palabras** en conjugaciones irregulares.

| Forma | Lema de spaCy | Correcto |
| :--- | :--- | :--- |
| "dijiste" | `dijistar` (inventado) | `decir` |
| "dijimos" | `dijir` (inventado) | `decir` |
| "dijisteis" | `dijisteis` (sin lematizar) | `decir` |
| "decís" (voseo) | `decís` (sin lematizar) | `decir` |
| "Cuéntale" | `Cuéntale` **y POS=PROPN** | `contar` |
| "dijo" | `decir` ✅ | — |

**La 3ª persona singular funciona; 2ª persona, 1ª plural, voseo e imperativo no.** Como prácticamente todo el material español probado antes usaba 3ª persona ("Ana dijo que...", "El testigo declaró que..."), el hueco llevaba toda la sesión invisible. El voseo importa especialmente: es el uso estándar en Argentina, Uruguay y partes de Colombia.

**Solución (misma técnica ya validada, pero generada sistemáticamente).** `scratch/generate_spanish_verb_forms.py` produce `prisma_core/spanish_verb_forms.json`: **1.695 formas** de superficie -> lema, para los 32 lemas españoles de reporte/no-verbales, generadas con un conjugador español real (`verbecc`) a partir del paradigma COMPLETO. Parchear solo las 7 formas fallidas habría sido sobreajustar a la sonda. `verbecc` es dependencia **solo de generación**: el runtime lee un JSON estático y nunca lo importa.

**Protección contra falsos positivos (lo más delicado).** Muchas formas conjugadas colisionan con sustantivos comunes: "cuentas"/*contar*, "firma"/*firmar*, "jura"/*jurar*. Un mapeo ciego habría fabricado justo los falsos positivos que esta sesión lleva eliminando. Dos filtros independientes lo impiden: (1) la tabla solo se consulta si spaCy ya etiquetó el token `VERB`/`AUX` -- "pagué la cuenta" (NOUN) nunca dispara; (2) solo se consulta cuando el lema actual **no** es ya un verbo de reporte conocido, así nunca se pisa un análisis correcto. Hay tests dedicados a ambas condiciones.

**Dos bugs propios encontrados y corregidos durante la verificación** (documentados porque muestran por qué verificar el generador importa tanto como generarlo):
1. *Falso positivo de enclisis:* la primera versión marcaba como "enclítica" cualquier forma terminada en `-te`/`-me`/`-se`, eximiéndola del filtro de POS. Pero "-aste"/"-iste" (pretérito) y "-ase" (subjuntivo) son desinencias ordinarias: 53 formas quedaban indebidamente exentas. Corregido -- verbecc solo emite formas desnudas, así que **ninguna** es enclítica y todas exigen POS verbal.
2. *Lematización sensible al contexto:* la primera versión omitía formas que spaCy "ya acertaba", probándolas **aisladas**. Pero `nlp("dijimos")` suelto devuelve `decir` (correcto) mientras que dentro de "Nosotros dijimos que..." devuelve `dijir`. Esa optimización descartaba justo formas que sí fallan en uso real. Corregido incluyendo el paradigma completo.

Las formas imperativas con clítico ("Dile", "Cuéntale", "Explícale") se añadieron a `_FUSED_CLITIC_FORMS`, no a la tabla generada -- separación de responsabilidades: la tabla contiene solo formas desnudas.

**Resultado: 47/47 = 100.00%** (voseo 0/2 -> 2/2, persona 4/7 -> 7/7, imperativo 0/2 -> 2/2), con los 6 controles negativos intactos.

**Guardia de regresión -- sin degradación en ningún frente:** `pytest` 114 passed (107 + 7 nuevos), piloto español legal **85.00% sin cambio**, piloto inglés Snell **74.47% sin cambio**, corpus real colombiano **58.33% sin cambio**.

**Nota honesta sobre ese último número:** que el corpus colombiano NO mejorara es el resultado esperado y coherente. Su fallo es de **género textual** (resúmenes de caso donde `MadeOutOfCourt` colapsa), no de conjugación -- son problemas distintos. Arreglar la conjugación no podía arreglarlo, y que no lo haya "arreglado por accidente" es evidencia de que el diagnóstico anterior era correcto.
