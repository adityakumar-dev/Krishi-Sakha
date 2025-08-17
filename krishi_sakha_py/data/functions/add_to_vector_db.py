import os
import logging
import json
from typing import List, Dict, Optional, Union
from pathlib import Path
from datetime import datetime
import hashlib

# Vector database imports
try:
    import chromadb
    from chromadb.config import Settings
    CHROMADB_AVAILABLE = True
except ImportError:
    chromadb = None
    CHROMADB_AVAILABLE = False

try:
    import faiss
    import numpy as np
    FAISS_AVAILABLE = True
except ImportError:
    faiss = None
    np = None
    FAISS_AVAILABLE = False

try:
    from sentence_transformers import SentenceTransformer
    SENTENCE_TRANSFORMERS_AVAILABLE = True
except ImportError:
    SentenceTransformer = None
    SENTENCE_TRANSFORMERS_AVAILABLE = False

try:
    import google.generativeai as genai
    from configs.external_keys import GEMINI_API_KEY
    GEMINI_AVAILABLE = True
except ImportError:
    genai = None
    GEMINI_AVAILABLE = False

# Local imports
from data.functions.parse_pdf import parse_pdf, parse_pdfs_from_directory

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class VectorDBError(Exception):
    """Custom exception for vector database operations"""
    pass


class EmbeddingGenerator:
    """Generate embeddings for text using various methods"""
    
    def __init__(self, method: str = "sentence_transformers", model_name: str = None):
        """
        Initialize embedding generator.
        
        Args:
            method: Embedding method ('sentence_transformers', 'gemini')
            model_name: Model name for the embedding method
        """
        self.method = method
        self.model = None
        
        if method == "sentence_transformers":
            if not SENTENCE_TRANSFORMERS_AVAILABLE:
                raise VectorDBError("sentence-transformers not available. Install with: pip install sentence-transformers")
            
            model_name = model_name or "all-MiniLM-L6-v2"
            self.model = SentenceTransformer(model_name)
            logger.info(f"Initialized SentenceTransformer with model: {model_name}")
            
        elif method == "gemini":
            if not GEMINI_AVAILABLE:
                raise VectorDBError("Gemini API not available. Check your API key configuration.")
            
            genai.configure(api_key=GEMINI_API_KEY)
            logger.info("Initialized Gemini embeddings")
            
        else:
            raise VectorDBError(f"Unsupported embedding method: {method}")
    
    def generate_embeddings(self, texts: List[str]) -> List[List[float]]:
        """
        Generate embeddings for a list of texts.
        
        Args:
            texts: List of text strings
            
        Returns:
            List of embedding vectors
        """
        if self.method == "sentence_transformers":
            embeddings = self.model.encode(texts, convert_to_tensor=False)
            return embeddings.tolist()
            
        elif self.method == "gemini":
            embeddings = []
            for text in texts:
                try:
                    result = genai.embed_content(
                        model="models/embedding-001",
                        content=text,
                        task_type="retrieval_document"
                    )
                    embeddings.append(result['embedding'])
                except Exception as e:
                    logger.error(f"Error generating Gemini embedding: {e}")
                    # Fallback to zero vector
                    embeddings.append([0.0] * 768)  # Gemini embedding dimension
            return embeddings
        
        else:
            raise VectorDBError(f"Unsupported embedding method: {self.method}")


