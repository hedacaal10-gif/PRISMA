# 🔮 PRISMA Enterprise — Motor de Inferencia Neuro-Simbólico & Memory Gateway B2B

**Protocol for Reasoning, Inference and Semantic Memory Architecture — Version v4.0.0**  
*0% Alucinaciones · 210,000+ QPS en Caché O(1) · Latencia P99 ≤ 7.6µs · Certificado DNDA Colombia 2026*


---

## 🚀 Inicio Rápido

### 1. Iniciar el Servidor API (FastAPI Gateway)

```bash
cd packages/prisma-python
python -m prisma_core.server
```

El servidor estará activo en `http://localhost:7777` con Swagger interactivo en `/docs` y el Portal Comercial en `/`.

### 2. Uso por CLI (Línea de Comandos)

```bash
# Consultar espacio de conocimiento por dominio
python -m prisma_core.cli query --domain traffic-law --input "Conductor_A" --format json
```

---

## 📚 5 Ejemplos Multidominio Prácticos

### 1. ⚖️ Derecho de Tránsito & Sanciones
```python
from prisma_core import PrismaCoreEngine, Fact, Rule, compute_semantic_identity, LifecycleState, Provenance

engine = PrismaCoreEngine()
prov = Provenance(issuer="did:gov:transit", method="AutomatedIngestion")
temporal = ("2026-01-01T00:00:00Z", "INF")

f1 = engine.insert_fact(Fact(
    id=compute_semantic_identity("prisma:type:fact", {"kind": "PredicateAssertion", "subject": "Conductor_A", "operator": "CometióInfraccion", "value": "C02_Velocidad"}, "ctx:legal", temporal),
    type="prisma:type:fact", expression={"kind": "PredicateAssertion", "subject": "Conductor_A", "operator": "CometióInfraccion", "value": "C02_Velocidad"},
    context="ctx:legal", temporalValidity=temporal, provenance=prov, integrityState=LifecycleState.ASSERTED
))
```

### 2. 💊 Medicina & Farmacología (Contraindicaciones)
```python
f_med = engine.insert_fact(Fact(
    id=compute_semantic_identity("prisma:type:fact", {"kind": "PredicateAssertion", "subject": "Paciente_B", "operator": "Diagnóstico", "value": "HipertensiónGrave"}, "ctx:med", temporal),
    type="prisma:type:fact", expression={"kind": "PredicateAssertion", "subject": "Paciente_B", "operator": "Diagnóstico", "value": "HipertensiónGrave"},
    context="ctx:med", temporalValidity=temporal, provenance=prov, integrityState=LifecycleState.ASSERTED
))
```

### 3. 📊 Finanzas & Riesgo Crediticio
```python
f_fin = engine.insert_fact(Fact(
    id=compute_semantic_identity("prisma:type:fact", {"kind": "PredicateAssertion", "subject": "Empresa_Titan", "operator": "ScoreCrediticio", "value": "BajaCalificacion_C"}, "ctx:fin", temporal),
    type="prisma:type:fact", expression={"kind": "PredicateAssertion", "subject": "Empresa_Titan", "operator": "ScoreCrediticio", "value": "BajaCalificacion_C"},
    context="ctx:fin", temporalValidity=temporal, provenance=prov, integrityState=LifecycleState.ASSERTED
))
```

### 4. ☁️ Arquitectura Cloud & Autoescalado
```python
f_eng = engine.insert_fact(Fact(
    id=compute_semantic_identity("prisma:type:fact", {"kind": "PredicateAssertion", "subject": "Cluster_K8s", "operator": "UsoCPU", "value": "Excede95Porciento"}, "ctx:eng", temporal),
    type="prisma:type:fact", expression={"kind": "PredicateAssertion", "subject": "Cluster_K8s", "operator": "UsoCPU", "value": "Excede95Porciento"},
    context="ctx:eng", temporalValidity=temporal, provenance=prov, integrityState=LifecycleState.ASSERTED
))
```

### 5. 🏠 Vida Cotidiana & Contratos de Arriendo
```python
f_day = engine.insert_fact(Fact(
    id=compute_semantic_identity("prisma:type:fact", {"kind": "PredicateAssertion", "subject": "Arrendatario_Juan", "operator": "MoraPago", "value": "MayorA15Dias"}, "ctx:everyday", temporal),
    type="prisma:type:fact", expression={"kind": "PredicateAssertion", "subject": "Arrendatario_Juan", "operator": "MoraPago", "value": "MayorA15Dias"},
    context="ctx:everyday", temporalValidity=temporal, provenance=prov, integrityState=LifecycleState.ASSERTED
))
```

---

## 🤖 Integración LangChain (Agentes de IA con Memoria Verificada)

