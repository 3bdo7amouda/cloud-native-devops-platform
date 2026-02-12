# 🗳️ Voting App Source

Application services for the demo voting workload.

## 🧩 Services

| Path | Stack | Purpose |
| --- | --- | --- |
| `voting-app/vote/` | Python Flask | Accepts votes and writes to MongoDB |
| `voting-app/result/` | Node.js + Socket.IO | Reads vote counts and streams live results |
| `voting-app/worker/` | .NET | Legacy Redis-to-Mongo worker (optional) |

## 🗃️ Data Model

MongoDB collection: `voting.votes`
- `vote` currently keeps a single document (`_id = singleton`) for latest-vote behavior.
- `result` aggregates by `vote` field and publishes percentages via Socket.IO.
- `worker` (legacy mode) upserts by `voter_id` when consuming from Redis.

## ✅ Vote Service (`voting-app/vote`)

Endpoints:
- `GET /healthz`
- `GET /` redirects to `${BASE_PATH}/`
- `GET|POST ${BASE_PATH}` and `${BASE_PATH}/`

Environment:
- `MONGODB_URI` (required)
- `DATABASE_NAME` (default: `voting`)
- `BASE_PATH` (default: `/api/vote`)
- `OPTION_A` (default: `Cats`)
- `OPTION_B` (default: `Dogs`)

UI assets:
- Template: `voting-app/vote/templates/index.html`
- Styles: `voting-app/vote/static/stylesheets/style.css`

## 📊 Result Service (`voting-app/result`)

Behavior:
- Connects to MongoDB collection `votes`
- Aggregates counts every second
- Emits `scores` over Socket.IO
- Serves UI and Socket.IO under `BASE_PATH`

Endpoints:
- `GET /healthz`
- `GET ${BASE_PATH}` and `GET ${BASE_PATH}/`
- Socket.IO path: `${BASE_PATH}/socket.io`

Environment:
- `MONGODB_URI` (required in cluster)
- `DATABASE_NAME` (default: `voting`)
- `BASE_PATH` (default: `/api/result`)
- `PORT` (default: `4000`; container sets `80`)

UI assets:
- `voting-app/result/views/index.html`
- `voting-app/result/views/app.js`
- `voting-app/result/views/socket.io.js`
- `voting-app/result/views/angular.min.js`
- `voting-app/result/views/stylesheets/style.css`

## 🧪 Worker Service (`voting-app/worker`) - Legacy

Status:
- Kept for compatibility with the original multi-component pattern.
- Disabled by default in Helm (`worker.enabled=false`).
- Current primary flow in this repo is MongoDB-only (`vote` -> MongoDB -> `result`).

Environment:
- `REDIS_HOST` (default: `redis`)
- `MONGODB_URI` (default fallback: `mongodb://localhost:27017`)

Runtime behavior:
- Pops JSON from Redis list `votes`
- Expected shape: `{ "vote": "a|b", "voter_id": "..." }`
- Upserts into MongoDB collection `voting.votes` with `_id = voter_id`

## 🐳 Build Images

```bash
docker build -t voting-app-vote:latest -f voting-app/vote/Dockerfile voting-app/vote
docker build -t voting-app-result:latest -f voting-app/result/Dockerfile voting-app/result
docker build -t voting-app-worker:latest -f voting-app/worker/Dockerfile voting-app/worker
```

## ▶️ Local Run

Vote:

```bash
cd voting-app/vote
pip install -r requirements.txt
MONGODB_URI='<mongodb-uri>' BASE_PATH='/api/vote' python app.py
```

Result:

```bash
cd voting-app/result
npm install
MONGODB_URI='<mongodb-uri>' BASE_PATH='/api/result' PORT=4000 node server.js
```