class ChromaVectorDB:
    """ChromaDB implementation for vector storage"""
    
    def __init__(self, db_path: str = "./chroma_db", collection_name: str = "pdf_documents"):
        """
        Initialize ChromaDB client.
        
        Args:
            db_path: Path to store ChromaDB data
            collection_name: Name of the collection
        """
        if not CHROMADB_AVAILABLE:
            raise VectorDBError("ChromaDB not available. Install with: pip install chromadb")
        
        self.db_path = Path(db_path)
        self.db_path.mkdir(exist_ok=True)
        
        self.client = chromadb.PersistentClient(path=str(self.db_path))
        self.collection_name = collection_name
        
        # Create or get collection
        try:
            self.collection = self.client.get_collection(name=collection_name)
            logger.info(f"Loaded existing ChromaDB collection: {collection_name}")
        except:
            self.collection = self.client.create_collection(name=collection_name)
            logger.info(f"Created new ChromaDB collection: {collection_name}")
    
    def add_documents(self, chunks: List[Dict], embeddings: List[List[float]]):
        """
        Add document chunks to ChromaDB.
        
        Args:
            chunks: List of document chunks with metadata
            embeddings: List of embedding vectors
        """
        if len(chunks) != len(embeddings):
            raise VectorDBError("Number of chunks must match number of embeddings")
        
        ids = []
        documents = []
        metadatas = []
        
        for i, chunk in enumerate(chunks):
            # Generate unique ID for each chunk
            chunk_id = f"{chunk.get('file_hash', 'unknown')}_{i}"
            ids.append(chunk_id)
            documents.append(chunk['text'])
            
            # Prepare metadata (ChromaDB requires string values)
            chunk_metadata = chunk.get('metadata', {})
            metadata = {
                'source_file': str(chunk.get('source_file', '')),
                'chunk_index': str(chunk.get('chunk_index', i)),
                'file_hash': chunk.get('file_hash', ''),
                'created_at': chunk.get('created_at', datetime.now().isoformat()),
                'total_pages': str(chunk_metadata.get('total_pages', 0)),
                'extraction_method': chunk_metadata.get('extraction_method', ''),
                # Enhanced organizational metadata
                'organization': chunk_metadata.get('organization', 'Unknown'),
                'document_type': chunk_metadata.get('document_type', 'Unknown'),
                'document_category': chunk_metadata.get('document_category', 'General'),
                'publication_year': str(chunk_metadata.get('publication_year', 'Unknown')),
                'language': chunk_metadata.get('language', 'Unknown'),
                'document_title': chunk_metadata.get('document_title', ''),
                'file_size_bytes': str(chunk_metadata.get('file_size_bytes', 0)),
                'tags': ','.join(chunk_metadata.get('tags', [])),  # Convert list to comma-separated string
                'chunk_size': str(chunk_metadata.get('chunk_size', 0)),
                'total_chunks': str(chunk_metadata.get('total_chunks', 0))
            }
            metadatas.append(metadata)
        
        # Add to collection
        self.collection.add(
            ids=ids,
            embeddings=embeddings,
            documents=documents,
            metadatas=metadatas
        )
        
        logger.info(f"Added {len(chunks)} documents to ChromaDB collection")
    
    def search(self, query_embedding: List[float], n_results: int = 5, 
               where_filter: Dict = None) -> Dict:
        """
        Search for similar documents with optional metadata filtering.
        
        Args:
            query_embedding: Query embedding vector
            n_results: Number of results to return
            where_filter: Optional metadata filter (e.g., {"organization": "WHO"})
            
        Returns:
            Search results from ChromaDB
        """
        query_params = {
            "query_embeddings": [query_embedding],
            "n_results": n_results
        }
        
        if where_filter:
            query_params["where"] = where_filter
            
        results = self.collection.query(**query_params)
        return results
    
    def search_by_organization(self, query_embedding: List[float], 
                              organization: str, n_results: int = 5) -> Dict:
        """
        Search for documents from a specific organization.
        """
        return self.search(query_embedding, n_results, {"organization": organization})
    
    def search_by_document_type(self, query_embedding: List[float], 
                               document_type: str, n_results: int = 5) -> Dict:
        """
        Search for documents of a specific type.
        """
        return self.search(query_embedding, n_results, {"document_type": document_type})
    
    def search_by_year(self, query_embedding: List[float], 
                      year: str, n_results: int = 5) -> Dict:
        """
        Search for documents from a specific year.
        """
        return self.search(query_embedding, n_results, {"publication_year": year})


