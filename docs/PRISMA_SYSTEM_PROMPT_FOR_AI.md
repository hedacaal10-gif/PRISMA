# 🔮 Guía de Integración con ChatGPT & Custom GPTs (OpenAI Actions)

Esta guía explica paso a paso cómo conectar cualquier **Custom GPT** o **Agente de OpenAI / ChatGPT** a la API de PRISMA en menos de 2 minutos.

---

## 🛠️ Pasos para Conectar ChatGPT (Custom GPT) a PRISMA

### Paso 1: Crear un Custom GPT en OpenAI
1. Entra a ChatGPT y ve a **Explore GPTs** $\rightarrow$ **Create** (o la pestaña **Configure**).
2. Asigna un nombre a tu GPT (ejemplo: *PRISMA Deductive Verifier*).

### Paso 2: Importar la Especificación OpenAPI (Actions)
1. En la sección **Actions** (Acciones abajo en la configuración), haz clic en **Create new action**.
2. En el campo **Import from URL**, ingresa la URL activa de tu servidor PRISMA:
   `https://indie-nose-often-winston.trycloudflare.com/openapi.json`

3. Haz clic en **Import**. ChatGPT importará automáticamente todos los endpoints de inferencia determinista (`/api/v1/infer`), ingesta (`/api/v1/ingest/text`) y diagnóstico (`/api/v1/system_status`).

### Paso 3: Pegar el Prompt de Sistema en "Instructions"
En el cuadro de texto **Instructions** de tu Custom GPT, pega el siguiente bloque:

```markdown
### INSTRUCCIONES DE SISTEMA: MOTOR DE INFERENCIA VERIFICADA PRISMA v4.0.0

Eres un Asistente de IA con acceso directo a la API del Motor Neuro-Simbólico PRISMA.

1. REGLA DE ORO: Para cualquier consulta donde se requiera verificar normatividad, derechos laborales, reglas de tránsito, triaje médico o cláusulas de contratos, NO intentes adivinar probabilísticamente.
2. Ejecuta una llamada a la Acción de PRISMA en el endpoint `POST /api/v1/infer`.
3. Presenta la respuesta al usuario con:
   - Conclusión formal deducida por Modus Ponens (0.00% alucinación).
   - El ID Criptográfico SHA-256 de la Prueba (`prisma:id:sha256:...`).
   - El estado de la inferencia (ASSERTED / MATERIALIZED).
```

---

## 🔒 Autenticación y Seguridad
- Si tu API requiere API Key, en la sección **Authentication** de la Acción selecciona **API Key** $\rightarrow$ **Custom Header** (`X-PRISMA-API-KEY`).

---

*Documento de integración oficial para PRISMA Systems — Registro DNDA Colombia 2026.*
