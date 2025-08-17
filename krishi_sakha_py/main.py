from fastapi import FastAPI
from fastapi.responses import StreamingResponse
from langchain_ollama import ChatOllama

app = FastAPI()


@app.get("/")
async def root():
    return {"msg": "Ollama+LangChain+FastAPI running"}


