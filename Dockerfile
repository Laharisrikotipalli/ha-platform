FROM python:3.11-alpine AS builder

WORKDIR /app

RUN apk add --no-cache gcc musl-dev postgresql-dev

COPY requirements.txt .
RUN pip wheel --no-cache-dir --wheel-dir /app/wheels -r requirements.txt

FROM python:3.11-alpine

WORKDIR /app

RUN apk add --no-cache libpq

COPY --from=builder /app/wheels /wheels
RUN pip install --no-cache-dir /wheels/*

COPY src/ .

RUN adduser -D appuser
USER appuser

EXPOSE 8080

CMD ["python", "app.py"]