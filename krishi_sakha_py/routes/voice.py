from fastapi import APIRouter, Form, Depends
from fastapi.responses import StreamingResponse
from typing import Optional, List, Any
import json
import logging

from routes.middlewares.auth_middleware import supabase_jwt_middleware
from brain.model_run import model_runner
from routes.helpers.router_picker import route_question
from data.functions.add_to_vector_db import PDFVectorDBManager

logger = logging.getLogger(__name__)
router = APIRouter()


router = APIRouter()
@router.post("/voice")
async def voice_endpoint(
    prompt: str = Form(...),
    user=Depends(supabase_jwt_middleware)
):
    user_id = user.get("sub")
    logger.info(f"[VOICE] user={user_id}, prompt={prompt}")

    async def event_stream():
        try:
            async for chunk in model_runner.generate_voice(
                question=prompt,
            ):
                yield f"data: {json.dumps({'type': 'text', 'chunk': chunk})}\n\n"

            # when loop ends, send a single "complete"
            yield f"data: {json.dumps({'type': 'complete'})}\n\n"

        except Exception as e:
            logger.error(f"Voice endpoint error: {e}", exc_info=True)
            yield f"data: {json.dumps({'type': 'error', 'message': str(e)})}\n\n"

    return StreamingResponse(event_stream(), media_type="text/event-stream")
