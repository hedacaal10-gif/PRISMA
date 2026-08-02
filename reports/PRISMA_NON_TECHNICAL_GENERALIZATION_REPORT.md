# PRISMA — Pruebas de generalización con texto no técnico

**Fecha:** 1 de agosto, 2026
**Propósito:** el trabajo de esta sesión hasta ahora se centró en un solo dominio (hearsay, `nguha/legalbench`). Este reporte documenta dos pruebas deliberadamente distintas al dominio legal formal, para responder dos preguntas separadas: (1) ¿la extracción de Luz/Snell generaliza a lenguaje natural cotidiano, no solo a la plantilla rígida de LegalBench? (2) ¿el motor de PRISMA sigue razonando con 100% de precisión en un dominio completamente distinto al legal, aislado de cualquier heurística de extracción?

> ⚠️ Ambas pruebas son **autoescritas por el equipo de PRISMA**, no datasets externos publicados. Se documentan con la misma disciplina de honestidad que el resto del proyecto (`docs/VERIFICATION_STANDARDS.md`) -- nunca deben presentarse como "benchmark" ni compararse numéricamente con `nguha/legalbench`.

---

## 1. Sonda de generalización con lenguaje cotidiano (`scratch/non_technical_hearsay_probe.py`)

**Qué prueba:** si Luz/Snell (`extract_features`/`is_statement_snell`/`made_out_of_court`/`offered_for_truth`, las mismas funciones ya validadas contra el piloto real de LegalBench) siguen funcionando cuando el texto de entrada es prosa narrativa cotidiana en vez de la plantilla formulaica "On the issue of whether X, the fact that Y..." que usa el dataset real.

**Diseño:** 15 oraciones en inglés natural, escritas por el equipo, cubriendo los mismos escenarios de hearsay que el dataset real (standard hearsay, no ofrecido para la verdad, testimonio en corte actual, aserción no verbal, conducta no asertiva, negación, testimonio de proceso previo, voz pasiva, expresión nominalizada). Respuesta esperada: análisis FRE 801 propio del equipo, no una fuente externa.

**Resultado primera corrida: 12/15 (80.00%).**

**Diagnóstico libre de las 3 fallas (legítimo porque este set es propio, no un test ciego externo) -- 2 resultaron ser bugs reales:**

1. **Verbos instrumentales sin cláusula de contenido contaban como aserción.** "Marcus never told anyone that he had signed the lease." predecía `IsStatement=True` incorrectamente porque "sign" (parte de `REPORTING_VERB_LEMMAS`) no exigía ninguna cláusula de contenido (`ccomp`/`xcomp`) real para contar -- firmar un contrato es un acto físico/legal, no necesariamente una aserción. Verificado con pares mínimos: "wrote a check" (objeto directo, sin cláusula) vs. "wrote that the check was in the mail" (cláusula presente). **Corregido:** nuevo `INSTRUMENTAL_REPORTING_LEMMAS = {"sign", "write", "email", "note"}` en `snell.py` -- estos lemas ahora exigen una cláusula de contenido real; el resto del vocabulario mantiene el comportamiento original.
2. **"without VERBing" no se detectaba como negación.** "Lisa left the room without saying a word." -- "saying" cuelga como `pcomp` de la preposición "without", una construcción de negación-por-implicatura genuina en inglés. Verificado con dos verbos distintos ("say", "admit") para confirmar que generaliza. **Corregido:** `_find_negation()` ahora también revisa este patrón.

