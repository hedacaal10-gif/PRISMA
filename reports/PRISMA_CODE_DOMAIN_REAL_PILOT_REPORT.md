# PRISMA — Real Code-Domain Pilot Report (punto 4, expansión a dominio general)

**Fecha:** 1 de agosto, 2026
**Script:** `scratch/code_domain_real_pilot.py`
**Módulo extendido:** `packages/prisma-python/prisma_core/ast_ingester.py`

---

## 1. Por qué código, y no biología/historia directamente

Se investigó primero usar MMLU (el equivalente multi-materia de LegalBench — biología, historia, seguridad informática, etc., con Q&A real ya definido, disponible en HuggingFace `cais/mmlu`). Hallazgo honesto: las preguntas de MMLU son de **conocimiento general de opción múltiple** ("¿qué causa una mutación de marco de lectura?"), no del tipo "¿se cumple la condición A Y B?" que un motor Horn-clause puede razonar sin una base de conocimiento completa precargada de la materia — un proyecto categóricamente más grande que un piloto (equivaldría a construir un sistema experto de biología/historia desde cero).

**Código es distinto: las reglas de calidad/estilo de código SON, literalmente, Horn-clauses** ("si la función es pública Y no tiene docstring, entonces falta documentación"). PRISMA ya tenía `ast_ingester.py` construido (nunca probado en esta sesión) para ingerir código Python/JS real en Facts — encaja con la arquitectura sin inventar nada nuevo.

---

## 2. Qué se construyó

Se extendió `PrismaASTIngester.parse_python_file()` para emitir, además de los Facts estructurales que ya tenía (imports, definiciones de función/clase), dos Facts de calidad por función real:
- `IsPublicFunction` (el nombre no empieza con `_`, convención de Python)
- `HasDocstring` (el primer statement del cuerpo es un string literal)

Regla Horn-clause real: `IsPublicFunction=TRUE AND HasDocstring=FALSE → MissingRequiredDocstring=TRUE`, ejecutada vía `PrismaCoreEngine.infer()` real — mismo motor, mismo mecanismo de verificación de antecedentes que en todos los pilotos legales.

**Dato:** el propio código fuente de PRISMA (`packages/prisma-python/prisma_core/*.py`, 36 archivos reales de producción) — no fixtures sintéticas.

---

## 3. Resultado: 198/198 verificado, 100% de exactitud

| Métrica | Valor |
| :--- | :-: |
| Archivos `.py` reales escaneados | 36 |
| Funciones analizadas | 198 |
| Marcadas como "función pública sin docstring" | 74 (37.4%) |
| **Verificación independiente contra el código fuente real (las 198, no solo una muestra)** | **198/198 correctas (0 discrepancias)** |

A diferencia del razonamiento legal (donde la verdad requiere interpretación jurídica), aquí la respuesta correcta es mecánicamente verificable por cualquiera: se re-parseó cada archivo de forma independiente del pipeline de PRISMA y se comparó el resultado — no una muestra, las 198 funciones completas.

---

## 4. Un bug real encontrado en el camino (propio, no de PRISMA)

La primera corrida marcó 198/198 (100%) — una señal de que algo estaba mal, no un resultado real. Causa: en Python, `PrismaCoreEngine.infer()` **no lanza excepción** para premisas no satisfechas — devuelve un objeto `InferenceResult` con `.status != "SUCCESS"` (a diferencia del puerto a TypeScript que sí lanza `UnsatisfiedPremisesError`, ver paridad TS↔Python de hoy). El script usaba `try/except` asumiendo el comportamiento de TypeScript, así que `infer()` nunca lanzaba, y todo se marcaba como `flagged=True` sin importar los Facts reales. Corregido para chequear `res.status == "SUCCESS"` explícitamente. Esto es exactamente el tipo de error que la verificación independiente (§3) existe para atrapar — y lo atrapó.

---

## 5. Lectura honesta y alcance

Esto demuestra que la arquitectura de PRISMA (extracción de Facts + reglas Horn-clause + motor determinista) **generaliza genuinamente a un dominio no legal** cuando la tarea real tiene la forma correcta (condiciones combinables con AND/OR, no recuperación de conocimiento abierto). No demuestra que PRISMA pueda responder preguntas de biología o historia tipo trivia — eso requiere una base de conocimiento del dominio, un proyecto distinto y mucho más grande, no cubierto aquí.

**Próximos dominios candidatos, mismo patrón:** reglas de seguridad de código (ej. uso de `eval()` sin sanitización), convenciones de nomenclatura, complejidad ciclomática — todo lo que ya sea "si A y B, entonces C" es alcanzable con la misma arquitectura. Materias de conocimiento abierto (biología, historia) necesitarían una fase de construcción de base de conocimiento, fuera del alcance de un piloto.
