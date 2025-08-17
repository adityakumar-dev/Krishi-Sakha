from fastapi import APIRouter, File, UploadFile, Form, Depends, HTTPException, Request
from fastapi.responses import StreamingResponse
from typing import Optional, List, Dict
import logging
import json
import os

from brain.model_run import rag_runner  # Your SimpleRAG instance
from routes.helpers.router_picker import route_question
from routes.helpers.push_supabase import push_to_supabase

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

router = APIRouter()


@router.post("/chat")
async def chat_endpoint(
    prompt: str = Form(...),
    conversation_id: int = Form(...),
    history: Optional[List[Dict[str, str]]] = None,
    image: Optional[UploadFile] = File(None),
    request: Request = None
):
    """
    Chat endpoint supporting text prompt + optional image with streaming RAG responses.
    """
    try:
        # Default user_id
        user_id = "anonymous"
        if hasattr(request.state, "user") and request.state.user:
            user_id = request.state.user.get("sub", "anonymous")

        logger.info(f"Chat request from user: {user_id}, prompt: {prompt[:100]}...")

        # If image is uploaded, prepend info to prompt
        if image:
            prompt = f"[Image uploaded: {image.filename}] {prompt}"

        # Streaming generator
        async def generate_stream():
            full_response = ""
            try:
                async for chunk in rag_runner.generate_response(query=prompt, user_id=user_id, stream=True):
                    full_response += chunk
                    # Each chunk as JSON for frontend
                    yield f"data: {json.dumps({'type': 'partial_response', 'content': chunk, 'query_type': route_question(prompt)['domain']})}\n\n"

                # Push complete message to Supabase
                await push_to_supabase("chat_messages", {
                    "conversation_id": conversation_id,
                    "user_id": user_id,
                    "sender": "ai",
                    "message": full_response
                })

                # Notify frontend that streaming is complete
                yield f"data: {json.dumps({'type': 'complete', 'content': full_response})}\n\n"

            except Exception as e:
                err_msg = f"Error in streaming: {e}"
                logger.error(err_msg)
                yield f"data: {json.dumps({'type': 'error', 'content': err_msg})}\n\n"

        return StreamingResponse(
            generate_stream(),
            media_type="text/event-stream",
            headers={
                "Cache-Control": "no-cache",
                "Connection": "keep-alive",
                "Content-Type": "text/event-stream"
            }
        )

    except Exception as e:
        logger.error(f"Error in chat endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))
