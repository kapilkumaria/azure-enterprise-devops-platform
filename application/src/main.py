from fastapi import FastAPI
import os

app = FastAPI(
    title="Azure Enterprise DevOps Platform Demo",
    version="1.0.0"
)

@app.get("/")
def root():
    return {
        "message": "Azure Enterprise DevOps Platform - Fully Templated CD",
        "environment": os.getenv("ENVIRONMENT", "unknown")
    }

@app.get("/health")
def health():
    return {"status": "healthy"}

@app.get("/ready")
def ready():
    return {"status": "ready"}

@app.get("/config")
def config():
    return {
        "environment": os.getenv("ENVIRONMENT", "unknown"),
        "secret_configured": bool(os.getenv("DEMO_MESSAGE"))
    }
