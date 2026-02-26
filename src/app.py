import os
import time
import psycopg2
from flask import Flask, jsonify

app = Flask(__name__)


@app.route("/health")
def health():
    return "OK", 200

@app.route("/ready")
def ready():
    try:
        conn = get_db_connection()
        conn.close()
        return "READY", 200
    except Exception:
        return "NOT READY", 503


def get_db_connection():
    return psycopg2.connect(
        host=os.getenv("DB_HOST", "postgres"),
        database=os.getenv("DB_NAME", "appdb"),
        user=os.getenv("DB_USER", "postgres"),
        password=os.getenv("DB_PASSWORD", "postgres"),
        connect_timeout=5
    )

def init_db():
    """
    Ensures table exists before app starts.
    Retries until database is reachable.
    """
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
            print(f"Waiting for database... {e}")
            time.sleep(2)


@app.route("/")
def index():
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("INSERT INTO visits DEFAULT VALUES;")
                cur.execute("SELECT COUNT(*) FROM visits;")
                count = cur.fetchone()[0]
            conn.commit()

        return jsonify({
            "message": "Hello from HA Platform!",
            "total_visits": count
        }), 200

    except Exception as e:
        return jsonify({
            "error": str(e)
        }), 500



if __name__ == "__main__":
    init_db()
    app.run(host="0.0.0.0", port=8080)