class FAISSVectorDB:
    """FAISS implementation for vector storage"""
    
    def __init__(self, db_path: str = "./faiss_db", dimension: int = 384):
        """
        Initialize FAISS index.
        
        Args:
            db_path: Path to store FAISS index
            dimension: Embedding dimension
        """
        if not FAISS_AVAILABLE:
            raise VectorDBError("FAISS not available. Install with: pip install faiss-cpu")
        
        self.db_path = Path(db_path)
        self.db_path.mkdir(exist_ok=True)
        
        self.dimension = dimension
        self.index_path = self.db_path / "index.faiss"
        self.metadata_path = self.db_path / "metadata.json"
        
        # Initialize or load index
        if self.index_path.exists():
            self.index = faiss.read_index(str(self.index_path))
            logger.info(f"Loaded existing FAISS index with {self.index.ntotal} vectors")
        else:
            self.index = faiss.IndexFlatIP(dimension)  # Inner product similarity
            logger.info(f"Created new FAISS index with dimension {dimension}")
        
        # Load metadata
        if self.metadata_path.exists():
            with open(self.metadata_path, 'r') as f:
                self.metadata = json.load(f)
        else:
            self.metadata = []
    
    def add_documents(self, chunks: List[Dict], embeddings: List[List[float]]):
        """
        Add document chunks to FAISS index.
        
        Args:
            chunks: List of document chunks with metadata
            embeddings: List of embedding vectors
        """
        if len(chunks) != len(embeddings):
            raise VectorDBError("Number of chunks must match number of embeddings")
        
        # Convert embeddings to numpy array
        embeddings_array = np.array(embeddings, dtype=np.float32)
        
        # Normalize embeddings for cosine similarity
        faiss.normalize_L2(embeddings_array)
        
        # Add to index
        self.index.add(embeddings_array)
        
        # Store metadata with enhanced structure
        for chunk in chunks:
            chunk_metadata = chunk.get('metadata', {})
            enhanced_chunk = {
                'text': chunk.get('text', ''),
                'source_file': chunk.get('source_file', ''),
                'chunk_index': chunk.get('chunk_index', 0),
                'file_hash': chunk.get('file_hash', ''),
                'created_at': chunk.get('created_at', datetime.now().isoformat()),
                # Enhanced organizational metadata
                'organization': chunk_metadata.get('organization', 'Unknown'),
                'document_type': chunk_metadata.get('document_type', 'Unknown'),
                'document_category': chunk_metadata.get('document_category', 'General'),
                'publication_year': chunk_metadata.get('publication_year', 'Unknown'),
                'language': chunk_metadata.get('language', 'Unknown'),
                'document_title': chunk_metadata.get('document_title', ''),
                'file_size_bytes': chunk_metadata.get('file_size_bytes', 0),
                'tags': chunk_metadata.get('tags', []),
                'total_pages': chunk_metadata.get('total_pages', 0),
                'extraction_method': chunk_metadata.get('extraction_method', ''),
                'chunk_size': chunk_metadata.get('chunk_size', 0),
                'total_chunks': chunk_metadata.get('total_chunks', 0)
            }
            self.metadata.append(enhanced_chunk)
        
        # Save index and metadata
        faiss.write_index(self.index, str(self.index_path))
        with open(self.metadata_path, 'w') as f:
            json.dump(self.metadata, f, indent=2)
        
        logger.info(f"Added {len(chunks)} documents to FAISS index")
    
    def search(self, query_embedding: List[float], n_results: int = 5) -> Dict:
        """
        Search for similar documents.
        
        Args:
            query_embedding: Query embedding vector
            n_results: Number of results to return
            
        Returns:
            Search results
        """
        query_array = np.array([query_embedding], dtype=np.float32)
        faiss.normalize_L2(query_array)
        
        scores, indices = self.index.search(query_array, n_results)
        
        results = {
            'documents': [],
            'metadatas': [],
            'distances': scores[0].tolist()
        }
        
        for idx in indices[0]:
            if idx < len(self.metadata):
                metadata = self.metadata[idx]
                results['documents'].append(metadata.get('text', ''))
                results['metadatas'].append(metadata)
        
        return results