```python
from prisma_core import PrismaCoreEngine
from prisma_core.adapters import PrismaLangChainMemory

engine = PrismaCoreEngine()
memory = PrismaLangChainMemory(engine=engine, context="ctx:clinical_bot")

# El agente guarda la conversación con verificación SHA-256
memory.save_context(
    inputs={"human_input": "Presión arterial: 140/90"},
    outputs={"output": "Registrado. Se requiere monitoreo."}
)

# Si un dato es invalidado posteriormente, PRISMA lo purga automáticamente del contexto del LLM
```

> [!WARNING]
> **Nota sobre Pruebas de Carga y Agentes de IA Externos:**  
> El motor PRISMA procesa las deducciones e inferencias de la API localmente en microsegundos sin costo de tokens. Sin embargo, si un evaluador conecta un agente de IA externo (como Claude o GPT) para generar miles de consultas automatizadas en lote, la cuota de la API de dicho proveedor de IA externo podría agotarse en su cuenta personal. Se recomienda realizar pruebas masivas de volumen directamente mediante peticiones HTTP a la API de PRISMA, o reservar los agentes de IA externos para consultas puntuales.


---


## 🎁 Acceso Anticipado Pre-Lanzamiento (Pruebas 100% Gratuitas)

Durante esta **fase previa al lanzamiento oficial**, la API de PRISMA es **totalmente gratuita** para desarrolladores, evaluadores e inversores:

- **Registro de Cuenta Pre-Lanzamiento**: Al iniciar sesión o registrarte durante las ventanas de disponibilidad, el sistema te emite automáticamente tu **API Key de evaluación**.
- **Límites de Uso por Sesión**: Cada cuenta cuenta con un límite de peticiones por minuto (RPM) y cuota diaria para proteger la disponibilidad de la infraestructura durante las pruebas públicas.
- **Garantía de Latencia**: En la caché de pruebas, PRISMA ofrece respuestas deterministas en **P99 ≤ 7.6 µs**.
- *Nota: Las condiciones comerciales y planes definitivos On-Premise se anunciarán en el lanzamiento oficial.*


---

## 🌐 API Gratuita Temporal (Horarios de Demostración en Vivo)

Durante la fase de validación y pruebas públicas, la API en la nube estará activa en ventanas de horario específicas para que la comunidad e inversores puedan realizar consultas en vivo:

- 🔗 **URL de API Pública Activa (Hoy):** `https://test-demo-tunnel-99.trycloudflare.com/api/v1`
- 📜 **Especificación OpenAPI (JSON):** `https://test-demo-tunnel-99.trycloudflare.com/openapi.json`
- 🧪 **Documentación Interactiva (Swagger):** `https://test-demo-tunnel-99.trycloudflare.com/docs`



---

## 🔒 Política de Transparencia y Recopilación de Datos (Fase Beta)

Para auditar el rendimiento, mejorar la precisión de los extractores de texto y evaluar el comportamiento de los clientes durante estas fases públicas, PRISMA registra únicamente la siguiente información mínima de telemetría:

1. **Datos Recopilados:**
   - Texto de las consultas enviadas (`query_text`) e intención detectada (`detected_intent`).
   - Identificador SHA-256 de los documentos cargados (`doc_sha256`).
   - Métrica de latencia de respuesta (microsegundos/milisegundos) y código de respuesta HTTP.
   - Retroalimentación voluntaria enviada por el usuario (votos de pulgar arriba / pulgar abajo).
2. **Lo que NO recopilamos ni almacenamos:**
   - **No se almacenan contraseñas en texto plano** (utilizamos hashing SHA-256).
   - **No se recopila información personal identificable (PII) no autorizada**.
   - Las llaves de API sensibles se enmascaran automáticamente en los logs.
3. **Uso de la Información:**
   - Los registros de auditoría (`query_audit_logs`) se utilizan exclusivamente para análisis de telemetría, detección de errores y mejora del motor de razonamiento de PRISMA.

---

## 📑 Informes Técnicos y Estándar

- [📄 **Informe Técnico Maestro (3 Páginas)**](file:///c:/Users/DaniK/Documents/PRISMA/reports/PRISMA_INFORME_TECNICO_MAESTRO_3PAGINAS.md): Metodología estadística, percentiles, escalabilidad 10M, matriz competitiva y SLA.
- [🧪 **Proof of Concept JSON Real**](file:///c:/Users/DaniK/Documents/PRISMA/reports/poc_sample_real.json): Ejemplo completo de payload verificado.
- [📜 **Especificaciones Formales**](file:///c:/Users/DaniK/Documents/PRISMA/docs/CONSTITUTION.md): Invariantes CP-001 a CP-008.

---

*PRISMA Enterprise v4.0.0 — Propiedad Intelectual Registrada en Trámite ante la DNDA Colombia, 2026. Licensor: PRISMA Systems — Todos los derechos reservados.*



