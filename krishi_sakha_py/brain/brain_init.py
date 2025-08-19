from langchain_ollama import ChatOllama
from configs.model_config import MODEL_NAME, DEFAULT_SYSTEM_MESSAGE, VOICE_SYSTEM_MESSAGE

# Default model for text-only queries
default_model = ChatOllama(
    model=MODEL_NAME,
    # Don't set system message here - we'll handle it in the templates
)    

# Voice model for voice queries
voice_model = ChatOllama(
    model=MODEL_NAME,
    # Don't set system message here - we'll handle it in the templates
)

# Vision model - using Gemma 3 4B for vision tasks
vision_model = ChatOllama(
    model=MODEL_NAME,  # Using Gemma 3 4B for vision as well
    # Don't set system message here - we'll handle it in the templates
)