class PDFVectorDBManager:
    """Main class for managing PDF to vector database operations"""
    
    def __init__(self, 
                 vector_db_type: str = "chroma",
                 embedding_method: str = "sentence_transformers",
                 db_path: str = None,
                 collection_name: str = "pdf_documents"):
        """
        Initialize the PDF to Vector DB manager.
        
        Args:
            vector_db_type: Type of vector database ('chroma' or 'faiss')
            embedding_method: Method for generating embeddings
            db_path: Path to store database files
            collection_name: Name of the collection/index
        """
        self.vector_db_type = vector_db_type
        self.embedding_method = embedding_method
        
        # Initialize embedding generator
        self.embedding_generator = EmbeddingGenerator(method=embedding_method)
        
        # Initialize vector database
        if vector_db_type == "chroma":
            db_path = db_path or "./chroma_db"
            self.vector_db = ChromaVectorDB(db_path=db_path, collection_name=collection_name)
        elif vector_db_type == "faiss":
            db_path = db_path or "./faiss_db"
            # Determine embedding dimension based on method
            dimension = 384 if embedding_method == "sentence_transformers" else 768
            self.vector_db = FAISSVectorDB(db_path=db_path, dimension=dimension)
        else:
            raise VectorDBError(f"Unsupported vector database type: {vector_db_type}")
        
        logger.info(f"Initialized PDFVectorDBManager with {vector_db_type} and {embedding_method}")
    
    def add_pdf_to_db(self, pdf_path: Union[str, Path], 
                     chunk_size: int = 1000, chunk_overlap: int = 200,
                     organization: str = None,
                     document_type: str = None,
                     document_category: str = None,
                     year: str = None,
                     language: str = None,
                     tags: List[str] = None,
                     custom_metadata: Dict = None):
        """
        Parse a PDF and add it to the vector database with rich metadata.
        
        Args:
            pdf_path: Path to the PDF file
            chunk_size: Size of text chunks
            chunk_overlap: Overlap between chunks
            organization: Name of the organization that published the document
            document_type: Type of document (e.g., 'annual_report', 'research_paper')
            document_category: Category of the document (e.g., 'agriculture', 'livestock')
            year: Publication year of the document
            language: Language of the document
            tags: List of tags/keywords for the document
            custom_metadata: Additional custom metadata
        """
        logger.info(f"Processing PDF: {pdf_path}")
        
        # Parse PDF into chunks with enhanced metadata
        chunks = parse_pdf(
            pdf_path=pdf_path, 
            chunk_size=chunk_size, 
            chunk_overlap=chunk_overlap,
            organization=organization,
            document_type=document_type,
            document_category=document_category,
            year=year,
            language=language,
            tags=tags,
            custom_metadata=custom_metadata
        )
        
        if not chunks:
            logger.warning(f"No chunks extracted from PDF: {pdf_path}")
            return
        
        # Extract text for embedding generation
        texts = [chunk['text'] for chunk in chunks]
        
        # Generate embeddings
        logger.info(f"Generating embeddings for {len(texts)} chunks")
        embeddings = self.embedding_generator.generate_embeddings(texts)
        
        # Add to vector database
        self.vector_db.add_documents(chunks, embeddings)
        
        logger.info(f"Successfully added PDF to vector database: {pdf_path}")
    
    def add_pdf_directory_to_db(self, directory_path: Union[str, Path], 
                               chunk_size: int = 1000, chunk_overlap: int = 200):
        """
        Parse all PDFs in a directory and add them to the vector database.
        
        Args:
            directory_path: Path to directory containing PDFs
            chunk_size: Size of text chunks
            chunk_overlap: Overlap between chunks
        """
        logger.info(f"Processing PDF directory: {directory_path}")
        
        # Parse all PDFs in directory
        pdf_chunks = parse_pdfs_from_directory(directory_path, chunk_size=chunk_size, chunk_overlap=chunk_overlap)
        
        if not pdf_chunks:
            logger.warning(f"No PDFs found or processed in directory: {directory_path}")
            return
        
        # Process each PDF's chunks
        total_chunks = 0
        for pdf_path, chunks in pdf_chunks.items():
            if chunks:
                texts = [chunk['text'] for chunk in chunks]
                embeddings = self.embedding_generator.generate_embeddings(texts)
                self.vector_db.add_documents(chunks, embeddings)
                total_chunks += len(chunks)
                logger.info(f"Added {len(chunks)} chunks from {pdf_path}")
        
        logger.info(f"Successfully processed {len(pdf_chunks)} PDFs with {total_chunks} total chunks")
    
    def search_documents(self, query: str, n_results: int = 5, 
                        organization: str = None,
                        document_type: str = None,
                        document_category: str = None,
                        year: str = None,
                        language: str = None) -> Dict:
        """
        Search for documents similar to the query with optional metadata filtering.
        
        Args:
            query: Search query text
            n_results: Number of results to return
            organization: Filter by organization name
            document_type: Filter by document type
            document_category: Filter by document category
            year: Filter by publication year
            language: Filter by language
            
        Returns:
            Search results with metadata
        """
        # Generate embedding for query
        query_embedding = self.embedding_generator.generate_embeddings([query])[0]
        
        # Build metadata filter for ChromaDB
        where_filter = {}
        if organization:
            where_filter['organization'] = organization
        if document_type:
            where_filter['document_type'] = document_type
        if document_category:
            where_filter['document_category'] = document_category
        if year:
            where_filter['publication_year'] = str(year)
        if language:
            where_filter['language'] = language
        
        # Search in vector database
        if self.vector_db_type == "chroma" and where_filter:
            results = self.vector_db.search(query_embedding, n_results=n_results, where_filter=where_filter)
        else:
            # For FAISS or when no filter is needed
            results = self.vector_db.search(query_embedding, n_results=n_results)
            
            # Apply post-filtering for FAISS if filters are specified
            if self.vector_db_type == "faiss" and where_filter:
                results = self._apply_post_filter(results, where_filter)
        
        return results
    
    def _apply_post_filter(self, results: Dict, where_filter: Dict) -> Dict:
        """
        Apply metadata filtering to FAISS search results.
        """
        filtered_docs = []
        filtered_metadatas = []
        filtered_distances = []
        
        documents = results.get('documents', [])
        metadatas = results.get('metadatas', [])
        distances = results.get('distances', [])
        
        for i, metadata in enumerate(metadatas):
            match = True
            for key, value in where_filter.items():
                if str(metadata.get(key, '')).lower() != str(value).lower():
                    match = False
                    break
            
            if match:
                if i < len(documents):
                    filtered_docs.append(documents[i])
                filtered_metadatas.append(metadata)
                if i < len(distances):
                    filtered_distances.append(distances[i])
        
        return {
            'documents': filtered_docs,
            'metadatas': filtered_metadatas,
            'distances': filtered_distances
        }
    
    def search_by_organization(self, query: str, organization: str, n_results: int = 5) -> Dict:
        """
        Search for documents from a specific organization.
        """
        return self.search_documents(query, n_results=n_results, organization=organization)
    
    def search_by_document_type(self, query: str, document_type: str, n_results: int = 5) -> Dict:
        """
        Search for documents of a specific type.
        """
        return self.search_documents(query, n_results=n_results, document_type=document_type)
    
    def get_organizations(self) -> List[str]:
        """
        Get list of all organizations in the database.
        """
        if self.vector_db_type == "chroma":
            # For ChromaDB, we'd need to query all documents to get unique organizations
            # This is a simplified approach - in production, you might want to maintain a separate index
            try:
                all_results = self.vector_db.collection.get()
                organizations = set()
                for metadata in all_results.get('metadatas', []):
                    org = metadata.get('organization', 'Unknown')
                    if org != 'Unknown':
                        organizations.add(org)
                return sorted(list(organizations))
            except:
                return []
        elif self.vector_db_type == "faiss":
            organizations = set()
            for metadata in self.vector_db.metadata:
                org = metadata.get('organization', 'Unknown')
                if org != 'Unknown':
                    organizations.add(org)
            return sorted(list(organizations))
        return []


