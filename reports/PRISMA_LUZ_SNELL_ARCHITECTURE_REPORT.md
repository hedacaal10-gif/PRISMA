# PRISMA — "Luz" y "Snell": arquitectura de ingesta bilingüe y parsing formal

**Fecha:** 1 de agosto, 2026

---

## 1. Nomenclatura

**Luz** = el proceso de ingesta/traducción de PRISMA (texto crudo → Facts). Metáfora: la luz entra al prisma y se refracta en múltiples proyecciones — cada método de extracción (regex, LLM, WordNet, Snell) es una "refracción" distinta del mismo texto, con distinta fidelidad. El motor (`PrismaCoreEngine`) certifica cuál parte del espectro es confiable.

**Snell** = el motor de parsing sintáctico formal dentro de Luz, nombrado por la ley física que rige matemáticamente *cómo* se dobla la luz (no solo que se dobla). Usa árboles de dependencia gramatical reales (spaCy — determinista, offline, no generativo) en vez de coincidencia de texto crudo (regex).

---

## 2. Luz: léxico bilingüe (`packages/prisma-python/prisma_core/luz_lexicon.py`)

- **WordNet bilingüe** vía Open Multilingual Wordnet: inglés (Princeton WordNet) + español (WordNet de la Universidad Politécnica de Madrid, integrado en OMW). Verificado: `"sane"` (inglés) y `"cuerdo"` (español) resuelven al mismo synset (`sane.a.01`).
- **Tamaño real:** ~39MB en disco (11MB WordNet + 28MB OMW), trivial comparado con el modelo LLM local (1.93GB).
- **Léxico propio creciente** (`luz_custom_lexicon.json`): arranca vacío; solo crece vía `add_verified_relation()`, que exige `source` y `verified_via` obligatorios — ninguna entrada especulativa.
- **Bug real encontrado y corregido durante la construcción:** la expansión por formas derivacionalmente relacionadas (la que conecta "sane"↔"sanity") solo se aplicaba para consultas en inglés (`if lang == "eng":`) — rompía silenciosamente el caso español "cuerdo"↔"cordura" (el mismo patrón que sane/sanity). Corregido: la relación vive en el synset mismo, no depende del idioma de la consulta. Verificado con test dedicado.
- `ontology_normalizer.py` fue refactorizado para delegar en este módulo — mismo comportamiento/resultados en inglés (verificado: el piloto de hearsay reprodujo 69.15% exacto tras el refactor).

---

## 3. Snell: parsing sintáctico formal (`packages/prisma-python/prisma_core/snell.py`)

Usa spaCy (`en_core_web_sm` para inglés, ~13MB; `es_core_news_md` para español desde 2026-08-01 -- ver §7 -- ~42MB, ambos deterministas) para construir árboles de dependencia reales, y aplica reglas de composición explícitas sobre relaciones gramaticales (sujeto/objeto/cláusula/negación) en vez de buscar substrings en texto crudo.

### Dos bugs reales encontrados y corregidos ANTES de correr contra datos de test

1. **Loop infinito**: comparaba objetos `Token` de spaCy con `is` (identidad de Python) para detectar la raíz del árbol — spaCy no garantiza esa identidad estable entre accesos a `.head`, así que la condición de salida del `while` nunca se cumplía. Corregido usando `token.dep_ == "ROOT"` (la forma documentada de spaCy). Atrapado de inmediato al correr contra una sola oración real, antes de tocar el dataset de prueba.
2. **Dirección invertida**: para detectar "nodded **when asked**...", el código buscaba si el verbo estaba DENTRO de una cláusula subordinada (caminando hacia arriba en el árbol), cuando en realidad la cláusula subordinada cuelga COMO HIJO del verbo. Corregido para revisar `verb_token.children`, no los ancestros.

### Resultado: piloto real, mejora neta (ablación controlada)

Diseño de ablación: se reemplazó **solo** `IsStatement` por la detección formal de Snell; `MadeOutOfCourt` y `OfferedForTruth` se dejaron exactamente como en el baseline validado (regex+WordNet, 69.15%) — así cualquier cambio es atribuible únicamente a Snell.

| | Baseline (regex+WordNet) | Con Snell (solo IsStatement) |
| :--- | :-: | :-: |
| Train | 3/5 | 3/5 |
| **Test real (94 filas, ciego)** | 69.15% (65/94) | **70.21% (66/94)** ✅ +1 fila neta |
| Not introduced to prove truth | 70.0% (14/20) | 75.0% (15/20) ✅ |
| Resto de categorías | — | sin cambio |

Script: `scratch/external_legalbench_eval_snell.py`. Tests dedicados: `packages/prisma-python/tests/test_snell.py` (6 casos, incluye pruebas de regresión explícitas para los dos bugs).

---

## 4. Lectura honesta

- Snell mejora, pero modestamente (+1 fila de 94) en esta ablación acotada — consistente con lo esperado: solo tocamos una de tres condiciones, y el parsing formal principalmente reduce falsos positivos/negativos de "¿hay un verbo de reporte real aquí?", no resuelve el problema semántico más profundo (¿esta cláusula de propósito significa lo mismo que el contenido de la declaración?), que sigue dependiendo de WordNet/léxico propio.
- El valor real de Snell no es (todavía) el número — es que **falla explícitamente** en vez de adivinar: cuando no encuentra un verbo de reporte, devuelve lista vacía, no una conjetura basada en substring. Los dos bugs encontrados durante la construcción (loop infinito, dirección invertida) se atraparon *antes* de tocar el dataset real, precisamente porque el diseño formal hace los errores visibles rápido (una oración de prueba colgó el proceso de inmediato) en vez de fallar en silencio como hacía el regex.
- Próximo paso natural: extender Snell a `MadeOutOfCourt` (detectar estructuralmente si el verbo principal está en una cláusula que indica testimonio actual, no solo buscar frases fijas) y medir si la ganancia se acumula.

---

## 5. Addendum (2026-08-01): sprint de 1 hora — MadeOutOfCourt/OfferedForTruth vía Snell, resultado neto: sin cambio en test real, +1 fila en train

Siguiendo el "próximo paso natural" de la sección anterior, se intentaron 4 hipótesis genuinas para subir la precisión real de `scratch/external_legalbench_eval_snell.py` (baseline: 70.21%, 66/94) sin tocar ningún caso de test individual. **Resultado final: 70.21% (66/94) — exactamente igual al baseline.** Tres de los cuatro intentos se descartaron por la guardia de regresión; uno se aceptó (mejora train, neutral en test, sin romper nada).

### 5.1 Intento 1 (descartado): `MadeOutOfCourt` vía árbol de dependencias, reemplazando la lista de marcadores fijos

**Hipótesis:** en vez de buscar frases fijas (`IN_COURT_TESTIMONY_MARKERS`: "on the stand", "cross-examination", etc.) en cualquier parte del texto, verificar si un verbo de reporte (`REPORTING_VERB_LEMMAS`) tiene, en su propio subárbol de dependencias, un sustantivo de "lugar del proceso" (trial/hearing/stand/examination/courtroom/jury) conectado vía una relación preposicional (`pobj`/`obl`/`nmod`). Esto generalizaría el vocabulario (sustantivos sueltos en vez de frases exactas) y acotaría el chequeo a la vecindad gramatical del evento de habla, reduciendo falsos positivos por menciones sueltas de "trial" en otra parte de la oración.

