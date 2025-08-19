from fastapi import APIRouter, UploadFile, File, Form, Depends
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


def flatten_docs(docs: List[Any]) -> List[str]:
    """
    Recursively flatten a list of documents which may contain strings or nested lists of strings.
    Returns a flat list of strings.
    """
    flat_list = []
    for doc in docs:
        if isinstance(doc, str):
            flat_list.append(doc)
        elif isinstance(doc, list):
            flat_list.extend(flatten_docs(doc))
        else:
            flat_list.append(str(doc))
    return flat_list
@router.post("/chat")
async def chat_endpoint(
    prompt: str = Form(...),
    conversation_id: str = Form(...),
    image: Optional[UploadFile] = File(None),
    user=Depends(supabase_jwt_middleware)
):
    user_id = user.get("sub")
    logger.info(f"User: {user_id}, Conversation: {conversation_id}")

    # Read image bytes ONLY ONCE here:
    image_bytes = None
    if image:
        image_bytes = await image.read()
        logger.info(f"Read {len(image_bytes)} bytes from image")

    async def event_stream():
        try:
            # ---------------------------------------------------------------------
            # IMAGE REQUEST
            # ---------------------------------------------------------------------
            if image_bytes:
                yield f"data: {json.dumps({'type': 'status', 'message': 'Processing uploaded image...'})}\n\n"

                import os
                temp_dir = "./temp"
                os.makedirs(temp_dir, exist_ok=True)
                image_path = f"{temp_dir}/{image.filename}"

                with open(image_path, "wb") as f:
                    f.write(image_bytes)
                logger.info(f"Saved temp image to {image_path}")

                final_query = prompt if prompt.strip() else "What do you see in this image?"

                async for chunk in model_runner.generate_image(
                    question=final_query,
                    conversation_id=conversation_id,
                    user_id=user_id,
                    image_path=image_path,
                    stream=True
                ):
                    yield f"data: {json.dumps({'type': 'text', 'chunk': chunk})}\n\n"

                # Done
                yield "data: {\"type\": \"complete\"}\n\n"

                # Clean up temp file
                try:
                    os.remove(image_path)
                    logger.info("Temp image removed")
                except Exception as cleanup_err:
                    logger.warning(f"Failed to cleanup temp image: {cleanup_err}")

                return  # Stop here (do not go to text flow)

            # ---------------------------------------------------------------------
            # TEXT-ONLY REQUEST
            # ---------------------------------------------------------------------
            yield f"data: {json.dumps({'type': 'status', 'message': 'Processing query...'})}\n\n"
            yield f"data: {json.dumps({'type': 'status', 'message': 'Routing query...'})}\n\n"

            routing = route_question(prompt)
            logger.info(f"Routing result: {routing}")

            domain = routing.get("domain", "general")
            keywords = routing.get("keywords", [])

            # Retrieve context if needed
            context = ""
            if domain != "general":
                yield f"data: {json.dumps({'type': 'status', 'message': 'Searching for context...'})}\n\n"
                db_manager = PDFVectorDBManager(
                    vector_db_type="chroma",
                    embedding_method="sentence_transformers",
                    db_path="/home/linmar/Desktop/Krishi-Sakha/krishi_sakha_py/chroma_db",
                    collection_name=domain
                )

                search_query = " ".join(keywords) if keywords else prompt
                results = db_manager.search_documents(query=search_query, n_results=5)
                if not results.get("documents") or results["documents"] == [[]]:
                    results = db_manager.search_documents(query=prompt, n_results=5)
                docs_flat = flatten_docs(results.get("documents", []))
                context = "\n".join(docs_flat) if docs_flat else ""

                yield f"data: {json.dumps({'type': 'status', 'message': f'Context found: {len(docs_flat)} documents'})}\n\n"

            # Stream normal model
            yield f"data: {json.dumps({'type': 'status', 'message': 'Generating response...'})}\n\n"
            async for chunk in model_runner.generate(
                question=prompt,
                context=context,
                conversation_id=conversation_id,
                user_id=user_id,
                stream=True
            ):
                yield f"data: {json.dumps({'type': 'text', 'chunk': chunk})}\n\n"

            yield f"data: {json.dumps({'type': 'complete'})}\n\n"

        except Exception as e:
            logger.error(f"General error in chat endpoint: {str(e)}", exc_info=True)
            yield f"data: {json.dumps({'type': 'error', 'message': str(e)})}\n\n"

    return StreamingResponse(event_stream(), media_type="text/event-stream")
