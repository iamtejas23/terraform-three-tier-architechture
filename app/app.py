import json
import logging
import os

import boto3
import pymysql
from flask import Flask, jsonify, redirect, render_template, request, url_for

app = Flask(__name__)
logging.basicConfig(level=logging.INFO, format="%(levelname)s %(name)s %(message)s")
logger = logging.getLogger(__name__)


def _get_db_credentials() -> dict:
    secret_arn = os.environ.get("DB_SECRET_ARN")
    if secret_arn:
        region = os.environ.get("AWS_REGION", "us-east-1")
        client = boto3.client("secretsmanager", region_name=region)
        secret = client.get_secret_value(SecretId=secret_arn)
        return json.loads(secret["SecretString"])

    return {
        "host":     os.environ.get("DB_HOST", "localhost"),
        "username": os.environ.get("DB_USER", "root"),
        "password": os.environ.get("DB_PASSWORD", ""),
        "dbname":   os.environ.get("DB_NAME", "appdb"),
        "port":     int(os.environ.get("DB_PORT", 3306)),
    }


def _connect():
    creds = _get_db_credentials()
    return pymysql.connect(
        host=creds["host"],
        user=creds["username"],
        password=creds["password"],
        database=creds["dbname"],
        port=int(creds.get("port", 3306)),
        connect_timeout=5,
        cursorclass=pymysql.cursors.DictCursor,
    )


def _ensure_table():
    conn = _connect()
    with conn.cursor() as cur:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS items (
                id         INT AUTO_INCREMENT PRIMARY KEY,
                name       VARCHAR(255) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
    conn.commit()
    conn.close()


# ── UI Routes ─────────────────────────────────────────────────────────────────

@app.get("/")
def index():
    env = os.environ.get("ENVIRONMENT", "local")
    items = []
    error = None
    try:
        _ensure_table()
        conn = _connect()
        with conn.cursor() as cur:
            cur.execute("SELECT id, name, created_at FROM items ORDER BY id DESC")
            items = cur.fetchall()
        conn.close()
        for row in items:
            if row.get("created_at"):
                row["created_at"] = str(row["created_at"])
    except Exception as exc:
        logger.exception("index load failed")
        error = str(exc)
    return render_template("index.html", items=items, env=env, error=error)


@app.post("/items")
def add_item():
    name = request.form.get("name", "").strip()
    if not name:
        return redirect(url_for("index"))
    try:
        _ensure_table()
        conn = _connect()
        with conn.cursor() as cur:
            cur.execute("INSERT INTO items (name) VALUES (%s)", (name,))
        conn.commit()
        conn.close()
    except Exception as exc:
        logger.exception("add_item failed")
    return redirect(url_for("index"))


@app.post("/items/<int:item_id>/delete")
def delete_item(item_id):
    try:
        conn = _connect()
        with conn.cursor() as cur:
            cur.execute("DELETE FROM items WHERE id = %s", (item_id,))
        conn.commit()
        conn.close()
    except Exception as exc:
        logger.exception("delete_item failed")
    return redirect(url_for("index"))


# ── API Routes (JSON) ─────────────────────────────────────────────────────────

@app.get("/health")
def health():
    return jsonify({"status": "ok"}), 200


@app.get("/api/items")
def api_items():
    try:
        _ensure_table()
        conn = _connect()
        with conn.cursor() as cur:
            cur.execute("SELECT id, name, created_at FROM items ORDER BY id")
            rows = cur.fetchall()
        conn.close()
        for row in rows:
            if row.get("created_at"):
                row["created_at"] = str(row["created_at"])
        return jsonify({"items": rows})
    except Exception as exc:
        logger.exception("api_items failed")
        return jsonify({"error": str(exc)}), 500


@app.get("/db/init")
def db_init():
    try:
        _ensure_table()
        conn = _connect()
        with conn.cursor() as cur:
            cur.execute("SELECT COUNT(*) AS cnt FROM items")
            if cur.fetchone()["cnt"] == 0:
                cur.executemany(
                    "INSERT INTO items (name) VALUES (%s)",
                    [("Alpha",), ("Beta",), ("Gamma",)],
                )
        conn.commit()
        conn.close()
        return jsonify({"status": "db initialized"})
    except Exception as exc:
        logger.exception("db_init failed")
        return jsonify({"error": str(exc)}), 500


if __name__ == "__main__":
    port = int(os.environ.get("APP_PORT", 8080))
    app.run(host="0.0.0.0", port=port)