# Convenience functions
def add_pdf_to_vector_db(pdf_path: Union[str, Path], 
                        vector_db_type: str = "chroma",
                        embedding_method: str = "sentence_transformers",
                        db_path: str = None):
    """
    Convenience function to add a single PDF to vector database.
    
    Args:
        pdf_path: Path to PDF file
        vector_db_type: Type of vector database
        embedding_method: Method for generating embeddings
        db_path: Path to store database files
    """
    manager = PDFVectorDBManager(
        vector_db_type=vector_db_type,
        embedding_method=embedding_method,
        db_path=db_path
    )
    manager.add_pdf_to_db(pdf_path)


def add_pdf_directory_to_vector_db(directory_path: Union[str, Path],
                                  vector_db_type: str = "chroma",
                                  embedding_method: str = "sentence_transformers",
                                  db_path: str = None):
    """
    Convenience function to add all PDFs in a directory to vector database.
    
    Args:
        directory_path: Path to directory containing PDFs
        vector_db_type: Type of vector database
        embedding_method: Method for generating embeddings
        db_path: Path to store database files
    """
    manager = PDFVectorDBManager(
        vector_db_type=vector_db_type,
        embedding_method=embedding_method,
        db_path=db_path
    )
    manager.add_pdf_directory_to_db(directory_path)


