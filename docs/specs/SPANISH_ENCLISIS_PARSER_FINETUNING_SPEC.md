# Spec de traspaso: fine-tuning del parser español para enclisis (Luz/Snell)

> ⚠️ **SUPERADO (2026-08-01, misma sesión en que se escribió esto).** El problema de enclisis que motivó este documento **se resolvió sin fine-tuning y sin tocar el tokenizador** -- ver `reports/PRISMA_LUZ_SPANISH_PILOT_REPORT.md` §12 para la solución completa (reconocimiento de formas fusionadas por texto superficial vía `_FUSED_CLITIC_FORMS`, más una búsqueda de subárbol completo de 3 niveles en `_find_content_span`, todo en `packages/prisma-python/prisma_core/snell.py`). Este documento queda como referencia histórica de la vía de fine-tuning que se investigó y se descartó como innecesaria para el alcance ya cubierto (verbos "decir"/"confirmar"/"explicar"/"contar" con clíticos de 3ª persona) -- **no es trabajo pendiente**. Si en el futuro se necesita cubrir verbos/clíticos que el enfoque de código puro no alcance a resolver, esta spec sigue siendo un punto de partida válido para esa vía alternativa.

**Propósito original de este documento:** dar contexto completo y autocontenido para continuar, en una sesión/ventana distinta, el trabajo de mejorar cómo Snell (`packages/prisma-python/prisma_core/snell.py`) maneja verbos de reporte con clíticos fusionados en español (enclisis: "decírselo", "diciéndoselo", "dígaselo"). No asume memoria de la conversación que lo originó -- todo lo relevante está aquí.

---

## 1. El problema, en una frase

`es_core_news_md` (el modelo español actual de Snell) no reconoce verbos de reporte cuando los clíticos están fusionados como sufijo ("decírselo" = decir+se+lo), y arreglar esto con trucos de tokenización **no es suficiente** -- ya se investigó y se descartó, ver §2.

## 2. Qué ya se investigó (para no repetir trabajo)

### 2.1 Diagnóstico original (confirmado con `es_core_news_sm`, luego re-confirmado con `es_core_news_md`)

Con oraciones gramaticalmente válidas (la enclisis española SOLO ocurre en infinitivo, gerundio, o imperativo afirmativo -- nunca en indicativo conjugado; "Dijoselo" NO es español válido, un primer intento con esa forma se descartó por eso):

| Oración | Con `es_core_news_sm` | Con `es_core_news_md` |
| :--- | :--- | :--- |
| "...quiere **decírselo** al juez." | `pos_="NOUN"`, lema="decírselo" | `pos_="VERB"` (correcto), lema sigue="decírselo" (incorrecto) |
| "...sigue **diciéndoselo** al jurado." | `pos_="NOUN"` | `pos_="ADJ"` (sigue mal) |
| "**Dígaselo** al juez..." | `pos_="NOUN"` | `pos_="VERB"` (correcto), lema="dígaselir" (inventado, incorrecto) |

El upgrade a `es_core_news_md` mejoró el POS-tagging en 2 de 3 casos, pero el **lema nunca es correcto** ("decir") en ninguno de los 3 -- así que `REPORTING_VERB_LEMMAS` (el set de lemas conocidos en `snell.py`) nunca hace match, sin importar el modelo.

### 2.2 Intento de excepción de tokenizador (`nlp.tokenizer.add_special_case`) -- DESCARTADO

Mecanismo de spaCy para forzar que una cadena literal se divida en varios tokens (el mismo que usa spaCy internamente para "del" -> "de"+"el"). Dos restricciones reales de la API, confirmadas por error real (no supuestas):

- Los pedazos `ORTH` deben reconstruir la cadena original EXACTA, con tildes incluidas (error `E997` si no).
- Solo se puede fijar `ORTH` y `NORM` en una excepción -- **nunca `LEMMA` ni `POS` directamente** (error `E1005` si se intenta).

Ejemplo verificado que SÍ corre:
```python
from spacy.symbols import ORTH, NORM
nlp.tokenizer.add_special_case('decírselo', [
    {ORTH: 'decír', NORM: 'decir'},   # debe respetar la tilde original
    {ORTH: 'se'},
    {ORTH: 'lo'},
])
```
Resultado: el POS del primer token queda `VERB` (correcto) y `NORM` queda "decir" (correcto, usable como fallback de matching en `snell.py` en vez de `.lemma_`). **Pero esto no es suficiente**, ver §2.3.

### 2.3 Por qué la excepción de tokenizador no resuelve el problema real -- hallazgo clave

Verificado con 6 construcciones (infinitivo/gerundio, con y sin cláusula de contenido, doble clítico, negación) que ya tienen la excepción de tokenizador aplicada:

