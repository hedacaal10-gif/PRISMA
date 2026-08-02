# PRISMA — Infrastructure Hardening Report (Fase 4)

**Fecha:** 1 de agosto, 2026

---

## 1. Vulnerabilidad SSRF encontrada y corregida — `/api/v1/user/library/import-url`

**Hallazgo:** este endpoint recibía una URL arbitraria del usuario y la descargaba **server-side** (`urllib.request.urlopen`) sin ninguna validación — sin restricción de esquema, sin chequeo de si la IP resuelta es privada/interna. Un atacante podía usarlo como proxy para acceder a:
- Servicios internos no expuestos (`http://127.0.0.1/...`, `http://192.168.x.x/...`)
- El endpoint de metadata de la nube (`http://169.254.169.254/...`) — el objetivo más común de explotación SSRF real, usado para robar credenciales de IAM en AWS/GCP/Azure.
- Otros esquemas peligrosos (`file://`, `gopher://`).

**Fix:** `_validate_safe_external_url()` en `server.py` — valida esquema (`http`/`https` solamente) y resuelve el hostname, rechazando cualquier IP privada, loopback, link-local o reservada (`ipaddress.IPv4Address.is_private/is_loopback/is_link_local/is_reserved`) **antes** de hacer la petición real.

**Tests:** `packages/prisma-python/tests/test_security_and_coverage.py::TestImportUrlSSRFProtection` — 7 casos, incluyendo el ataque real contra el endpoint de metadata de la nube probado end-to-end contra la API (no solo la función aislada).

---

## 2. Cobertura de tests agregada (endpoints previamente sin probar)

- `POST /api/v1/auth/register` + `POST /api/v1/auth/login` — registro/login exitoso, contraseña incorrecta rechazada.
- `POST /api/v1/webhooks` — requiere rol válido (rechaza sin autenticación), registro exitoso con rol correcto.

**Resultado:** 49/49 tests pasan (antes 38/38).

---

## 3. Hallazgo NO corregido — requiere decisión explícita

**Hashing de contraseñas sin sal (`hash_pw()` en `server.py`):**
```python
def hash_pw(pw: str) -> str:
    return hashlib.sha256(pw.encode('utf-8')).hexdigest()
```
SHA-256 sin sal es vulnerable a ataques de tabla arcoíris/diccionario precomputado — el estándar de la industria es bcrypt, scrypt o argon2 con sal única por usuario. **No lo corregí** porque cambiar el formato de hash invalidaría las contraseñas de usuarios ya registrados en la base de datos actual — requiere una estrategia de migración (ej. re-hashear en el próximo login exitoso) que es una decisión de producto, no solo una corrección técnica aislada como el SSRF.

---

## 4. Decisiones ya tomadas en Fase 0, reafirmadas aquí

`storage_postgres.py` (stub en memoria) y `storage_redis.py` (fallback silencioso) ya quedaron honestamente documentados en sus propios docstrings desde la Fase 0 de este roadmap. No se conectaron a instancias reales de Postgres/Redis en esta pasada — hacerlo requiere orquestación de infraestructura (Docker Compose con servicios reales) que no se intentó en esta sesión. Sigue siendo trabajo pendiente, ya etiquetado honestamente en el código.

---

## 5. Pendiente real de Fase 4

- Cobertura de `natural_language_ingest`, `parse_document`, `library/add` (usa `email` como identidad informal, sin API key — verificar si es diseño intencional o hueco de autenticación).
- Tests dedicados para `auth.py`, `rate_limiter.py`, `mcp_server.py` como módulos aislados (no solo vía la API).
- Decisión sobre migración de hashing de contraseñas (arriba).
- Conectar `storage_postgres.py`/`storage_redis.py` a instancias reales, o mantener como stubs documentados indefinidamente.
