from dotenv import load_dotenv, find_dotenv
load_dotenv(find_dotenv())

from fastapi import FastAPI
from fastapi.responses import StreamingResponse
from langchain_ollama import ChatOllama
from routes import test, chat
app = FastAPI()


@app.get("/")
async def root():
    return {"msg": "Ollama+LangChain+FastAPI running"}



app.include_router(test.router)
app.include_router(chat.router)