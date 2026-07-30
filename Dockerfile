# Production Dockerfile for PRISMA Enterprise v4.0.0

FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends curl build-essential && rm -rf /var/lib/apt/lists/*

COPY packages/prisma-python/pyproject.toml /app/
RUN pip install --no-cache-dir fastapi uvicorn pydantic python-multipart requests psycopg2-binary

COPY packages/prisma-python/prisma_core /app/prisma_core
COPY packages/prisma-web/index.html /app/index.html

EXPOSE 8080
ENV PYTHONUNBUFFERED=1
ENV PORT=8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 CMD curl -f http://localhost:8080/health || exit 1

CMD ["python", "-m", "uvicorn", "prisma_core.server:app", "--host", "0.0.0.0", "--port", "8080"]
