# ============================================================
# PRODUCTION-GRADE MULTI-STAGE DOCKERFILE
# Number Reverser — Python / Flask
# ============================================================

# ----------------------------------------------------------
# STAGE 1: builder — install dependencies in an isolated layer
# ----------------------------------------------------------
FROM python:3.12-alpine AS builder

WORKDIR /build

# Install build tools needed for some wheels, then remove them
RUN apk add --no-cache gcc musl-dev libffi-dev

# Copy dependency manifest first → Docker cache-friendly
COPY app/requirements.txt .

# Install into a prefix directory so we can copy just that into the final image
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ----------------------------------------------------------
# STAGE 2: runtime — ultra-lean, non-root, no build tools
# ----------------------------------------------------------
FROM python:3.12-alpine

WORKDIR /app

# Security hardening: create a non-root system user & group
RUN addgroup -g 1000 -S appgroup && adduser -u 1000 -S appuser -G appgroup

# Copy only the installed packages from the builder (no pip, no gcc, etc.)
COPY --from=builder /install /usr/local

# Copy application source code — owned by non-root user
COPY --chown=appuser:appgroup app/main.py app/reverser.py ./

# Switch to non-root user before the process starts
USER appuser

EXPOSE 8080

# Use gunicorn (production WSGI server) instead of Flask dev server
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "--timeout", "30", "main:app"]