**La cláusula de contenido se ata al verbo EQUIVOCADO.** En "El abogado quiere **decírselo** al juez **que el auto fue robado**", la cláusula "que el auto fue robado" se conecta como `ccomp` de **"quiere"** (el verbo modal externo), NO de "decír" (el verbo de reporte real). Esto significa que `_find_content_span()` en `snell.py` (que busca hijos `ccomp`/`xcomp` del verbo de reporte mismo) devolvería `None` -- una extracción silenciosamente vacía, no un error visible.

**Control decisivo:** la MISMA oración con los clíticos NO fusionados (antepuestos, "clitic climbing", 100% gramatical y equivalente en significado) -- "El testigo **se lo** sigue **diciendo** al jurado que Luis vio el robo" -- parsea PERFECTO: "se"/"lo" con las etiquetas correctas (`iobj`/`obj`), y la cláusula de contenido correctamente atada a "diciendo" (el verbo real). Esto confirma que el problema no es el clítico en sí, es la FORMA FUSIONADA -- el parser nunca vio suficientes ejemplos de esa forma en su entrenamiento (Universal Dependencies Spanish-AnCora, el treebank en el que se entrena `es_core_news_*`, tiene muy poca representación de enclisis con cláusula de complemento), así que sus predicciones de dependencia para esa construcción son poco confiables incluso después de arreglar la tokenización.

**Conclusión de esta fase:** cualquier arreglo a nivel de tokenizador es cosmético -- el parser mismo necesita ver más ejemplos de esta construcción durante su entrenamiento para predecir bien las conexiones. De ahí la idea de fine-tuning.

### 2.4 Alternativa considerada y con límite conocido: reescritura de texto ("clitic climbing" a la inversa)

Idea: antes de parsear, reescribir "decírselo" -> "se lo decir" (mover el clítico a su posición no-fusionada, ya que el control §2.3 demuestra que esa forma sí parsea bien). **Límite real:** el imperativo afirmativo ("Dígaselo") NO tiene una forma no-fusionada válida en español -- "lo diga" no es una reescritura equivalente de "dígalo" (el imperativo afirmativo EXIGE enclisis en español estándar). Esta alternativa quedaría sin resolver ese caso específico. No se implementó, solo se identificó como dirección posible.

---

## 3. Por qué se descartó "construir un parser propio" y qué se recomendó en su lugar

Entrenar un parser de dependencias desde cero es un proyecto de investigación de años, desproporcionado para este problema puntual. La alternativa intermedia -- **fine-tuning** (continuar el entrenamino de `es_core_news_md` ya existente con datos propios, no entrenar desde cero) -- es técnicamente viable pero es un compromiso de una naturaleza distinta a todo lo hecho hasta ahora en este proyecto: pasa de "una función de Python verificada en minutos" a "un artefacto de modelo que hay que versionar, re-entrenar si cambia spaCy, y re-verificar contra toda la guardia de regresión cada vez". El resto de este documento asume que se decidió seguir con fine-tuning de todos modos.

---

## 4. Qué se necesita técnicamente para el fine-tuning

### 4.1 Mecánica de entrenamiento en spaCy v3 (versión instalada: 3.8.13)

spaCy v3 entrena por configuración declarativa (`config.cfg`), no por API imperativa directa. El flujo estándar:

1. **Generar una config base** con `python -m spacy init config config.cfg --lang es --pipeline parser`. Esto crea un `config.cfg` editable.
2. **Partir del modelo existente, no desde cero:** en la sección `[components]` del config, usar `source = "es_core_news_md"` para los componentes que NO se quieren re-entrenar (tagger, lemmatizer, morphologizer, attribute_ruler -- deben quedar **congelados**, ver `frozen_components` en `[training]`), y dejar `parser` como el único componente entrenable. Esto es lo que evita tener que re-entrenar todo el pipeline desde cero.
3. **Datos de entrenamiento:** formato binario `.spacy` (un `DocBin` serializado), no CoNLL-U directamente (aunque se puede convertir CoNLL-U a `.spacy` con `spacy convert`).
4. **Comando de entrenamiento:** `python -m spacy train config.cfg --output ./output --paths.train train.spacy --paths.dev dev.spacy`.

### 4.2 Cómo construir los ejemplos de entrenamiento (ya sabemos cuál es el árbol "correcto" -- podemos construirlo a mano en Python, sin herramienta de anotación externa)

Como ya diagnosticamos exactamente qué debería decir el árbol de dependencia correcto (ver el control del §2.3), podemos construir los `Doc` de entrenamiento directamente en código, sin Prodigy ni anotación manual en una UI:

```python
import spacy
from spacy.tokens import Doc, DocBin
from spacy.training import Example

nlp = spacy.blank("es")  # tokenizador vacío, solo para construir el Doc

# Ejemplo: "El abogado quiere decírselo al juez que el auto fue robado."
# Gold: "decír" (o el token que corresponda tras dividir el fusionado)
# debe llevar la cláusula de contenido como su propio hijo ccomp/xcomp,
# no como hijo de "quiere".
words = ["El", "abogado", "quiere", "decír", "se", "lo", "al", "juez",
          "que", "el", "auto", "fue", "robado", "."]
heads =  [1, 2, 2, 2, 3, 4, 7, 3, 12, 10, 12, 12, 3, 2]  # índice del head de cada token
deps  =  ["det", "nsubj", "ROOT", "xcomp", "iobj", "obj", "case", "obl",
          "mark", "det", "nsubj", "aux", "ccomp", "punct"]
doc = Doc(nlp.vocab, words=words, heads=heads, deps=deps)
example = Example(doc, doc)  # reference == predicted para un ejemplo de oro
```

(Los índices de `heads` de arriba son ilustrativos -- hay que fijarlos con cuidado para que "robado" cuelgue de "decír" con `dep_="ccomp"`, que es el punto central del arreglo.)

Luego juntar muchos `Example` en un `DocBin` y guardarlo:
```python
db = DocBin()
for example in examples:
    db.add(example.reference)
db.to_disk("train.spacy")
```

### 4.3 Cuántos ejemplos hacen falta, y el riesgo de "catastrophic forgetting"

No hay un número mágico -- es empírico, hay que iterar. Puntos de referencia generales (no específicos de este caso):

- Un puñado de docenas de ejemplos del fenómeno puntual PUEDE ser suficiente para que el parser aprenda el patrón, si se mezclan con una muestra representativa de español "normal" durante el entrenamiento -- de lo contrario el modelo puede "olvidar" cómo parsear todo lo demás (catastrophic forgetting) al sobre-ajustarse al fenómeno raro.
- Fuente recomendada para la muestra de español "normal": el mismo corpus en el que se entrena `es_core_news_md` -- **Universal Dependencies Spanish-AnCora** (público, descargable desde el repositorio oficial de UD: `UD_Spanish-AnCora` en GitHub, formato CoNLL-U). Se puede mezclar una porción de ese corpus con los nuevos ejemplos de enclisis.
- **Verbos/construcciones a cubrir en los ejemplos nuevos** (lista de partida, ya identificada en esta sesión -- no exhaustiva, expandir según se descubran más):
  - Infinitivo con clítico simple: "hacerlo", "verlo", "decirlo"
  - Infinitivo con doble clítico: "decírselo", "contárselo", "confirmárselo", "explicárselo"
  - Gerundio con clítico(s): "diciéndolo", "diciéndoselo", "explicándoselo"
  - Imperativo afirmativo con clítico(s): "dígalo", "dígaselo", "cuéntaselo", "confírmeselo"
  - Cada uno en AL MENOS dos posiciones sintácticas: como complemento de un verbo modal/aspectual ("quiere decírselo", "sigue diciéndoselo") y como verbo principal de una oración imperativa ("Dígaselo al juez...")
  - Cada uno CON una cláusula de contenido real después (el caso que realmente nos importa para `_find_content_span`) y sin ella (para no perder cobertura de los casos más simples)

### 4.4 Dónde vivirá el modelo resultante -- decisión pendiente, no asumida aquí

El modelo fine-tuneado es un artefacto binario nuevo, distinto del paquete pip `es_core_news_md`. Antes de integrarlo hay que decidir:
- **Ruta de almacenamithe:** ¿una carpeta local dentro de `packages/prisma-python/prisma_core/models/es_snell_finetuned/`? Nota: `packages/prisma-python/` está en `.gitignore` según `CLAUDE.md` -- un modelo entrenado ahí NO quedaría en el historial de git a menos que se decida explícitamente lo contrario (y un modelo de spaCy fine-tuneado puede pesar más que el paquete base, hay que decidir si se sube a git, a un artifact store externo, o se regenera localmente con un script reproducible).
- **Carga en `snell.py`:** `_get_nlp()` actualmente hace `spacy.load(_MODEL_NAMES[lang])` usando el NOMBRE del paquete pip. Cargar un modelo local requiere `spacy.load(ruta_absoluta)` en su lugar -- cambio pequeño pero hay que decidir cómo distinguir "modelo de paquete pip" de "modelo local fine-tuneado" en `_MODEL_NAMES` (¿una ruta en vez de un nombre? ¿un flag nuevo?).
- **Reproducibilidad:** el script/config de entrenamiento debe quedar versionado (sí, ese si puede ir en git aunque el modelo binario resultante no) para que cualquiera pueda regenerar el modelo desde cero -- consistente con la disciplina de `docs/VERIFICATION_STANDARDS.md` regla 6 ("fijar explícitamente la configuración de la que depende un número publicado").