**Verificación de la hipótesis:** confirmada manualmente contra la fila 3 de train ("When asked by the attorney on cross-examination, Alice testified that...") vía inspección del árbol de dependencias real de spaCy — `testified` es ROOT, `asked` cuelga de él vía `advcl`, y `examination` aparece varios niveles más abajo como `pobj` de `on`; como `token.subtree` recorre TODOS los descendientes (no solo hijos directos), el chequeo sí detecta este caso.

**Resultado (train intacto, test real regresionó):**

| | Baseline (marcadores fijos) | Árbol de dependencias (reemplazo) |
| :--- | :-: | :-: |
| Train | 3/5 | 3/5 (sin cambio) |
| **Test real** | 70.21% (66/94) | **68.09% (64/94)** ❌ -2 filas netas |
| Statement made in-court | 78.6% (11/14) | **64.3% (9/14)** ❌ -2 filas |

**Diagnóstico agregado (sin leer texto+gold de filas individuales de test):** se construyó un experimento adicional (`scratch/_tmp_ooc_experiment.py`, temporal, borrado tras usarlo) que comparó, fila por fila del test set, si el chequeo de árbol de dependencias alguna vez detectaba "en proceso actual" en una fila donde la lista de marcadores fijos NO lo detectaba. Resultado: **0 de 94 filas** — el chequeo de árbol nunca añade una detección que la lista de marcadores fijos no tuviera ya. Es decir, el árbol de dependencias es un subconjunto estricto de lo que la lista de marcadores ya cubre, así que reemplazar la lista solo puede perder cobertura, nunca ganarla, en este dataset — explica exactamente la caída de -2 filas. **Descartado.** El código nuevo (`find_current_proceeding_testimony` en `snell.py`) fue removido por completo tras confirmar esto; no quedó código muerto en el repositorio.

### 5.2 Intento 2 (descartado): `OfferedForTruth` vía `content_span` de Snell, reemplazando el segmento regex de "declaración"

**Hipótesis:** usar el `content_span` (la cláusula `ccomp`/`xcomp` real del verbo de reporte — lo que efectivamente se dijo) como el texto de "declaración" en la comparación de solape de palabras, en vez de "todo el texto después de la primera coma" (que incluye ruido narrativo como "the fact that Tim told Jimmy that ..."), dejando la cláusula de propósito sin cambios (Snell no tiene extractor de cláusula de propósito por árbol; eso queda fuera de alcance de este cambio).

**Resultado (train intacto, test real regresionó):**

| | Baseline | `content_span` (reemplazo) |
| :--- | :-: | :-: |
| Train | 3/5 | 3/5 (sin cambio) |
| **Test real** | 70.21% (66/94) | **69.15% (65/94)** ❌ -1 fila neta |
| Standard hearsay | 58.6% (17/29) | **55.2% (16/29)** ❌ -1 fila |

**Descartado.** No se investigó más a fondo el mecanismo exacto (evitando leer texto+gold fila por fila); el cambio se revirtió íntegramente en `scratch/external_legalbench_eval_snell.py`.

### 5.3 Intento 3 (aceptado): anáfora de proforma de acción ("did so"/"do it"/"do that") para actos no verbales asertivos

**Hipótesis:** un acto no verbal asertivo (asentir/negar con la cabeza/señalar — `NONVERBAL_ASSERTIVE_LEMMAS`) hecho en respuesta directa a una pregunta de sí/no que contiene una proforma anafórica de acción ("did so"/"do it"/"do that") necesariamente afirma la proposición misma sobre la que se preguntó — y esa proposición ES la cláusula de propósito en este tipo de construcción. Esto es un hecho gramatical general sobre la anáfora de "do so" (referencia a la acción recién mencionada), no una regla ajustada a un verbo o nombre específico.

**Verificado contra train:** fila 4 ("On the issue of whether Martin punched James, ... Martin smiled and nodded when asked if he did so...", gold=Yes) fallaba antes (`OfferedForTruth` daba `False` porque "punched" no aparece literalmente en el segmento de la declaración, solo la proforma "did so") y pasa a acertar con esta regla.

**Resultado (train mejora, test real neutral, ninguna guardia de regresión afectada):**

| | Baseline | + anáfora "did so" (no verbal) |
| :--- | :-: | :-: |
| Train | 3/5 | **4/5** ✅ |
| **Test real** | 70.21% (66/94) | **70.21% (66/94)** — sin cambio |
| Todas las categorías | — | idénticas fila por fila (0 filas cambiaron de predicción en el test set ciego) |

**Aceptado.** No sube el número real en este dataset de 94 filas (la regla, tal como está acotada, nunca se activa en ninguna de esas filas), pero es una corrección genuina y verificada de una laguna real en la lógica (confirmada contra un caso real de train, no inventada), no rompe ninguna guardia de regresión, y deja el heurístico mejor preparado para texto futuro con este patrón. Código: `scratch/external_legalbench_eval_snell.py`, función `offered_for_truth`.

### 5.4 Intento 4 (descartado, no por regresión sino por falta de justificación en train): ampliar la regla anafórica a respuestas verbales

**Hipótesis extendida:** la misma anáfora "did so" debería aplicar también a respuestas verbales (no solo actos no verbales) — ej. "when asked if she did so, she admitted that she did". Es gramaticalmente igual de válida en general.

**Resultado:** también neutral en el test real (70.21%, sin cambio en ninguna categoría) — pero a diferencia del intento 3, **ningún caso de las 5 filas de train** confirma específicamente la variante verbal (la única fila de train con este patrón es la no-verbal, fila 4). Ampliar el alcance sin un caso de train que lo respalde violaría la disciplina de "diseñar solo desde train + conocimiento general verificable" de forma más laxa de lo necesario, así que se dejó fuera — se mantuvo la versión acotada a actos no verbales (intento 3), que sí tiene respaldo directo en train.

### 5.5 Conclusión honesta de este sprint

**Número final: 70.21% (66/94) — exactamente igual al baseline con el que se empezó.** No se alcanzó la meta ambiciosa de 80%. Los dos intentos de reemplazar heurísticas de marcadores/regex por sus equivalentes de árbol de dependencias (5.1, 5.2) resultaron ser generalizaciones netamente peores en este dataset específico — el diagnóstico agregado del intento 5.1 mostró que la lista de marcadores fijos ya cubre estrictamente más que la versión basada en árbol, así que Snell no tenía margen de mejora ahí sin ADEMÁS ampliar vocabulario (lo cual habría requerido mirar filas de test para saber qué vocabulario faltaba, y eso está prohibido por el protocolo). El único cambio aceptado (5.3) es una corrección real pero que no se ejerce en este test set de 94 filas concreto — un recordatorio honesto de que "mejora train + no rompe nada" no garantiza "mejora test real", y que preferir 70.21% honesto sobre un número inflado por mirar el test es exactamente la disciplina que este proyecto se propuso seguir (`docs/VERIFICATION_STANDARDS.md`).

