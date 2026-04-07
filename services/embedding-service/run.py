import os
import uvicorn

if __name__ == "__main__":
    port = int(os.environ.get("EMBEDDING_SERVICE_PORT", "8000"))
    reload = os.environ.get("EMBEDDING_SERVICE_RELOAD", "false").lower() == "true"
    uvicorn.run("app:app", host="127.0.0.1", port=port, reload=reload)