### 4.5 Cómo verificar el resultado (obligatorio antes de aceptar cualquier cambio)

1. **Verificación estructural dirigida primero:** re-correr las 6 oraciones de prueba de esclisis (§2.3) contra el modelo fine-tuneado y confirmar que "decír"/"diciéndo"/etc. ahora SÍ tienen `ccomp`/`xcomp` propio con la cláusula de contenido correcta.
2. **`packages/prisma-python/tests/test_snell.py`:** el test `test_spanish_enclitic_reporting_verb_is_a_known_limitation` está diseñado para EMPEZAR A FALLAR cuando esto se arregle (documenta el comportamiento actual a propósito) -- si el fine-tuning funciona, hay que actualizar ese test para reflejar el nuevo comportamiento correcto, no solo dejarlo en rojo.
3. **Toda la guardia de regresión existente, sin excepción**, porque cambiar el modelo de spaCy es un cambio compartido de infraestructura, igual que el upgrade a `es_core_news_md` de esta sesión:
   - `cd packages/prisma-python && python -m pytest tests/ -q` (68 passed a la fecha de este documento)
   - `cd packages/core && npm test` (26 passed)
   - `python scratch/test_prisma_core_upgrades.py` (5/5)
   - `python scratch/prisma_legalbench_suite.py` (120/120)
   - `python scratch/external_legalbench_eval_snell.py` (inglés, no debería cambiar -- 70.21%, 66/94)
   - `python scratch/prisma_spanish_hearsay_eval.py` (autoescrito, NO benchmark -- verificar que sigue en 85% o mejora, nunca que empeora sin explicación)
4. **Verificación de que el fine-tuning NO degradó el parsing general español:** correr el modelo fine-tuneado contra una muestra de oraciones de UD Spanish-AnCora que NO se usaron en el entrenamiento (un dev/test split real del treebank) y comparar el UAS/LAS (unlabeled/labeled attachment score, las métricas estándar de evaluación de parsers) contra el modelo `es_core_news_md` original -- si el fine-tuning bajó la precisión general de forma notable, es una señal de catastrophic forgetting y hay que ajustar la mezcla de datos de entrenamiento.

---

## 5. Honestidad y disciplina de reporte (aplica igual que al resto del proyecto)

Cualquier resultado de este trabajo debe documentarse en `reports/PRISMA_LUZ_SPANISH_PILOT_REPORT.md` (nueva sección addendum) siguiendo `docs/VERIFICATION_STANDARDS.md`:
- Si el fine-tuning corrige la enclisis, decir explícitamente CONTRA QUÉ se verificó (las 6 oraciones de prueba + el dataset autoescrito de 20 filas, NO un benchmark real -- sigue sin existir un dataset real en español).
- Si el fine-tuning degrada el parsing general (UAS/LAS más bajo en el dev set de AnCora), reportarlo con el mismo nivel de detalle que una mejora -- no ocultar un retroceso.
- Actualizar `test_spanish_enclitic_reporting_verb_is_a_known_limitation` en vez de dejarlo fallando en silencio si el comportamiento cambió.

---

## 6. Primer experimento sugerido (barato, antes de comprometerse a todo lo anterior)

Antes de construir el pipeline completo de entrenamiento: tomar 15-20 ejemplos hechos a mano (solo los verbos/construcciones del §4.3, sin mezclar todavía con AnCora), hacer un fine-tuning rápido, y verificar SOLO contra las 6 oraciones de prueba del §2.3 -- si ni siquiera con datos hechos a medida el parser aprende el patrón, es señal de que hace falta mucho más volumen/variedad de datos de lo esperado, y vale la pena reconsiderar el costo/beneficio antes de invertir en mezclar con AnCora y montar la evaluación UAS/LAS completa.

---

## 7. Archivos relevantes (todos ya existen, ninguno hace falta crear desde cero salvo lo que este documento describe)

- `packages/prisma-python/prisma_core/snell.py` -- `_MODEL_NAMES`, `_get_nlp()`, `REPORTING_VERB_LEMMAS["spa"]`, `NONVERBAL_ASSERTIVE_LEMMAS["spa"]`
- `packages/prisma-python/tests/test_snell.py` -- `test_spanish_enclitic_reporting_verb_is_a_known_limitation` (el test que debe actualizarse si esto se arregla)
- `scratch/prisma_spanish_hearsay_dataset.json` -- fila `es_hearsay_013`, diseñada específicamente para ejercitar este caso
- `scratch/prisma_spanish_hearsay_eval.py` -- pipeline de evaluación que reportaría el efecto end-to-end
- `reports/PRISMA_LUZ_SPANISH_PILOT_REPORT.md` §3 (H6) y §9 -- historial completo de lo ya intentado
- `docs/VERIFICATION_STANDARDS.md` -- disciplina de reporte a seguir
