# PRISMA — Real Document Ingestion Gap Report

**Fecha de evaluación:** 31 de julio, 2026
**Pipeline evaluado:** `TextIngestionEngine.ingest_text()` → `PrismaMicroAIExtractor.extract_po1_object()` (producción real, sin modificar para esta prueba)
**Script:** `scratch/real_document_ingestion_eval.py`
**Resultados completos:** `scratch/real_document_ingestion_eval_results.json`

---

## 1. Resultado principal

| Métrica | Valor |
| :--- | :--- |
| Fragmentos evaluados | 9 (4 del estatuto, 5 de la regla) |
| `accuracy_rate` autoreportado por el propio pipeline | **100.0%** en ambas fuentes |
| Fragmentos **fieles** al contenido legal real (evaluación humana) | **0/9 (0%)** |
| Fragmentos **parcialmente útiles** (sujeto correcto, sin estructura lógica) | 4/9 (44.4%) |
| Fragmentos **no fieles** (clasificación o sujeto incorrectos) | 5/9 (55.6%) |

**El `accuracy_rate` que el propio pipeline reporta (100%) es engañoso por diseño**, no solo en este caso: `slm_extractor.py`'s `_build_result()` marca `status: "success"` en **todo** camino de extracción, incluido el fallback genérico — el campo mide "no lanzó excepción", no calidad de extracción. Este hallazgo es, en sí mismo, otra instancia del mismo patrón que motivó todo este roadmap: una métrica autoevaluada que aparenta ser una medida de calidad.

---

## 2. Fuentes usadas (reales, de dominio público, verificadas en vivo)

Los estatutos y reglas federales de EE. UU. son obra del gobierno y están excluidos de derechos de autor (17 U.S.C. § 105). Texto verificado en vivo el 2026-07-31 contra Cornell Law School's Legal Information Institute:

1. **28 U.S.C. § 1332(a)** (jurisdicción por diversidad de ciudadanía) — https://www.law.cornell.edu/uscode/text/28/1332
2. **Federal Rule of Evidence 801** (definiciones de hearsay) — https://www.law.cornell.edu/rules/fre/rule_801

---

## 3. Hallazgo principal: falsos positivos por coincidencia léxica trivial

Los 4 fragmentos de 28 U.S.C. § 1332(a) — un estatuto sobre **jurisdicción federal por diversidad de ciudadanía** — fueron clasificados **incorrectamente** como `FinancialRiskAssessment` con `subject="ApplicantRecord"` y `operator="EvaluateCreditEligibility"`.

**Causa raíz:** el patrón de dominio financiero en `slm_extractor.py` es:
```python
(r"(?:solicitante|ingresos|ingreso|crédito|hipoteca|score|dólares|\$|mora).*", self._extract_financial_rule)
```
El símbolo `\$` en la expresión regular hace match con **cualquier texto que mencione una cifra en dólares** — y el estatuto menciona "$75,000" (el umbral de cuantía en controversia) en cada una de sus 4 subsecciones. El resultado es que un estatuto sobre jurisdicción federal termina etiquetado como una evaluación de riesgo crediticio, con un sujeto (`ApplicantRecord`) y operador (`EvaluateCreditEligibility`) completamente fabricados y sin relación con el contenido real.

Esto es **peor que caer al fallback genérico**: no es solo pérdida de información, es una clasificación confiadamente incorrecta que un sistema downstream podría tratar como válida sin revisión humana.

Los 5 fragmentos de la Regla Federal de Evidencia 801 sí cayeron al fallback genérico (`GeneralDomainAssertion`), que extrae únicamente la primera palabra de ≥4 letras del texto como "sujeto" y descarta toda la estructura lógica real:
- 4 de 5 casos el sujeto extraído fue temáticamente razonable (`Statement`, `Declarant`, `Hearsay`, `Declarant`) pero sin ninguna estructura condicional capturada — exactamente la estructura de dos condiciones ("no se hizo testificando" + "se ofrece para probar la verdad de lo afirmado") que el piloto real de LegalBench necesitó codificar a mano.
- 1 de 5 casos (`"An opposing party's statement..."`) el heurístico extrajo `Opposing` (un adjetivo) como sujeto — ni siquiera el sujeto es utilizable.