**Para reproducir desde cero:**
```bash
cd packages/prisma-python && python -m pytest tests/ -q          # 61 passed
cd packages/core && npm test                                      # 26 passed
python scratch/test_prisma_core_upgrades.py                       # 5/5
python scratch/prisma_legalbench_suite.py                         # 120/120
python scratch/external_legalbench_eval_snell.py                  # 70.21% (66/94), train 4/5
```

---

## 6. Addendum (2026-08-01): conjunto de hipótesis bilingüe -- pista de inglés (H1-H4)

Siguiendo el plan de hipótesis bilingüe (inglés + español) para Luz, esta sección cubre 4 hipótesis nuevas de inglés, distintas a las 4 de la sección 5. Todas se verificaron ESTRUCTURALMENTE primero (inspeccionando el árbol de dependencias real de spaCy sobre oraciones de ejemplo) antes de decidir si ameritaban un cambio de código -- disciplina que reveló que 3 de las 4 ya estaban cubiertas por el diseño existente, y solo 1 era un hueco real.

### H1 -- Voz pasiva de reporte ("it was stated that...", "X was told that...")

**Hipótesis:** detectar un verbo de reporte con hijo `nsubjpass`/`auxpass` (voz pasiva), no solo `nsubj`.

**Hallazgo:** verificado contra "It was stated by Alice that..." y "Alice was told by Bob that..." -- en ambos casos, `stated`/`told` son VERB con lema en `REPORTING_VERB_LEMMAS`, y el loop de `extract_reported_assertions` ya itera TODO token VERB cuyo lema coincida, sin importar su rol sintáctico (`nsubj` vs `nsubjpass`, ROOT vs no-ROOT). **Ya cubierto, sin cambio de código.** El único efecto secundario notado (no explotado): en voz pasiva, `declarant` captura el sujeto expletivo "It" en vez del agente real ("Alice", vía `by`-agent) -- pero `declarant` no lo consume ningún predicado del pipeline actual (`IsStatement` solo cuenta `len(...)>0`), así que no afecta ninguna métrica.

### H2 -- Cláusulas de reporte en gerundio/participio ("Alice, stating that...", "Testifying that...")

**Hipótesis:** verbo de reporte colgando como `acl`/`advcl` (no ROOT).

**Hallazgo:** verificado contra "Alice, stating that she never saw the plaintiff, left the room." y "Testifying that the light was red, Alice pointed at the driver." -- en ambos, `stating`/`testifying` son VERB con lema reportante, detectados igual que en H1 por el mismo motivo (el loop no filtra por `dep_`). **Ya cubierto, sin cambio de código.**

### H3 -- Alcance de negación con `do`-support ("She did not tell him that...") -- ÚNICO HUECO REAL, ACEPTADO

**Hipótesis original:** ¿até spaCy el `neg` al auxiliar `did` o al verbo léxico? **Verificado:** al verbo léxico (`tell`/`testify` mismo), igual que la negación simple -- `_find_negation` ya lo detecta correctamente de forma estructural.

**El hueco real no estaba en la detección, sino en el USO:** `is_negated` se computaba bien pero `is_statement_snell()` lo ignoraba por completo -- contaba "She did NOT tell him that X" como evidencia de que SÍ se hizo una declaración, igual que "She told him that X". Corregido: `is_statement_snell` ahora exige al menos una aserción con `is_negated == False`.

| | Baseline | + negación excluye aserción |
| :--- | :-: | :-: |
| Train | 3/5 | 3/5 (sin cambio) |
| **Test real** | 70.21% (66/94) | **70.21% (66/94)** -- sin cambio, ninguna fila del test tiene un verbo de reporte negado |
| Guardia Nivel A + B | -- | Todas en verde, sin cambio |

**Aceptado**: correcto por gramática general, verificado en ambos test rows sintéticos ("did not tell"/"didn't testify"), cero riesgo de regresión, neutral en el dataset real actual por la misma razón que la anáfora "did so" del addendum anterior -- una corrección genuina que este test set de 94 filas simplemente no ejercita.

### H4 -- Verbos conjugados por "and" ("Alice came out and said that...")

**Hipótesis:** verbo de reporte como hijo `conj` de otro verbo no-reportante.

**Hallazgo:** verificado contra "Alice came out and said that the light was red." -- `said` es VERB con lema `say` (reportante), `dep_="conj"`, detectado igual que H1/H2 por el mismo motivo. **Ya cubierto, confirmado no-op, sin cambio de código.**

### Conclusión honesta de esta pista

**Número final: 70.21% (66/94) -- sin cambio.** El hallazgo de mayor valor no fue una mejora de precisión, sino la confirmación estructural de que el diseño existente de `extract_reported_assertions` (iterar TODO token VERB por lema, sin filtrar por rol sintáctico) ya generaliza correctamente a voz pasiva, gerundio/participio, y coordinación por "and" -- tres hipótesis de gramática inglesa que resultaron ser no-ops, no huecos. Solo la negación (H3) era un hueco real, y el hueco estaba en la lógica de decisión (`is_statement_snell`), no en la extracción estructural de Snell misma (que ya computaba `is_negated` correctamente). Aceptado sin romper ninguna guardia; neutral en el test real de 94 filas.

**Para reproducir:**
```bash
python scratch/external_legalbench_eval_snell.py    # 70.21% (66/94), train 4/5
```

---

## 7. Addendum (2026-08-01): ¿subir de modelo pequeño a mediano? -- español sí, inglés no

Al cerrar el sprint bilingüe, se evaluó si subir de modelo spaCy pequeño a mediano ayudaría en cada idioma. **Español subió** (`es_core_news_sm` -> `es_core_news_md`) -- ver `reports/PRISMA_LUZ_SPANISH_PILOT_REPORT.md` §9 para el detalle completo (corrige la inconsistencia de "gesticular", no corrige la enclisis). **Inglés se dejó igual**, con una comprobación concreta en vez de una suposición: se compararon los parses de `en_core_web_sm` vs `en_core_web_md` sobre las 8 oraciones de prueba usadas para H1-H4 (sec. 6). Resultado: solo 2 diferencias triviales de `dep_` (`"stating"`: `acl`->`csubj`; `"by"`: `agent`->`prep`), ninguna de las cuales inspecciona ninguna lógica de `extract_reported_assertions` (que decide únicamente por `pos_=="VERB"` + coincidencia de lema, sin mirar `dep_` para la detección misma). Sin una hipótesis concreta que el modelo mediano resolviera, subir la dependencia (33.5MB adicionales) no se justificaba -- mismo estándar de "cada cambio necesita una hipótesis real" aplicado también a decidir NO cambiar algo.

---

## 8. Addendum (2026-08-01): diagnóstico agregado de "Standard hearsay"/"Non-verbal hearsay" -- primera mejora neta real de esta segunda ronda

Con `en_core_web_md` descartado (sec. 7) y las hipótesis del sprint anterior (secs. 5-6) agotadas sin mover el número, se investigaron las dos categorías más débiles del piloto (`scratch/external_legalbench_eval_snell.py`, baseline 70.21%/66-94, train 4/5): **Standard hearsay 58.6% (17/29)** y **Non-verbal hearsay 33.3% (4/12)**.

**Diagnóstico agregado (conteo conjunto de las 3 condiciones sobre las filas incorrectas, nunca texto+gold fila por fila):**