# Example usage and testing
if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Add PDFs to Vector Database")
    parser.add_argument("--pdf", type=str, help="Path to single PDF file")
    parser.add_argument("--directory", type=str, help="Path to directory containing PDFs")
    parser.add_argument("--db-type", type=str, choices=["chroma", "faiss"], default="chroma",
                       help="Vector database type")
    parser.add_argument("--embedding", type=str, choices=["sentence_transformers", "gemini"], 
                       default="sentence_transformers", help="Embedding method")
    parser.add_argument("--db-path", type=str, help="Path to store database files")
    parser.add_argument("--search", type=str, help="Search query to test")
    
    args = parser.parse_args()
    
    try:
        # Initialize manager
        manager = PDFVectorDBManager(
            vector_db_type=args.db_type,
            embedding_method=args.embedding,
            db_path=args.db_path
        )
        
        # Add PDFs to database
        if args.pdf:
            manager.add_pdf_to_db(args.pdf)
        elif args.directory:
            manager.add_pdf_directory_to_db(args.directory)
        else:
            print("Please provide either --pdf or --directory argument")
            exit(1)
        
        # Test search if query provided
        if args.search:
            print(f"\nSearching for: {args.search}")
            results = manager.search_documents(args.search, n_results=3)
            
            print(f"Found {len(results.get('documents', []))} results:")
            for i, (doc, metadata) in enumerate(zip(results.get('documents', []), 
                                                   results.get('metadatas', []))):
                print(f"\nResult {i+1}:")
                print(f"Source: {metadata.get('source_file', 'Unknown')}")
                print(f"Text: {doc[:200]}...")
        
        print("\nPDF processing completed successfully!")
        
    except Exception as e:
        logger.error(f"Error: {e}")
        print(f"\nError: {e}")
        print("\nTo install required dependencies:")
        print("pip install chromadb sentence-transformers")
        print("# OR for FAISS:")
        print("pip install faiss-cpu sentence-transformers")
