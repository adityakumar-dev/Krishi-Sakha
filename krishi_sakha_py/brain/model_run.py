# brain/model_run.py

from brain.brain_init import default_model, voice_model, vision_model
from configs.model_config import DEFAULT_SYSTEM_MESSAGE, VOICE_SYSTEM_MESSAGE
from langchain.prompts import ChatPromptTemplate
from langchain.schema.output_parser import StrOutputParser
from langchain.schema import HumanMessage, SystemMessage
import logging
import base64
from datetime import datetime
from typing import Any, AsyncGenerator, Dict, Optional,List

from routes.helpers.push_supabase import push_to_supabase

logger = logging.getLogger(__name__)

class ModelRun:
    def __init__(self):
        self.default_model = default_model
        self.voice_model = voice_model
        self.vision_model = vision_model

        self.rag_template = ChatPromptTemplate.from_messages([
            ("system", DEFAULT_SYSTEM_MESSAGE + "\n\nUse the following context to answer the user's question:\n{context}"),
            ("human", "{question}")
        ])
        self.voice_template = ChatPromptTemplate.from_messages([
            ("system", VOICE_SYSTEM_MESSAGE),
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
        stream: bool = True,
        push_to_db: bool = True,
        metadata: Optional[List[List[str]]] = None
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
        if push_to_db:
            push_to_supabase(
                'chat_messages',
                {
                    'conversation_id': conversation_id,
                    'user_id': user_id,
                    'message': full_response,
                    'sender' : "assistant",
                    'metadata' : metadata
            }
        )

    async def generate_image(
        self,
        question: str,
        conversation_id: str = "",
        user_id: str = "",
        image_path: str = "",
        history: Optional[List[Dict[str, str]]] = None,
        stream: bool = True
    ) -> AsyncGenerator[str, None]:

        if image_path == "":
            raise ValueError("generate_image() requires image_path != None")

        pushed = False
        try:
            # Read and encode image to base64 (following your reference script)
            logger.info(f"Reading image from: {image_path}")
            with open(image_path, "rb") as f:
                image_bytes = f.read()
            logger.info(f"Image size: {len(image_bytes)} bytes")
            # Encode image to base64 with proper data URL format
            image_b64 = base64.b64encode(image_bytes).decode("utf-8")
            data_url = f"data:image/jpeg;base64,{image_b64}"
            logger.info(f"Question: {question}")
            logger.info(f"Data URL length: {len(data_url)}")
            # Build LangChain HumanMessage with image + text (following your reference script)
            message = HumanMessage(
                content=[
                    {"type": "text", "text": question},
                    {"type": "image_url", "image_url": {"url": data_url}}
                ]
            )
            logger.info("HumanMessage created successfully")
            # Run / stream the model with image
            logger.info("Starting model streaming...")
            full_response = ""
            if stream:
                chunk_count = 0
                async for chunk in self.vision_model.astream([message]):
                    chunk_count += 1
                    logger.info(f"Received chunk {chunk_count}: {type(chunk)}")
                    if chunk and hasattr(chunk, 'content') and chunk.content:
                        content = chunk.content
                        logger.info(f"Chunk content: {content[:100]}...")
                        full_response += content
                        yield content
                    elif isinstance(chunk, str):
                        logger.info(f"String chunk: {chunk[:100]}...")
                        full_response += chunk
                        yield chunk
                    else:
                        logger.info(f"Unknown chunk type: {chunk}")
                logger.info(f"Streaming completed. Total chunks: {chunk_count}, Response length: {len(full_response)}")
            else:
                logger.info("Using non-streaming mode...")
                response = await self.vision_model.ainvoke([message])
                logger.info(f"Response type: {type(response)}")
                content = response.content if hasattr(response, 'content') else str(response)
                full_response = content
                yield content
            # Save assistant response (only if no exception)
            if full_response:
                await push_to_supabase(
                    'chat_messages',
                    {
                        'conversation_id': conversation_id,
                        'user_id': user_id,
                        'message': full_response,
                        'sender': "assistant",
                    }
                )
                pushed = True
        except Exception as e:
            logger.error(f"Error in generate_image: {str(e)}")
            error_msg = f"Sorry, I encountered an error processing the image: {str(e)}"
            yield error_msg
            # Save error message only if not already pushed
            if not pushed:
                await push_to_supabase(
                    'chat_messages',
                    {
                        'conversation_id': conversation_id,
                        'user_id': user_id,
                        'message': error_msg,
                        'sender': "assistant",
                    }
                )
    async def generate_voice(
        self,
        question: str,
    ) -> AsyncGenerator[str, None]:

        template = self.voice_template
        model    = self.voice_model
        chain    = template | model | StrOutputParser()

        chain_input = {"question": question}

        async for chunk in chain.astream(chain_input):
                if chunk:
                    yield chunk
 


model_runner = ModelRun()