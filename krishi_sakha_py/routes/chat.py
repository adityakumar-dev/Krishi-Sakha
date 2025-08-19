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

    async def event_stream():
        try:
            # 1) Processing query
            yield f"data: {json.dumps({'type': 'status', 'message': 'Processing query...'})}\n\n"

            # 2) Image handling
            if image:
                yield f"data: {json.dumps({'type': 'status', 'message': 'Processing uploaded image...'})}\n\n"
                img_bytes = await image.read()
                final_query = f"[Image uploaded: {image.filename}] {prompt}"
                context = ""
            else:
                final_query = prompt
                # 3) Route query
                yield f"data: {json.dumps({'type': 'status', 'message': 'Routing query...'})}\n\n"
                routing = route_question(prompt)
                logger.info(f"Routing result: {routing}")
                domain = routing.get("domain", "general")
                keywords = routing.get("keywords", [])

                # 4) Search for context
                yield f"data: {json.dumps({'type': 'status', 'message': 'Searching for context...'})}\n\n"
                if domain == "general":
                    context = ""
                else:
                    collection_name = domain  # must match your ChromaDB collection
                    db_manager = PDFVectorDBManager(
                        vector_db_type="chroma",
                        embedding_method="sentence_transformers",
                        db_path="/home/linmar/Desktop/Krishi-Sakha/krishi_sakha_py/chroma_db",
                        collection_name=collection_name
                    )
                    search_query = " ".join(keywords) if keywords else prompt
                    results = db_manager.search_documents(query=search_query, n_results=5)
                    if not results.get("documents") or results["documents"] == [[]]:
                        results = db_manager.search_documents(query=prompt, n_results=5)
                    docs_flat = flatten_docs(results.get("documents", []))
                    context = "\n".join(docs_flat) if docs_flat else ""
                    yield f"data: {json.dumps({'type': 'status', 'message': f'Context found: {len(docs_flat)} documents'})}\n\n"

            # 5) Generating response
            yield f"data: {json.dumps({'type': 'status', 'message': 'Generating response...'})}\n\n"

            # 6) Stream LLM output
            async for chunk in model_runner.generate(
                question=final_query,
                context=context,
                conversation_id=conversation_id,
                user_id=user_id,
                use_voice_model=False,
                stream=True
            ):
                yield f"data: {json.dumps({'type': 'text', 'chunk': chunk})}\n\n"

            # 7) Done
            yield f"data: {json.dumps({'type': 'complete', 'chunk': 'Done'})}\n\n"

        except Exception as e:
            yield f"data: {json.dumps({'type': 'error', 'message': str(e)})}\n\n"

    return StreamingResponse(event_stream(), media_type="text/event-stream")
