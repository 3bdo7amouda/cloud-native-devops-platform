from datetime import datetime
from flask import Flask, redirect, render_template, request
from pymongo import MongoClient
import os
import socket
import logging

option_a = os.getenv('OPTION_A', "Cats")
option_b = os.getenv('OPTION_B', "Dogs")
hostname = socket.gethostname()

BASE_PATH = os.getenv("BASE_PATH", "/api/vote").rstrip("/")
STATIC_URL_PATH = "/static" if not BASE_PATH else f"{BASE_PATH}/static"

app = Flask(__name__, static_url_path=STATIC_URL_PATH)

gunicorn_error_logger = logging.getLogger('gunicorn.error')
app.logger.handlers.extend(gunicorn_error_logger.handlers)
app.logger.setLevel(logging.INFO)

_MONGO_CLIENT = None


def get_votes_collection():
    global _MONGO_CLIENT

    mongo_uri = os.getenv("MONGODB_URI")
    if not mongo_uri:
        raise RuntimeError("MONGODB_URI is required")

    db_name = os.getenv("DATABASE_NAME", "voting")

    if _MONGO_CLIENT is None:
        _MONGO_CLIENT = MongoClient(
            mongo_uri,
            serverSelectionTimeoutMS=5000,
            connectTimeoutMS=10000,
        )

    return _MONGO_CLIENT[db_name]["votes"]


@app.get("/healthz")
def healthz():
    return "ok", 200


@app.get("/")
def root():
    # Keep a friendly root for local dev and simple probes.
    return redirect(f"{BASE_PATH}/", code=302)


@app.route(f"{BASE_PATH}", methods=["GET", "POST"])
@app.route(f"{BASE_PATH}/", methods=["GET", "POST"])
def vote():
    vote = None

    if request.method == 'POST':
        vote = request.form['vote']
        app.logger.info('Received vote for %s', vote)

        try:
            collection = get_votes_collection()
            # Keep only a single vote in the collection so the latest choice is 100%.
            collection.delete_many({})
            collection.update_one(
                {"_id": "singleton"},
                {"$set": {"vote": vote, "updated_at": datetime.utcnow()}},
                upsert=True,
            )
        except Exception as exc:
            app.logger.exception("Failed to write vote to MongoDB: %s", exc)
            return "Database error", 500

    return render_template(
        'index.html',
        option_a=option_a,
        option_b=option_b,
        hostname=hostname,
        vote=vote,
        base_path=BASE_PATH,
    )


if __name__ == "__main__":
    app.run(host='0.0.0.0', port=80, debug=True, threaded=True)
