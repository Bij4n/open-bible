from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from sentence_transformers import SentenceTransformer
from typing import List

MODEL_NAME = "all-MiniLM-L6-v2"

app = FastAPI(title="Open Bible Embedding Service")

# Loaded once at process start. ~80MB download on first run; cached
# afterwards in ~/.cache/huggingface/.
model = SentenceTransformer(MODEL_NAME)


class EmbedRequest(BaseModel):
    texts: List[str]


class EmbedResponse(BaseModel):
    embeddings: List[List[float]]
    model_version: str


@app.post("/embed", response_model=EmbedResponse)
def embed_texts(request: EmbedRequest) -> EmbedResponse:
    if not request.texts:
        return EmbedResponse(embeddings=[], model_version=MODEL_NAME)
    try:
        vectors = model.encode(request.texts).tolist()
        return EmbedResponse(embeddings=vectors, model_version=MODEL_NAME)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.get("/health")
def health_check() -> dict:
    return {"status": "healthy", "model": MODEL_NAME}
