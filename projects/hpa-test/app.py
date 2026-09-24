from fastapi import FastAPI
from prometheus_client import Counter, Gauge, generate_latest, CONTENT_TYPE_LATEST
from fastapi.responses import Response
import hashlib
import time

app = FastAPI()

REQUEST_COUNT = Counter('infer_requests_total', 'Total infer requests')
IN_FLIGHT = Gauge('infer_queue_length', 'Current in-flight requests')

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/infer")
def infer():
    REQUEST_COUNT.inc()
    IN_FLIGHT.inc()
    try:
        data = b"x"
        for _ in range(50000):
            data = hashlib.sha256(data).digest()
        time.sleep(0.1)
    finally:
        IN_FLIGHT.dec()
    return {"result": data.hex()[:16]}

@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