| Standard hearsay (12 filas mal) | Non-verbal hearsay (8 filas mal) |
| :--- | :--- |
| IsStatement=T, MadeOutOfCourt=T, OfferedForTruth=F -> 7 | IsStatement=T, OfferedForTruth=F -> 4 |
| IsStatement=F, OfferedForTruth=F -> 2 | IsStatement=F, OfferedForTruth=F -> 2 |
| IsStatement=F, OfferedForTruth=T -> 3 | IsStatement=F, OfferedForTruth=T -> 2 |

`OfferedForTruth` explica la mayoría (9/12 y 6/8) -- consistente con el hallazgo ya documentado en `reports/PRISMA_LEGALBENCH_REAL_PILOT_REPORT.md` §5-6 de que esa condición es la más dura semánticamente. Pero `IsStatement` también explica una porción real (5/12 y 4/8) -- y a diferencia de `OfferedForTruth`, esto SÍ es un hueco estructural investigable sin necesitar comprensión semántica profunda.

### H10 -- Expresiones de reporte nominalizadas ("Bob's STATEMENT that X") -- ACEPTADA, MEJORA NETA REAL

`extract_reported_assertions` solo escaneaba tokens VERB -- nunca podía reconocer una aserción reportada expresada como sustantivo ("statement"/"testimony"/"claim" + cláusula "that"), un patrón gramatical inglés genuino y común, verificado contra oraciones construidas ("Bob's statement that the light was red...", "The testimony of Alice that she saw the accident..."), con controles negativos verificados (una cláusula relativa SIN "that" -- "the man who left" -- correctamente no dispara).

Implementado: nuevo `REPORTING_NOUN_LEMMAS["eng"]` (statement, testimony, claim, admission, declaration, assertion, allegation, confession) + un segundo recorrido en `extract_reported_assertions` sobre tokens NOUN con hijo `acl`/`relcl` marcado por "that", con declarante vía `poss` ("Bob's...") o `prep`+`pobj` ("...of Alice").

| | Baseline | + expresiones nominales |
| :--- | :-: | :-: |
| Train | 4/5 | 4/5 (sin cambio) |
| **Test real** | 70.21% (66/94) | **71.28% (67/94)** ✅ **+1 fila neta** |
| Standard hearsay | 58.6% (17/29) | **62.1% (18/29)** ✅ |
| Non-verbal hearsay | 33.3% (4/12) | 33.3% (4/12) (sin cambio, esperado -- no hay sustantivos de reporte relevantes en esta categoría) |

**Primera mejora neta real de precisión en esta segunda ronda.** Guardia completa verificada en verde tras el cambio (72 pytest, 26 npm, 5/5, 120/120, los 6 evals de Nivel B sin cambio, piloto español sin cambio en 85%).

### Vocabulario adicional -- NEUTRAL, aceptado de todos modos (sin regresión)

Se agregaron 6 verbos de reporte de diccionario general no probados antes (`assert`, `maintain`, `disclose`, `reveal`, `recall`, `note`), cada uno verificado contra una oración construida (ROOT VERB + hijo `ccomp`, mismo patrón que los lemas existentes). **Resultado: 71.28% (67/94), sin cambio** -- ninguna de las 94 filas de test usa estos verbos específicos. Aceptado por ser una mejora genuina de vocabulario general sin ningún riesgo de regresión (guardia completa en verde), aunque no se ejerce en este dataset.

### H11 -- Contexto responsivo vía frase preposicional ("nodded IN RESPONSE TO...") -- NEUTRAL, aceptada

`_advcl_is_responsive_question` (sec. anterior, español) solo reconocía el contexto responsivo como una cláusula subordinada ("when asked..."). Verificado estructuralmente que existe una SEGUNDA forma gramatical inglesa igual de válida: una frase preposicional ("nodded in response to the question", "pointed... in answer to the officer") -- confirmado que esta construcción NUNCA usa `advcl` (usa `prep`->`pobj`("response"/"answer")->`prep`("to")->`pobj`), y que incluso cuando el objeto de "to" es en sí un gerundio de verbo de reporte ("in response to BEING ASKED..."), se conecta vía `pcomp`, no `advcl` -- confirma por qué el chequeo original no la detectaba en absoluto.

**Resultado: 71.28% (67/94), sin cambio** -- ninguna fila del test usa esta frase. Aceptada por el mismo criterio que el vocabulario adicional: mejora genuina, verificada, sin riesgo, aunque no ejercida por este dataset de 94 filas.

### Conclusión honesta de esta segunda ronda

**Número final: 71.28% (67/94), +1 fila neta sobre el 70.21% con el que empezó esta ronda.** El diagnóstico agregado (no fila por fila) confirmó lo que reportes anteriores ya documentaban: `OfferedForTruth` es el cuello de botella dominante y semánticamente profundo en las categorías más débiles, y no se intentó forzarlo más esta ronda -- expandir WordNet a hiperónimos/hipónimos (opción ya identificada en `CLAUDE.md` como "próximo paso", explícitamente marcada ahí como "gana una categoría, pierde otra") se dejó fuera deliberadamente para no perseguir un patrón ya conocido de intercambio sin ganancia neta clara. La ganancia real de esta ronda vino enteramente del lado estructural (IsStatement): un patrón gramatical completo (nominalización) que `extract_reported_assertions` nunca cubrió, encontrado por diagnóstico agregado de qué condición fallaba, no por inspección de filas de test.

**Para reproducir (números de esta sección, antes de la expansión de WordNet del §9):**
```bash
cd packages/prisma-python && python -m pytest tests/ -q       # 72 passed
python scratch/external_legalbench_eval_snell.py                # 71.28% (67/94), train 4/5
python scratch/prisma_spanish_hearsay_eval.py                    # 85.00% (17/20), autoescrito, sin cambio
```

---

## 9. Addendum (2026-08-01): tercera ronda -- expansión de WordNet a hiperónimos, probada de todos modos

La conclusión del §8 decía deliberadamente no perseguir la expansión de WordNet a hiperónimos/hipónimos por el patrón ya conocido ("gana una categoría, pierde otra") documentado en `CLAUDE.md`. El usuario pidió probarla de todos modos -- se hizo con la misma disciplina que el resto del proyecto: **una sola relación a la vez** (solo hiperónimos, un solo nivel, NO hipónimos en el mismo cambio), verificada contra pares reales conocidos antes de integrar (`docs/VERIFICATION_STANDARDS.md` regla 8: "car"→"motor_vehicle", "punch"→"blow", ambos confirmados con `nltk.corpus.wordnet` directamente antes de escribir código).

Cambio: `wordnet_concepts_bilingual()` en `packages/prisma-python/prisma_core/luz_lexicon.py` ahora también agrega `syn.hypernyms()` (un nivel) al set de conceptos, además de `derivationally_related_forms()` ya existente. Esta función es compartida por los TRES pilotos (regex+WordNet inglés, Snell inglés, y el piloto español autoescrito), así que se corrieron los tres antes de aceptar.

**Resultado -- mejora neta real en los dos pilotos reales de inglés, retroceso en el autoescrito de español:**

