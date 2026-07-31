# 🔮 Guía de Integración y Prompt de Sistema para Claude & Asistentes de IA (PRISMA v4.0.0)

> 🌐 **URL de API Pública Activa (Servidor en Vivo):**  
> `https://indie-nose-often-winston.trycloudflare.com`  
> 📜 **OpenAPI Spec (Para Custom GPTs / Claude Tools):** `https://indie-nose-often-winston.trycloudflare.com/openapi.json`  
> 🧪 **Documentación Swagger Interactiva:** `https://indie-nose-often-winston.trycloudflare.com/docs`

---

## 📌 Contexto General del Sistema

**PRISMA** (*Protocol for Reasoning, Inference and Semantic Memory Architecture*) es un **Motor de Inferencia Neuro-Simbólico y API Gateway B2B** de alta eficiencia. 

Está diseñado para tomar texto en lenguaje natural de normativas, contratos o registros clínicos, estructurarlos lógicamente en hechos y reglas simbólicas dentro de un espacio de conocimiento verificado, y ejecutar razonamiento formal determinista (Modus Ponens) con **0.00% alucinaciones**, garantizando trazabilidad total por IDs criptográficos SHA-256.

---

## 🌐 Endpoints REST Públicos (API de Caja Negra)

El servidor PRISMA expone los siguientes endpoints HTTP estándar:

### 1. Inferencia Lógica Formal (`POST /api/v1/infer`)
Ejecuta la deducción lógica determinista Modus Ponens entre dos premisas (hechos) y una regla.
- **Payload de Entrada**:
  - `fact_a`: Objeto Hecho premisa A.
  - `fact_b`: Objeto Hecho premisa B.
  - `rule`: Objeto Regla de implicación formal.
  - `context`: Identificador del espacio de conocimiento (ej: `ctx:legal`).
- **Respuesta**: Retorna `derivedFact`, árbol de prueba deductiva `proof` con ID SHA-256 e información de estado.

### 2. Ingesta y Estructuración de Texto (`POST /api/v1/ingest/text`)
Toma fragmentos de texto en lenguaje natural y genera la estructuración lógica JSON.
- **Payload de Entrada**: `text` (string), `domain` (string).
- **Respuesta**: Lista de hechos y reglas inferidas.

### 3. Diagnóstico de Salud del Sistema (`GET /api/v1/system_status`)
- **Respuesta**: Métricas de rendimiento, versión v4.0.0 y estado operativo.

---

## 🤖 Instrucciones para Claude (Prompt de Sistema Seguro)

Cuando utilices a Claude como asistente o agente conectado a PRISMA, utiliza las siguientes instrucciones en su prompt de sistema:

```markdown
### INSTRUCCIONES DE SISTEMA PARA CLAUDE — INTEGRACIÓN PRISMA

Eres un Asistente de IA con acceso a la API REST de PRISMA para inferencia neuro-simbólica y memoria verificada.

1. REGLA DE ORO: Para cualquier consulta donde se requiera verificar normatividad, derechos laborales, reglas de tránsito o protocolos clínicos, NO adivines probabilísticamente.
2. Comunícate con la API remota de PRISMA ejecutando peticiones HTTP al endpoint `POST /api/v1/infer` o utilizando la herramienta registrada `prisma_infer`.
3. Presenta siempre la respuesta al usuario incluyendo:
   - Conclusión formal deducida por Modus Ponens (0.00% alucinación).
   - El ID Criptográfico SHA-256 de la Prueba (`prisma:id:sha256:...`).
   - El estado de la inferencia (ASSERTED / MATERIALIZED).
```

---

## 🛠️ Definición de Herramientas para Claude (Tool Definition / Function Calling)

Para registrar la herramienta en la API de Anthropic Claude o en un agente Claude:

```json
{
  "name": "prisma_infer",
  "description": "Ejecuta inferencia neuro-simbólica formal Modus Ponens a través de la API HTTPS de PRISMA.",
  "input_schema": {
    "type": "object",
    "properties": {
      "fact_a": { "type": "object", "description": "Objeto Hecho premisa A" },
      "fact_b": { "type": "object", "description": "Objeto Hecho premisa B" },
      "rule": { "type": "object", "description": "Objeto Regla de implicación" },
      "context": { "type": "string", "description": "Dominio o contexto (ej: ctx:traffic)" }
    },
    "required": ["fact_a", "fact_b", "rule", "context"]
  }
}
```

---

*Documentación de integración pública de PRISMA Systems — Propiedad Intelectual Registrada en Trámite ante la DNDA Colombia 2026.*
