# PRISMA Verification Standards

**Estado:** Estándar operativo, derivado de la práctica (2026-07-31 a 2026-08-01).
**Propósito:** codificar en un solo lugar la disciplina de verificación que este proyecto sigue, para que ningún reporte o benchmark futuro tenga que re-justificarla desde cero, y para que sea auditable por cualquiera que revise el repositorio.

Este documento nació de una auditoría que encontró que la afirmación insignia del proyecto ("100% Stanford LegalBench") era una suite sintética autoevaluada, no una evaluación contra el dataset real. Las siguientes reglas existen para que ese error no se repita, en ningún dominio.

---

## 1. Toda prueba futura debe citar una fuente externa real

Un caso de prueba (input + respuesta esperada) solo cuenta como **verificación** si viene de una fuente que PRISMA no controla: un dataset académico publicado (ej. `nguha/legalbench` en HuggingFace), un documento gubernamental de dominio público (ej. estatutos vía Cornell LII), o material con licencia clara aportado por el usuario. La fuente exacta (URL, ID de dataset, fecha de descarga) debe quedar citada en el reporte, no solo en un comentario de código.

**Qué no cuenta como verificación:** casos de prueba escritos por el propio equipo/agente, aunque estén bien diseñados y sean pedagógicamente correctos. Eso es una suite sintética — útil para probar que el motor deduce bien dado un encoding correcto, pero nunca debe presentarse como "benchmark" o "evaluación".

---

## 2. Ninguna respuesta esperada autoescrita se presenta como resultado de benchmark

Si el equipo/agente escribió la respuesta esperada, el reporte debe decir explícitamente "suite sintética" o "autoevaluado" en el título y en la primera sección — no en una nota al pie. Ver `reports/PRISMA_LEGALBENCH_EVALUATION_REPORT.md` como ejemplo de cómo corregir un reporte que originalmente no cumplía esto.

---

## 3. Separar siempre la afirmación del motor de la afirmación de la extracción

Son dos capacidades distintas y hoy tienen madurez muy distinta:
- **(a) "Dado un Fact/Rule bien codificado, ¿el motor deduce correctamente?"** — bien soportada. Verificada en vivo repetidamente: 5/5 suite de upgrade, test de regresión de coincidencia de antecedentes, 100% real en `diversity_1` (300/300) y en la categoría "Non-assertive conduct" de hearsay (19/19), y 3/3 en el stress test estructural con Facts codificados a mano (`reports/PRISMA_ENGINE_STRUCTURAL_STRESS_TEST_REPORT.md`).
- **(b) "Dado texto real crudo, ¿el pipeline de PRISMA extrae los Facts/Rules correctos?"** — mucho más débil y variable (0% "fiel" en los primeros reportes de ingesta; 53%-100% en los pilotos de LegalBench según qué tan mecánica sea la tarea).

Ningún reporte debe fusionar (a) y (b) en un solo número de "precisión de PRISMA". Cuando algo falla, hay que rastrear la causa hasta una de las dos, y decirlo.

---

## 4. Disciplina de "congelar antes de medir"

Toda heurística de extracción se diseña usando **solo**: (a) el split de entrenamiento/pocos ejemplos que el propio dataset provee para ese fin, y (b) conocimiento de dominio general verificable (texto real de la ley, documentación de un lenguaje de programación, un libro de texto). Se congela, se corre **una vez** contra el conjunto de prueba real, y el resultado se reporta tal cual salga — bueno o malo.

**Excepción explícita y documentada:** si una corrida revela un bug conceptual en el propio código (ej. el bug del `\$` como disparador financiero aislado), corregirlo y volver a correr **una vez** es válido — pero el hallazgo del bug debe venir de un patrón agregado o de una revisión honesta del propio diseño, nunca de mirar filas de test específicas para encontrar qué patrón las haría pasar.

**Diagnóstico agregado, no fila por fila:** al comparar dos métodos (ej. regex vs. LLM), es legítimo mirar estadísticas agregadas ("¿qué predicado difiere en los casos donde un método le gana al otro?") para dirigir una mejora. No es legítimo leer el texto de filas de test específicas y escribir una regla que las haga pasar — eso es ajustar contra el test, aunque el resultado final "se vea bien".

---

## 5. Reportar mejoras Y retrocesos con el mismo detalle

Cuando una iteración empeora el número real (ej. la primera versión del normalizador de sinónimos: 65.96% → 62.77%), eso se documenta con el mismo nivel de detalle que una mejora, incluyendo el mecanismo diagnosticado. Ver `reports/PRISMA_LEGALBENCH_REAL_PILOT_REPORT.md` §4 para el ejemplo canónico. Ocultar o minimizar un retroceso repite exactamente el problema que motivó este documento.

---

## 6. Reproducibilidad: fijar explícitamente la configuración que un reporte publicado mide

Si un script produce un número que queda documentado en un reporte, ese script debe fijar explícitamente cualquier configuración de la que ese número dependa (ej. `PrismaMicroAIExtractor(use_embedded_neural=False)` en los scripts de la Fase 2/3), para que instalar una dependencia nueva en la máquina (como el modelo local) no cambie silenciosamente resultados ya publicados. Antes de reportar cualquier número, re-correr el script y confirmar que reproduce exactamente lo ya documentado.

---

## 7. Material con licencia restringida: mínimo, atribuido, y con alcance explícito

Material gratuito pero no abiertamente licenciado (ej. "MBE Sample Test Questions" del NCBE, "All rights reserved") se usa solo en la cantidad mínima necesaria para evaluación técnica interna, con atribución completa que incluya el aviso de copyright exacto. El alcance de uso (cuántas preguntas, para qué propósito) se decide explícitamente con el usuario, no se asume. Material usado en mayor volumen para pruebas internas permanece en `scratch/` (gitignored, nunca se sube); los reportes públicos (`reports/`) usan solo el extracto mínimo acordado.

---

## 8. Verificar una capacidad nueva antes de integrarla

Antes de adoptar una librería/recurso nuevo (ej. WordNet para relaciones de sinónimos), confirmar con un caso concreto y conocido que efectivamente hace lo que se espera (ej. verificar que `derivationally_related_forms()` conecta "sane"/"sanity" *antes* de integrarlo en el pipeline de evaluación).

---

## 9. Aislar variables al diagnosticar

Cuando se quiere saber si un componente específico (ej. el motor de inferencia) es responsable de un resultado, diseñar una prueba que elimine las demás variables — por ejemplo, codificar Facts/Rules a mano (sin regex ni LLM) para medir el motor solo, en vez de seguir midiendo la combinación completa. Ver `reports/PRISMA_ENGINE_STRUCTURAL_STRESS_TEST_REPORT.md`.

---

## Checklist rápido para cualquier reporte nuevo

- [ ] ¿Cita la fuente externa exacta (URL/dataset/fecha) de cada caso de prueba?
- [ ] ¿Dice explícitamente si es sintético/autoevaluado o real, en el título?
- [ ] ¿Separa la afirmación del motor de la afirmación de la extracción?
- [ ] ¿La heurística se congeló antes de correr contra el conjunto de prueba?
- [ ] Si hubo un retroceso, ¿está documentado con el mismo detalle que una mejora?
- [ ] ¿El script fija explícitamente cualquier configuración de la que el número dependa?
- [ ] Si usa material con licencia restringida, ¿el alcance fue acordado explícitamente y está atribuido?
