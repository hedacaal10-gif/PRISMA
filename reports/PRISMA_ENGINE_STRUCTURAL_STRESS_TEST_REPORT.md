# PRISMA — Engine Structural Stress Test Report

**Fecha:** 1 de agosto, 2026
**Script:** `scratch/engine_stress_test_structured.py`
**Motor evaluado:** `PrismaCoreEngine` (`packages/prisma-python/prisma_core/engine.py`)

---

## Objetivo

Todos los pilotos reales anteriores (`hearsay`, `diversity_1`, `ucc_v_common_law`, `contract_qa`) miden la combinación de **extracción + motor**, y la extracción siempre fue la fuente de error, nunca el motor. Este test aísla al motor por completo: los Facts/Rules se codificaron **a mano**, sin regex ni LLM, aplicando doctrina legal real a 3 preguntas reales ya verificadas del NCBE (`scratch/external_examset_eval.py`), específicamente para probar **estructuras lógicas que ningún piloto anterior había ejercido**.

---

## Resultado: 3/3 correcto

| # | Escenario (pregunta NCBE real) | Estructura nueva probada | Resultado del motor | Respuesta oficial NCBE |
| :-: | :--- | :--- | :--- | :--- |
| 1 | Autodefensa (Q1) | Antecedente que exige explícitamente `value="FALSE"` (nunca probado — todos los pilotos previos solo exigían `TRUE`) | `SUCCESS` → instrucción de autodefensa procede | B (procede) ✅ |
| 2 | Declaración previa inconsistente (Q19) | Lógica OR vía reglas alternativas independientes con el mismo consecuente (el motor solo soporta AND nativo por llamada) | Regla A `SUCCESS`, Regla B `UNSATISFIED_PREMISES`, resultado final correcto solo por A | B (se admite) ✅ |
| 3 | Conspiración (Q9) | Cadena de 3 niveles con fallo en el primer nivel, debe cortar sin llegar a un falso positivo en los niveles 2-3 | `UNSATISFIED_PREMISES` en Paso 1, cadena se detiene correctamente | A (ningún delito) ✅ |

Verificado sin regresiones: 38/38 tests de la suite completa.

---

## Lectura honesta

Esto extiende, no reemplaza, la evidencia ya reunida (`diversity_1`: 100% en 300 filas reales; `hearsay`: 100% en la categoría "Non-assertive conduct"). Con este test, la afirmación calibrada de la sesión pasa de:

> "Dado un AND de 2 condiciones bien codificado, el motor acierta 100% de las veces medidas con datos reales"

a:

> "Dado un AND de 2 condiciones (con valores `TRUE` o `FALSE` requeridos explícitamente), lógica OR modelada como reglas alternativas, o una cadena de hasta 3 niveles con corte temprano — todas bien codificadas — el motor acierta 100% de las veces medidas, incluyendo con datos reales de examen de la barra."

**Lo que sigue sin probarse:** negación lógica nativa (el motor no tiene un operador NOT — la "negación" aquí es un valor `FALSE` explícito en un predicado positivo, no una transformación lógica automática), comparación numérica de rangos dentro del motor mismo (siempre se precalcula a boolean antes de crear el Fact), cadenas de más de 3 niveles, y comportamiento bajo carga concurrente real con esta complejidad de reglas. Cada uno de estos sería una extensión legítima de este mismo enfoque.

---

## Próximos pasos sugeridos

1. Repetir este patrón (hand-encoded, datos reales, estructura nueva) para cadenas de 4+ niveles o reglas con más de 2 antecedentes reales (requeriría extender `infer()` más allá de su firma binaria actual, o encadenar más llamadas).
2. Considerar si vale la pena que el motor soporte un operador de rango numérico nativo, en vez de precalcular todo a boolean en Python antes de crear el Fact — hoy esa lógica vive fuera del motor, lo cual es una limitación de diseño documentada, no un bug.
