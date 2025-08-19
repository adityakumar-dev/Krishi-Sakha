# brain/model_run.py

from brain.brain_init import default_model, voice_model
from configs.model_config import DEFAULT_SYSTEM_MESSAGE, VOICE_SYSTEM_MESSAGE
from langchain.prompts import ChatPromptTemplate
from langchain.schema.output_parser import StrOutputParser
from langchain.schema import HumanMessage
import logging
from datetime import datetime
from typing import Any, AsyncGenerator, Dict, Optional

from routes.helpers.push_supabase import push_to_supabase

logger = logging.getLogger(__name__)

class ModelRun:
    def __init__(self):
        self.default_model = default_model
        self.voice_model = voice_model

        self.rag_template = ChatPromptTemplate.from_messages([
            ("system", DEFAULT_SYSTEM_MESSAGE + "\n\nUse the following context to answer the user's question:\n{context}"),
            ("human", "{question}")
        ])

        self.general_template = ChatPromptTemplate.from_messages([
            ("system", DEFAULT_SYSTEM_MESSAGE),
            ("human", "{question}")
        ])

    async def generate(
        self,
        question: str,
        context: str = "",
        conversation_id: str = "",
        user_id: str = "",
        use_voice_model: bool = False,
        stream: bool = True
    ) -> AsyncGenerator[str, None]:

        template = self.rag_template if context else self.general_template
        model    = self.voice_model if use_voice_model else self.default_model
        chain    = template | model | StrOutputParser()

        chain_input = {"question": question}
        if context:
            chain_input["context"] = context

        full_response = ""

        if stream:
            async for chunk in chain.astream(chain_input):
                if chunk:
                    full_response += chunk
                    yield chunk
        else:
            full_response = await chain.ainvoke(chain_input)
            yield full_response

        # log only once at end
        await push_to_supabase(
            'chat_messages',
            {
                'conversation_id': conversation_id,
                'user_id': user_id,
                'message': full_response,
                'sender' : "assistant",
            }
        )

model_runner = ModelRun()