"""
Context retriever for vector database search and formatting.
Inspired by add_pdfs_to_vectordb.py search functionality.
"""

import logging
from typing import Dict, List, Tuple, Optional, Any
from data.functions.add_to_vector_db import PDFVectorDBManager

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def retrieve_context(
    vector_db_manager: PDFVectorDBManager,
    query: str,
    domain: str,
    max_results: int = 5,
    **metadata_filters
) -> Tuple[str, List[Dict]]:
    """
    Retrieve relevant context from vector database based on query and domain.
    
    Args:
        vector_db_manager: Vector database manager instance
        query: Search query
        domain: Domain type (general, annual_report, search, image)
        max_results: Maximum number of results to return
        **metadata_filters: Additional metadata filters for fine-grained search
        
    Returns:
        Tuple of (formatted_context_string, raw_results_list)
    """
    if not vector_db_manager:
        logger.warning("Vector database manager not available")
        return "No vector database available.", []
    
    try:
        # Prepare search parameters
        search_kwargs = {
            'query': query,
            'n_results': max_results,
            **metadata_filters
        }
        
        # Apply domain-specific filters
        if domain == "annual_report":
            search_kwargs['document_type'] = "annual_report"
        elif domain == "search":
            # For search domain, we want broader results
            pass
        elif domain == "general":
            # For general queries, we might not need context
            return "No additional context needed for general queries.", []
        
        logger.info(f"Searching vector DB with query: '{query}', domain: '{domain}'")
        
        # Perform the search
        results = vector_db_manager.search_documents(**search_kwargs)
        
        if not results or 'documents' not in results:
            logger.warning("No results found in vector database")
            return "No relevant context found in knowledge base.", []
        
        # Format the context
        formatted_context = format_search_results(results, max_results)
        
        # Extract raw results for logging/debugging
        raw_results = extract_raw_results(results)
        
        logger.info(f"Retrieved {len(raw_results)} context chunks for domain '{domain}'")
        
        return formatted_context, raw_results
        
    except Exception as e:
        logger.error(f"Error retrieving context from vector DB: {e}")
        return f"Error retrieving context: {str(e)}", []


def format_search_results(results: Dict, max_results: int = 5) -> str:
    """
    Format search results into a readable context string.
    
    Args:
        results: Raw search results from vector database
        max_results: Maximum number of results to format
        
    Returns:
        Formatted context string
    """
    if not results or 'documents' not in results:
        return "No relevant context found."
    
    documents = results['documents']
    metadatas = results.get('metadatas', [])
    distances = results.get('distances', [])
    
    # Handle nested list format (ChromaDB sometimes returns nested lists)
    if isinstance(documents, list) and len(documents) > 0 and isinstance(documents[0], list):
        documents = documents[0]
        metadatas = metadatas[0] if metadatas else []
        distances = distances[0] if distances else []
    
    if not documents:
        return "No relevant context found."
    
    context_parts = []
    context_parts.append("=== RELEVANT CONTEXT ===\n")
    
    for i, doc in enumerate(documents[:max_results]):
        if not doc or not doc.strip():
            continue
            
        # Get metadata if available
        metadata = metadatas[i] if i < len(metadatas) else {}
        distance = distances[i] if i < len(distances) else None
        
        # Format source information
        source_info = []
        if metadata.get('organization'):
            source_info.append(f"Org: {metadata['organization']}")
        if metadata.get('document_type'):
            source_info.append(f"Type: {metadata['document_type']}")
        if metadata.get('filename'):
            source_info.append(f"File: {metadata['filename']}")
        if metadata.get('page_number'):
            source_info.append(f"Page: {metadata['page_number']}")
        
        source_str = " | ".join(source_info) if source_info else "Unknown source"
        
        # Add context chunk
        context_parts.append(f"[Context {i+1}] ({source_str})")
        if distance is not None:
            context_parts.append(f"Relevance Score: {1 - distance:.3f}")
        context_parts.append(f"{doc.strip()}\n")
    
    context_parts.append("=== END CONTEXT ===")
    
    return "\n".join(context_parts)


def extract_raw_results(results: Dict) -> List[Dict]:
    """
    Extract raw results for logging and debugging purposes.
    
    Args:
        results: Raw search results from vector database
        
    Returns:
        List of result dictionaries
    """
    if not results or 'documents' not in results:
        return []
    
    documents = results['documents']
    metadatas = results.get('metadatas', [])
    distances = results.get('distances', [])
    
    # Handle nested list format
    if isinstance(documents, list) and len(documents) > 0 and isinstance(documents[0], list):
        documents = documents[0]
        metadatas = metadatas[0] if metadatas else []
        distances = distances[0] if distances else []
    
    raw_results = []
    for i, doc in enumerate(documents):
        result = {
            'document': doc,
            'metadata': metadatas[i] if i < len(metadatas) else {},
            'distance': distances[i] if i < len(distances) else None
        }
        raw_results.append(result)
    
    return raw_results


def search_vector_db_only(
    vector_db_manager: PDFVectorDBManager,
    query: str,
    max_results: int = 10,
    **filters
) -> Dict[str, Any]:
    """
    Search vector database without formatting - returns raw results.
    Useful for knowledge base search endpoints.
    
    Args:
        vector_db_manager: Vector database manager instance
        query: Search query
        max_results: Maximum number of results
        **filters: Metadata filters
        
    Returns:
        Dictionary with search results and metadata
    """
    if not vector_db_manager:
        return {'error': 'Vector database not available', 'results': []}
    
    try:
        search_kwargs = {
            'query': query,
            'n_results': max_results,
            **filters
        }
        
        logger.info(f"Direct vector DB search: '{query}' with filters: {filters}")
        
        results = vector_db_manager.search_documents(**search_kwargs)
        raw_results = extract_raw_results(results)
        
        return {
            'query': query,
            'filters': filters,
            'total_results': len(raw_results),
            'results': raw_results
        }
        
    except Exception as e:
        logger.error(f"Error in direct vector DB search: {e}")
        return {'error': str(e), 'results': []}
