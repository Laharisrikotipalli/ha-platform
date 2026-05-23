import os
import time
import psycopg2
from flask import Flask, jsonify

app = Flask(__name__)


def get_db_connection():
    return psycopg2.connect(
        host=os.getenv("DB_HOST", "postgres"),
        database=os.getenv("DB_NAME", "postgres"),
        user=os.getenv("DB_USER", "postgres"),
        password=os.getenv("DB_PASSWORD", "postgres"),
        connect_timeout=5
    )


def init_db():
    """Create visits table on startup, retrying with backoff until DB is ready."""
    retries = 0
    while True:
        try:
            with get_db_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute("""
                        CREATE TABLE IF NOT EXISTS visits (
                            id SERIAL PRIMARY KEY,
                            ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                        );
                    """)
                conn.commit()
            print("Database initialized successfully.")
            break
        except Exception as e:
            retries += 1
            wait = min(2 * retries, 30)  
            print(f"Waiting for database (attempt {retries}), retrying in {wait}s... {e}")
            time.sleep(wait)


@app.route("/health")
def health():
    """Liveness probe: is the process alive?"""
    return jsonify({"status": "up"}), 200


@app.route("/ready")
def ready():
    """Readiness probe: can we reach the database?"""
    try:
        conn = get_db_connection()
        conn.close()
        return jsonify({"status": "up"}), 200
    except Exception:
        return jsonify({"status": "not ready"}), 503


@app.route("/")
def index():
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("INSERT INTO visits DEFAULT VALUES;")
                cur.execute("SELECT COUNT(*) FROM visits;")
                count = cur.fetchone()[0]
                cur.execute("SELECT version();")
                db_version = cur.fetchone()[0]
            conn.commit()

        return jsonify({
            "message": "Hello from HA Platform!",
            "total_visits": count,
            "db_version": db_version,
            "status": "success"
        }), 200

    except Exception as e:
        return jsonify({"error": str(e), "status": "error"}), 500


if __name__ == "__main__":
    init_db()
    app.run(host="0.0.0.0", port=8080)