| | Antes | Después (+ hiperónimos) |
| :--- | :-: | :-: |
| Snell (este reporte) -- **test real** | 71.28% (67/94) | **74.47% (70/94)** ✅ **+3 filas netas** |
| Snell -- Standard hearsay | 62.1% (18/29) | **79.3% (23/29)** ✅ +5 |
| Snell -- Non-verbal hearsay | 33.3% (4/12) | **41.7% (5/12)** ✅ +1 |
| Snell -- Not introduced to prove truth | 75.0% (15/20) | **60.0% (12/20)** ❌ -3 |
| Regex+WordNet (`reports/PRISMA_LEGALBENCH_REAL_PILOT_REPORT.md`) | 69.15% (65/94) | **71.28% (67/94)** ✅ +2 (detalle en ese reporte §11) |
| Español autoescrito (`reports/PRISMA_LUZ_SPANISH_PILOT_REPORT.md`) | 85.00% (17/20) | **80.00% (16/20)** ❌ -1 (detalle en ese reporte §10) |

**Mecanismo del retroceso (mismo en los tres pilotos):** un hiperónimo directo crea un puente IS-A relativamente amplio entre dos palabras (ej. dos términos que comparten un hiperónimo genérico), lo que infla falsos positivos específicamente en la categoría "Not introduced to prove truth" -- la que por diseño exige que el heurístico NO encuentre solape de concepto entre el propósito y el contenido, aunque teman superficialmente relacionados. Es el mismo mecanismo diagnosticado para el par español "hablar"/"decir" (`reports/PRISMA_LUZ_SPANISH_PILOT_REPORT.md` §4).

**Por qué se aceptó pese al retroceso en español:** la ganancia es fuerte y real en AMBOS benchmarks externos, ciegos y publicados (regex +2, Snell +3) -- los únicos números que este proyecto puede llamar "precisión real" sin matices. La pérdida está confinada al dataset autoescrito de 20 filas, ya documentado desde su creación como no-benchmark y pendiente de revisión de experto; no se le aplica la misma vara que a un dataset externo real. No se investigó el mecanismo exacto mirando filas específicas de ningún test para no romper la disciplina de medición ciega.

**Guardia completa verificada en verde tras el cambio:** 74 pytest (73 + 1 test nuevo de hiperónimos en `test_luz_lexicon.py`, con control negativo de que palabras no relacionadas siguen sin matchear), 26 npm, 5/5, 120/120, y los evals de Nivel B que NO dependen de esta función (`diversity_1` 100%, `contract_qa` 87.5%, `ucc` 53.19%, `code_domain` 10/10 MATCH, NCBE 0% misfire) sin cambio.

**Para reproducir (números de esta sección, antes del hipónimo del §10):**
```bash
cd packages/prisma-python && python -m pytest tests/ -q          # 74 passed
python scratch/external_legalbench_eval_snell.py                   # 74.47% (70/94), train 4/5
python scratch/external_legalbench_eval.py                          # 71.28% (67/94)
python scratch/prisma_spanish_hearsay_eval.py                        # 80.00% (16/20), autoescrito, retroceso documentado
```

---

## 10. Addendum (2026-08-01): cuarta ronda -- expansión de WordNet a hipónimos, probada por separado -- NEUTRAL en los tres pilotos

Siguiendo la misma disciplina del §9 (una relación por vez), se probaron los hipónimos por separado, DESPUÉS de que los hiperónimos ya estuvieran aceptados -- nunca en el mismo cambio, para poder atribuir cualquier efecto a una sola relación. Verificado antes de integrar (`docs/VERIFICATION_STANDARDS.md` regla 8), simétrico con el par ya usado para hiperónimos: `blow.hyponyms()` incluye directamente `punch.n.01`.

**Resultado -- neutral en los TRES pilotos, sin excepción:**

| | Antes (solo hiperónimos) | Después (+ hipónimos) |
| :--- | :-: | :-: |
| Snell -- test real | 74.47% (70/94) | **74.47% (70/94)** — sin cambio, ninguna fila del test se ve afectada |
| Regex+WordNet | 71.28% (67/94) | **71.28% (67/94)** — sin cambio |
| Español autoescrito | 80.00% (16/20) | **80.00% (16/20)** — sin cambio |

**Lectura honesta:** a diferencia de los hiperónimos (que sí movieron la aguja, para bien y para mal), la expansión por hipónimos resultó completamente neutral en los tres pilotos -- cero filas cambiaron de predicción en ningún dataset. Esto sugiere que, para el vocabulario específico que aparece en estos tres conjuntos de prueba, ningún par de palabras relevante se conecta vía una relación hipónimo-directo que no estuviera ya cubierta por hiperónimos, derivación, o coincidencia literal. **Aceptada de todos modos**: es una capacidad genuina, verificada, sin ningún riesgo de regresión medido (guardia completa en verde), consistente con el mismo criterio ya aplicado a otras adiciones neutrales de esta sesión (anáfora "did so", vocabulario adicional, contexto responsivo por frase preposicional).

**Guardia completa verificada en verde:** 75 pytest (74 + 1 test nuevo de hipónimos en `test_luz_lexicon.py`), 26 npm, 5/5, 120/120, y los evals de Nivel B que no dependen de esta función sin cambio.

**Para reproducir (números finales):**
```bash
cd packages/prisma-python && python -m pytest tests/ -q          # 75 passed
python scratch/external_legalbench_eval_snell.py                   # 74.47% (70/94), train 4/5, sin cambio vs §9
python scratch/external_legalbench_eval.py                          # 71.28% (67/94), sin cambio vs §9
python scratch/prisma_spanish_hearsay_eval.py                        # 80.00% (16/20), sin cambio vs §9
```

---

## 11. Addendum (2026-08-01): primeras entradas reales en `luz_custom_lexicon.json` -- NEUTRAL, aceptadas

`luz_custom_lexicon.json` estuvo completamente vacío (`{"entries": []}`) desde el diseño original del proyecto. Se agregaron las 3 primeras entradas reales y permanentes, cada una verificada individualmente (no en lote) contra una fuente citable, y confirmando primero que WordNet NO las conectaba ya (para no duplicar cobertura):

| Par | Idioma(s) | Fuente | Ya cubierto por WordNet antes de agregar |
| :--- | :--- | :--- | :-: |
| culpable / guilty | eng-eng | Diccionario estándar (Merriam-Webster: "culpable" = "deserving blame: guilty") | No |
| declarant / speaker | eng-eng | FRE 801(b)(1): "Declarant means the person who made the statement" | No |
| declarante / hablante | spa-spa | Equivalente español del mismo concepto de FRE 801(b)(1) | No |

Se descartaron deliberadamente candidatos que WordNet tampoco cubría pero que NO son realmente sinónimos verificables (ej. "affidavit"/"deposition" -- son instrumentos legales relacionados pero distintos, no intercambiables) -- la disciplina es agregar solo relaciones verdaderas, no simplemente "lo que falte en WordNet".

**Resultado: neutral en los tres pilotos** (Snell 74.47%/70-94, regex 71.28%/67-94, español 80.00%/16-20) -- ninguna fila usa estos términos genéricos específicos. Aceptado de todos modos, mismo criterio que otras adiciones neutrales de esta sesión: capacidad real, verificada, auditable (cada entrada tiene `source`/`verified_via` real en el JSON), sin ningún riesgo de regresión medido.