---

## 4. Por qué importa

Esto confirma y cuantifica lo que `reports/PRISMA_LEGALBENCH_REAL_PILOT_REPORT.md` había señalado como una brecha esperada: el pipeline de ingesta de PRISMA hoy es una colección de patrones regex/palabras clave diseñados para dominios narrows en español (tránsito, médico, financiero, arrendamiento) — **no un extractor general de lenguaje legal en inglés**. Frente a texto legal real:
- Puede clasificar con **falsa confianza** un texto de un dominio completamente distinto si contiene una palabra/símbolo trigger incidental (el caso `\$` es el ejemplo más claro).
- Cuando cae al fallback honesto, produce en el mejor de los casos un sujeto temáticamente razonable sin ninguna estructura lógica utilizable por el motor de inferencia.
- **0 de 9 fragmentos reales** produjeron un Fact/Rule que un humano calificaría como una representación fiel y estructuralmente útil del texto legal original.

---

## 5. Separación de afirmaciones (consistente con el Fase 6 del roadmap)

Este reporte mide exclusivamente la capacidad de **extracción** (texto real → Facts/Rules), no la capacidad de **deducción** del motor (ya verificada por separado). Ningún resultado aquí debe interpretarse como una crítica al motor `PrismaCoreEngine` — el problema está enteramente en `slm_extractor.py`'s reglas basadas en patrones.

---

## 6. Addendum (2026-07-31): fix aplicado y re-verificado

Se corrigió el patrón financiero en `packages/prisma-python/prisma_core/slm_extractor.py`, quitando `\$` como disparador aislado (ahora requiere un término financiero real: "crédito", "hipoteca", "score", "dólares", etc.). Se re-ejecutó `scratch/real_document_ingestion_eval.py` sobre el **mismo texto, sin cambios**:

| | Antes del fix | Después del fix |
| :--- | :-: | :-: |
| Fiel | 0/9 (0%) | 0/9 (0%) |
| Parcial | 4/9 (44.4%) | **8/9 (88.9%)** |
| No fiel | 5/9 (55.6%) | **1/9 (11.1%)** |

Los 4 fragmentos del estatuto ya no se clasifican falsamente como "riesgo crediticio" — ahora caen honestamente al fallback genérico con sujeto `District` (el sujeto gramatical real de la oración), en vez del fabricado `ApplicantRecord`. El fragmento restante "no fiel" (`Opposing`, de la Regla 801) no está relacionado con este bug — es un caso distinto del heurístico "primera palabra ≥4 letras" agarrando un adjetivo en vez de una entidad legal.

**Sigue en 0% "fiel"**: el fix elimina falsos positivos confiadamente incorrectos, pero no le da al extractor la capacidad de capturar estructura lógica real (condiciones, excepciones) — eso requiere trabajo de extracción semántica más profundo, no un ajuste de regex.

## 7. Próximos pasos sugeridos

1. **Fix inmediato de bajo costo:** acotar el patrón financiero para que `\$` solo dispare junto con otras señales financieras reales (ej. "crédito", "score", "hipoteca"), no de forma aislada — evitaría el falso positivo más grave encontrado aquí.
2. **Extensión de dominio:** los patrones actuales son mayormente en español y de 4-5 dominios estrechos; texto legal real en inglés (estatutos, jurisprudencia) prácticamente garantiza caer al fallback genérico salvo coincidencia accidental.
3. **Corregir la métrica `accuracy_rate` en `text_ingester.py`:** debe dejar de reportar 100% quemado y, como mínimo, distinguir "coincidió con un patrón de dominio específico" vs. "cayó al fallback genérico" — esa distinción por sí sola habría hecho este hallazgo visible sin necesidad de este script separado.
4. Repetir esta evaluación después de cualquier mejora al extractor, sobre el mismo conjunto de 9 fragmentos (u otro conjunto real ampliado), para medir mejora real y no solo la ausencia de errores.
