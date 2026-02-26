# STAGE 1: The Builder (Heavy but Cached)
FROM python:3.11-alpine AS builder

WORKDIR /app

# Install compilation tools only once
RUN apk add --no-cache gcc musl-dev postgresql-dev

# Pre-compile your requirements into "wheels"
COPY src/requirements.txt .
RUN pip wheel --no-cache-dir --wheel-dir /app/wheels -r requirements.txt


# STAGE 2: The Runtime (Small, Fast, and Secure)
FROM python:3.11-alpine

WORKDIR /app

# Install ONLY the runtime database library (takes seconds)
RUN apk add --no-cache libpq

# Copy the pre-compiled packages from the builder stage
COPY --from=builder /app/wheels /wheels
RUN pip install --no-cache-dir /wheels/*

# Copy your source code last (this makes code changes instant)
COPY src/ .

# Mandatory Security: Run as non-root user
RUN adduser -D appuser
USER appuser

# Correct Port for your web-deployment.yaml
EXPOSE 8080

CMD ["python", "app.py"]