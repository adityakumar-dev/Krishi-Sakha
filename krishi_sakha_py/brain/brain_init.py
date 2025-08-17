from langchain_ollama import ChatOllama
from configs.model_config import MODEL_NAME, DEFAULT_SYSTEM_MESSAGE, VOICE_SYSTEM_MESSAGE

default_model = ChatOllama(
    model=MODEL_NAME,
    system=DEFAULT_SYSTEM_MESSAGE,
)    

voice_model = ChatOllama(
    model=MODEL_NAME,
    system=VOICE_SYSTEM_MESSAGE,
)    