**Resultado tras corregir: 14/15 (93.33%).** La única falla restante (#5, "to show that Tom knew French...") es el mismo cuello de botella semántico de `OfferedForTruth` ya documentado extensamente en este proyecto (solape de palabra literal "French" entre propósito y contenido, sin ser el mismo contenido proposicional) -- no un bug nuevo, la misma limitación conocida del enfoque de solape de palabras/conceptos.

**Efecto en los pilotos oficiales: sin cambio** -- 74.47% (Snell), 71.28% (regex), 80.00% (español). Ninguno de los tres datasets ya medidos ejercita estos dos patrones específicos.

**Lectura honesta:** esta prueba tiene valor propio incluso sin mover el número oficial -- encontró 2 bugs reales y genuinos que el dataset de 94 filas de LegalBench nunca habría revelado, porque simplemente no contiene esas construcciones. Quedan corregidos para cualquier texto futuro que sí las tenga. Es la validación más directa de que "generalizar fuera del dataset de prueba" no es un ejercicio cosmético.

---

## 2. Motor aislado en dominio no-legal (`scratch/non_technical_engine_isolation_test.py`)

**Qué prueba:** si `PrismaCoreEngine.infer()` sigue deduciendo con 100% de precisión en un dominio completamente ajeno al legal -- mismo espíritu que `reports/PRISMA_ENGINE_STRUCTURAL_STRESS_TEST_REPORT.md` (que usó escenarios de examen de la barra codificados a mano), pero con un dominio cotidiano y verificable por cualquiera a simple vista: relaciones familiares, elegibilidad para un descuento, y una cláusula de contrato de arriendo. **Cero Luz, cero Snell, cero regex, cero LLM** -- cada Fact se construye a mano en Python, exactamente igual que el stress test original, para aislar el motor de cualquier heurística de extracción.

**4 patrones estructurales probados, cada uno verificable a simple vista:**

| Patrón | Escenario | Resultado esperado | Resultado real |
| :--- | :--- | :--- | :-: |
| Cadena AND de 2 pasos | "A es padre de B" + "B es padre de C" → "A es abuelo de C"; luego + "viven en la misma casa" → descuento familiar | `SUCCESS`, `SUCCESS` | ✅ |
| Premisa falsa rechazada | "B NO es padre de C" → NO se deriva "A es abuelo de C" | `UNSATISFIED_PREMISES` | ✅ |
| Lógica OR (2 reglas alternativas, mismo consecuente) | Descuento por adulto mayor (falla) O por certificado de discapacidad (sí aplica) → mismo resultado final de elegibilidad | `UNSATISFIED_PREMISES` luego `SUCCESS` | ✅ |
| Cadena de 3 niveles + corte temprano | Tener perro + vivir en depto → requiere depósito → no pagarlo → incumplimiento de contrato; variante: vive en casa propia → se corta en el nivel 2 | `SUCCESS` x3, luego `SUCCESS`+`UNSATISFIED_PREMISES` en la variante | ✅ |

**Resultado: 10/10 = 100.00%.**

**Lectura honesta:** confirma, en un dominio totalmente distinto al legal, la misma separación de capacidades que este proyecto documenta desde el inicio (`docs/VERIFICATION_STANDARDS.md` §3): el motor deduce correctamente de forma determinista, domain-agnostic, independiente de qué tan bien o mal funcione la extracción de texto crudo en cualquier dominio particular. Esta prueba NO mide extracción (no hay texto crudo de entrada) -- mide únicamente el motor mismo, igual que el stress test legal original.

---

## 3. Conclusión

Las dos preguntas planteadas al inicio quedan respondidas honestamente:
1. **¿Luz/Snell generaliza a lenguaje cotidiano?** Parcialmente sí, y el ejercicio encontró 2 bugs reales ya corregidos; la limitación restante es la ya conocida (`OfferedForTruth`), no una nueva.
2. **¿El motor sigue en 100% en un dominio no-legal?** Sí, sin excepción, en los 4 patrones estructurales probados.

**Para reproducir:**
```bash
python scratch/non_technical_hearsay_probe.py            # 14/15 = 93.33%, autoescrito, NO benchmark
python scratch/non_technical_engine_isolation_test.py     # 10/10 = 100.00%, motor aislado, NO benchmark
cd packages/prisma-python && python -m pytest tests/ -q  # 86 passed (incluye los 4 tests de regresión de los bugs encontrados aquí)
```