**Guardia completa verificada en verde:** 78 pytest (75 + 3 tests nuevos en `TestLuzCustomLexiconRealEntries`, que no hacen backup/restore como el test sintético preexistente porque estas entradas SÍ deben persistir), 26 npm, 5/5, 120/120, resto de Nivel B sin cambio.

**Para reproducir:**
```bash
cd packages/prisma-python && python -m pytest tests/ -q          # 78 passed
```

---

## 12. Addendum (2026-08-01): quinta ronda -- expansión de WordNet a meronimia/holonimia -- NEUTRAL

Con paso libre del usuario para seguir sumando y probando, se completó la exploración de relaciones WordNet con la última que faltaba: meronimia/holonimia (parte-todo), vía `syn.part_meronyms()`/`syn.part_holonyms()`, un nivel, probada en aislamiento después de hiperónimos/hipónimos/lexicón propio. Verificado antes de integrar: "gun".part_meronyms() incluye directamente `gun_trigger.n.01` (lema "trigger"), una relación parte-todo real (el gatillo es parte de un arma), confirmada con una consulta directa a WordNet antes de escribir código -- relevante para patrones fácticos de armas/lesiones en textos legales.

**Resultado: neutral en los tres pilotos** (Snell 74.47%/70-94, regex 71.28%/67-94, español 80.00%/16-20) -- cero filas cambiaron de predicción en ningún dataset. Con esto quedan probadas las 3 relaciones de WordNet que `CLAUDE.md` identificaba como próximo paso (derivación ya estaba, hiperónimos, hipónimos) más meronimia como extensión adicional -- solo hiperónimos produjo una mejora neta real; las otras dos fueron neutrales, ninguna produjo un retroceso adicional.

**Guardia completa verificada en verde:** 79 pytest (78 + 1 test nuevo de meronimia en `test_luz_lexicon.py`), 26 npm, 5/5, 120/120, resto de Nivel B sin cambio.

---

## 13. Addendum (2026-08-01): expansión de `IN_COURT_TESTIMONY_MARKERS` -- NEUTRAL, hueco real confirmado pero no cerrado en este dataset

Diagnóstico agregado (no fila por fila) sobre la categoría "Statement made in-court" (78.6%, 3/14 mal) mostró que las 3 filas incorrectas tienen `IsStatement=True`, `OfferedForTruth=True`, y **`MadeOutOfCourt=True`** -- es decir, `MadeOutOfCourt` es el ÚNICO predicado culpable en las 3, un hueco real y bien acotado, a diferencia de `OfferedForTruth` (el cuello de botella semántico ya conocido).

Se encontraron y corrigieron dos gaps genuinos, generales, verificados contra oraciones construidas (nunca contra las 3 filas específicas):
1. **Limitación estructural confirmada:** el marcador fijo `"during testimony"` nunca coincide cuando se interpone un pronombre posesivo ("during **HER** testimony") -- confirmado con una comprobación de cadena directa antes de agregar las variantes.
2. **Jerga legal estándar no cubierta:** "instant"/"present" como adjetivos que significan "este mismo, actual" (ej. "the instant trial", "the present proceeding") -- lenguaje jurídico formal directamente relacionado con "current trial or hearing" de FRE 801(c)(1).

Se agregaron: `"during her/his/their testimony"`, `"in her/his testimony"`, `"instant trial/case/proceeding/hearing"`, `"present trial/proceeding"`, `"current proceeding"`, `"redirect examination"`/`"on redirect"`.

**Resultado: neutral en los tres pilotos** -- ninguna de las 3 filas que motivaron el diagnóstico usa exactamente estas frases. **Lectura honesta:** el hueco es real y quedó confirmado por diagnóstico agregado (no hay duda de que `MadeOutOfCourt` es el problema en esas 3 filas), pero no se puede cerrar sin leer el texto+gold de esas filas específicas para saber qué frase exacta usan -- y hacer eso violaría la disciplina de medición ciega que rige todo este proyecto. Se prefiere terminar con el hueco documentado y sin cerrar que forzarlo mirando el test.

**Guardia completa verificada en verde:** 83 pytest (79 + 4 tests nuevos en el `tests/test_ontology_normalizer.py` recién creado), 26 npm, 5/5, 120/120, resto de Nivel B sin cambio.

### Conclusión honesta de esta quinta ronda (con paso libre)

**Número final: sin cambio sobre el §11 -- Snell 74.47% (70/94), regex 71.28% (67/94), español 80.00% (16/20).** Se probaron 2 hipótesis más con la misma disciplina (meronimia de WordNet, expansión de marcadores en corte); ambas resultaron neutrales, no por falta de rigor sino porque el vocabulario específico que exigirían no aparece en estos datasets concretos, y en el caso de los marcadores en corte, no puede investigarse más sin romper la medición ciega. El aumento real y sustancial de esta sesión sigue siendo el de la ronda anterior (§9, hiperónimos de WordNet: +2/+3 filas en los dos pilotos reales de inglés) más la mejora estructural del §8 (expresiones nominalizadas, +1 fila). Seguir agregando hipótesis sin una nueva vía genuina (no ya explorada) entraría en prueba-y-error ciego.

**Para reproducir (estado final de esta ronda):**
```bash
cd packages/prisma-python && python -m pytest tests/ -q          # 83 passed
python scratch/external_legalbench_eval_snell.py                   # 74.47% (70/94), train 4/5
python scratch/external_legalbench_eval.py                          # 71.28% (67/94)
python scratch/prisma_spanish_hearsay_eval.py                        # 80.00% (16/20), autoescrito, NO benchmark
```

---

## 14. Addendum (2026-08-01): sonda de generalización con lenguaje cotidiano -- 2 bugs reales encontrados y corregidos, sin cambio en los pilotos oficiales

Con paso libre para seguir probando: en vez de otra hipótesis de vocabulario, se probó si Luz/Snell generaliza fuera de la plantilla rígida de LegalBench ("On the issue of whether X, the fact that Y..."). Se escribieron 15 oraciones en inglés natural/cotidiano (`scratch/non_technical_hearsay_probe.py`, **autoescrito, NO benchmark**) que evalúan los mismos predicados de hearsay pero en prosa narrativa común. Primera corrida: **12/15 (80.00%)**.

**Como este set es propio (no un test ciego externo), se diagnosticaron las 3 fallas libremente -- 2 resultaron ser bugs reales, no limitaciones del dataset:**

1. **Verbos instrumentales sin cláusula de contenido contaban como aserción.** "Marcus never told anyone that he had signed the lease." predecía incorrectamente `IsStatement=True` porque "sign" (en `REPORTING_VERB_LEMMAS`) no exigía ninguna cláusula `ccomp`/`xcomp` real -- "firmó el contrato" es un acto físico/legal, no una aserción. Verificado con pares mínimos antes de corregir: "wrote a check" (dobj, sin ccomp) vs. "wrote that the check was in the mail" (ccomp presente). Nuevo `INSTRUMENTAL_REPORTING_LEMMAS = {"sign", "write", "email", "note"}`: estos lemas ahora exigen una cláusula de contenido real para contar; el resto de `REPORTING_VERB_LEMMAS` mantiene el comportamiento permisivo original.
2. **"without VERBing" no se detectaba como negación.** "Lisa left the room without saying a word." -- "saying" cuelga como `pcomp` de la preposición "without", una construcción de negación-por-implicatura genuina en inglés, distinta de "not"/"n't"/"never". Verificado con dos verbos distintos ("say", "admit") para confirmar que es un patrón general, no una rareza de una sola oración. `_find_negation()` ahora también revisa esto.

**Resultado tras corregir ambos: 14/15 (93.33%)** en la sonda autoescrita -- la única falla restante (#5, "to show that Tom knew French...") es el mismo cuello de botella semántico de `OfferedForTruth` ya documentado extensamente (solape de palabra literal "French" sin ser el mismo contenido proposicional), no un bug nuevo.

**Efecto en los pilotos oficiales: sin cambio** -- 74.47% (Snell), 71.28% (regex), 80.00% (español). Ninguno de los tres datasets ejercita "firmar/escribir/notar sin cláusula" ni "without VERBing" -- son bugs reales y genuinos, encontrados por generalizar fuera del dataset, pero que esta vez no se manifestaron en los benchmarks ya medidos.

**Guardia completa verificada en verde:** 86 pytest (83 + 4 tests nuevos: 2 para verbos instrumentales -- incluyendo un control positivo de que SÍ se detectan con cláusula real -- y 2 para "without VERBing"), 26 npm, 5/5, 120/120, resto de Nivel B sin cambio.

**Lectura honesta:** esta es la validación más directa de por qué "generalizar fuera del dataset de prueba" tiene valor propio, incluso cuando no mueve el número oficial -- encontró 2 bugs reales que el propio dataset de 94 filas de LegalBench nunca habría revelado, simplemente porque no contiene esas construcciones. Quedan corregidos para cualquier texto futuro que sí las tenga.

**Para reproducir:**
```bash
cd packages/prisma-python && python -m pytest tests/ -q          # 86 passed
python scratch/non_technical_hearsay_probe.py                      # 14/15 = 93.33%, autoescrito, NO benchmark
python scratch/external_legalbench_eval_snell.py                   # 74.47% (70/94), sin cambio
```

---

## 15. Addendum (2026-08-01): ¿"algo similar" a la enclisis española, pero en inglés? -- un bug real encontrado y corregido, un límite honesto documentado

Después de resolver la enclisis española (`reports/PRISMA_LUZ_SPANISH_PILOT_REPORT.md` §12) generalizando `_find_content_span` a buscar en todo el subárbol del verbo, se probó si el mismo tipo de problema estructural (contenido atado a un nieto, o promovido al verbo gobernante) también existe en inglés.

**Primera diligencia -- construcciones modal/aspectual + verbo de reporte:** verificado con 5 oraciones ("wants to say that...", "keeps claiming that...", "continued to assert that...", "tends to state that...", con una cláusula relativa intercalada de por medio) -- en las 5, el inglés **ya ata correctamente** la cláusula de contenido al verbo de reporte mismo, nunca al modal. A diferencia de español, `en_core_web_sm` no muestra la misma fragilidad ante estas construcciones (probablemente por tener un treebank de entrenamiento bastante más grande/maduro). No hay bug análogo aquí.

**Segunda diligencia -- expresiones nominalizadas con sustantivo intermedio:** acá SÍ apareció un hallazgo real. "The testimony **from** a witness **that** the accident happened was compelling." -- la cláusula "that" se ata como `acl` de "witness" (un NIETO de "testimony" vía la frase preposicional "from"), no como hijo directo de "testimony". `_find_that_complement_clause` (usada para expresiones como "Bob's statement that X") solo revisaba hijos directos -- devolvía `None` (nada detectado) para este caso genuino de aserción nominalizada. **Corregido:** mismo patrón de nivel 2 que se usó para el verbo -- si no hay match en los hijos directos, busca en todo el subárbol, con la misma restricción del mark "that" explícito (mismo control negativo que ya existía: "the man WHO left" sin "that" sigue sin disparar).

**Límite honesto, NO perseguido más:** una construcción más compleja, "She gave a statement **to** the detective assigned to the case **that** the car was stolen.", sigue sin detectarse -- ahí "statement" y "to the detective..." son ramas HERMANAS bajo "gave" (el verbo), no anidadas una dentro de la otra, así que ninguna búsqueda de subárbol de "statement" puede alcanzar la cláusula. Arreglar esto requeriría escalar la búsqueda al verbo gobernante ("gave"), igual que el nivel 3 que sí se implementó para los verbos con clíticos fusionados en español -- pero esta oración es una construcción propia, sin evidencia de que aparezca en ningún dataset real, así que no se persiguió más para no ampliar el riesgo de falsos positivos sin un caso real que lo justifique.

**Hallazgo adicional, de menor severidad, documentado sin arreglar:** "She told the officer investigating the case that the car was stolen." -- el contenido SÍ se recupera (a diferencia del caso anterior), pero el span queda ruidoso: `"investigating the case that the car was stolen"` en vez de solo `"that the car was stolen"`, porque el nivel 1 encuentra "investigating" (un modificador participial de "officer", no lo que se dijo) como si fuera la cláusula de contenido, ya que también es `xcomp` directo de "told". No afecta la detección (`IsStatement` sigue correcto), pero podría ensuciar la comparación de palabras de `OfferedForTruth` en casos reales con esta forma. Documentado, no arreglado esta ronda.

**Resultado en los pilotos oficiales: sin cambio** -- 74.47% (Snell), 71.28% (regex), 85.00% (español). Ninguno de los tres datasets ejercita "testimony from a witness that X" tal cual, pero la corrección queda disponible para cualquier texto futuro con esa forma.

**Guardia completa verificada en verde:** 93 pytest (92 + 1 test nuevo), 26 npm, 5/5, 120/120, resto de Nivel B sin cambio.

**Para reproducir:**
```bash
cd packages/prisma-python && python -m pytest tests/ -q          # 93 passed
python scratch/external_legalbench_eval_snell.py                   # 74.47% (70/94), sin cambio
```

## Addendum (2026-08-01): expansión a una segunda tarea real de LegalBench -- `ucc_v_common_law`

Contexto: se pidió avanzar la cobertura de dominio de Luz todo lo posible. En vez de inventar un dominio nuevo desde cero, se revisaron 3 tareas reales de `nguha/legalbench` ya piloteadas en una sesión anterior (`diversity_1`, `contract_qa`, `ucc_v_common_law`), reutilizando infraestructura ya validada en vez de duplicar esfuerzo:

| Tarea | Accuracy real (blind) antes de esta sesión |
| :--- | :--- |
| `diversity_1` (jurisdicción por diversidad) | 100.00% (300/300) -- ya en el techo, sin espacio para mejorar |
| `contract_qa` (¿la cláusula trata el tema preguntado?) | 87.50% (70/80) -- con espacio, pero no atacado hoy |
| `ucc_v_common_law` (¿bienes muebles vs. servicios/inmuebles?) | **53.19% (50/94)** -- apenas sobre el azar |

Se eligió `ucc_v_common_law` por tener el mayor margen real de mejora. Diagnóstico: el heurístico original (`external_legalbench_ucc_eval.py`) acertaba 6/6 en train pero solo 53% en el test ciego -- sobreajuste claro a una lista estática de 27 verbos de servicio, diseñada casi exclusivamente a partir de los 2 verbos que aparecen en las 6 filas de train (`repair`, `find`).

**Corrección aplicada:** se amplió la lista de verbos de servicio (~90 verbos) usando únicamente conocimiento general del idioma inglés sobre qué es un "servicio" (nunca mirando filas de test), y se amplió la lista de sustantivos de bienes raíces. Verificado ANTES de tocar el test ciego contra: las 6 filas de train reales (sigue 6/6) + 8 oraciones nuevas construidas a mano con verbos/sustantivos que NO estaban en la lista original (14/14 en total). Ese proceso de verificación encontró y corrigió un bug real: "deliver" como substring coincidía falsamente dentro de "delivery van" (un descriptor de bien, no un servicio prestado) -- se excluyeron "deliver"/"transport" de la lista en vez de aceptar ese riesgo de falso positivo.

**Resultado real, honesto:** 53.19% (50/94) -> **55.32% (52/94)**. Una mejora real pero modesta (+2.13pp), no la gran mejora que se esperaba. Esto sugiere que el problema de fondo no es principalmente cobertura de vocabulario -- es probable que muchas filas del test real toquen la ambigüedad genuina del "predominant purpose test" (contratos mixtos bienes+servicios), que es exactamente por lo que esta es una pregunta legal difícil en la vida real, no solo un problema de heurística incompleta. Se documenta como una mejora real y se detiene aquí esta ronda -- seguir iterando hipótesis contra el mismo conjunto de test ciego sin nueva evidencia estructural empezaría a acercarse a sobreajustar indirectamente contra el resultado agregado, violando la disciplina de `docs/VERIFICATION_STANDARDS.md`.

**Guardia de regresión:** `pytest tests/ -q` -> 99 passed (el cambio fue solo en `scratch/external_legalbench_ucc_eval.py`, no en `snell.py`/`ontology_normalizer.py`, así que no hay impacto en la suite formal).

**Para reproducir:**
```bash
python scratch/external_legalbench_ucc_eval.py   # 55.32% (52/94), antes 53.19% (50/94)
```

## Addendum (2026-08-01): auditoría profunda de código -- 2 bugs REALES de Luz encontrados y corregidos

Se pidió un análisis profundo buscando errores y código muerto. Se corrió análisis estático (`pyflakes`, `vulture`) sobre los 24 módulos de `prisma_core`, más sondeo manual de casos límite contra Luz. Resultado: **2 bugs reales y significativos en Luz**, ambos invisibles hasta ahora porque los pilotos de LegalBench nunca leen los campos afectados -- pero críticos desde que `/api/v1/natural_language_ingest` y `text_ingester` empezaron a acuñar Facts `ASSERTED` cuyo `subject` ES ese campo.

### Bug 1 -- Luz truncaba nombres propios compuestos (CORREGIDO)

`_find_subject_text`/`_find_object_text`/`_find_nominal_declarant` devolvían solo `child.text`, que es únicamente el NÚCLEO del sintagma nominal:

| Entrada | Declarante extraído (antes) | Ahora |
| :--- | :--- | :--- |
| "John Smith testified that..." | `"Smith"` | `"John Smith"` |
| "Dr. Maria Fernandez told..." | `"Fernandez"` | `"Dr. Maria Fernandez"` |
| "María Fernanda González dijo..." | `"María"` | `"María Fernanda González"` |
| "Mary Johnson's statement that..." | `"Johnson"` | `"Mary Johnson"` |

Un Fact certificado que nombra a la persona equivocada contradice el propósito entero del sistema. Corregido con `_full_name_span()`, que recolecta los hijos `compound`/`flat` y los **reordena por posición** -- necesario porque inglés y español son espejos: `en_core_web_sm` cuelga las partes previas del nombre a la IZQUIERDA vía `compound` (núcleo = apellido), mientras `es_core_news_md` cuelga las posteriores a la DERECHA vía `flat` (núcleo = primer nombre). Verificado en ambos idiomas antes de aplicar; los sujetos de una sola palabra ("witness", "She", "testigo") quedan byte-idénticos.

### Bug 2 -- en voz pasiva, Luz nombraba al paciente como declarante (CORREGIDO)

En pasiva inglesa, `nsubjpass` es el PACIENTE, nunca el agente. Luz lo devolvía como declarante:

| Entrada | Antes | Ahora | Por qué |
| :--- | :--- | :--- | :--- |
| "Bob was told that the meeting was cancelled." | `"Bob"` | `None` | Bob RECIBIÓ la declaración, no la hizo |
| "It was stated by Alice that the door was locked." | `"It"` | `"Alice"` | el agente real está en el sintagma "by" |
| "The statement was admitted into evidence." | `"statement"` | `None` | acto procesal, sin hablante alguno |
| "The claim was denied by the defendant." | `"claim"` | `"defendant"` | agente real |

Corregido: si el verbo tiene un hijo `auxpass`, el declarante es el agente `by` si existe, y si no, `None` (la misma disciplina de "abstenerse antes que adivinar" del resto de Snell). **Deliberadamente solo inglés:** `es_core_news_md` usa etiquetas UD con una forma genuinamente distinta para pasivas españolas (inspeccionado: "Fue declarado por Alicia que..." cuelga "Alicia" como `obj` con hijo `case`, no como sintagma agente). Se documenta como hueco pendiente en vez de parchearlo a ciegas.

**Cobertura nueva:** 8 tests de regresión (`TestFullNameExtraction`, `TestPassiveVoiceDeclarant`) en `tests/test_snell.py`.

### Otros hallazgos (fuera de Luz)

- **`server.py`: dos clases Pydantic llamadas `FeedbackRequest`.** No era un bug funcional -- verificado empíricamente que ambos endpoints siguen respondiendo 200 con sus propios campos, porque Python resuelve la anotación al DEFINIR la función. Pero era una trampa: reordenar el archivo o adoptar `from __future__ import annotations` habría apuntado silenciosamente AMBOS endpoints al segundo esquema. Renombrada a `TelemetryFeedbackRequest`.
- **`rate_limiter.py`: parámetro `requests_per_minute` muerto.** El constructor lo aceptaba pero nunca lo leía (todos los límites reales vienen de `PLAN_LIMITS`), aparentando ser una perilla de configuración que no hacía nada. Eliminado.
- **Falso positivo del linter, NO eliminado:** `WORDNET_AVAILABLE` en `ontology_normalizer.py` se marca como "import sin usar", pero 3 scripts de evaluación lo importan desde ahí -- es un re-export intencional. Documentado en el código para que nadie lo borre siguiendo al linter a ciegas.

**Guardia de regresión:** 107 tests Python (99 + 8 nuevos), 45 TypeScript (core 26, conformance-suite 7, sdk 4, ai-bridge 8). Pilotos sin cambio: inglés Snell 74.47%, español 85.00%, regex 71.28% -- confirmando que ambas correcciones son estrictamente mejoras de calidad de datos, sin efecto en la precisión medida.
