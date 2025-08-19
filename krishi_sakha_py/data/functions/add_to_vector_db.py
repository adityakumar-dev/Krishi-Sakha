import logging
import json
from typing import List, Dict, Optional, Union
from pathlib import Path
from datetime import datetime

# Vector database imports
try:
    import chromadb
    from chromadb.config import Settings
    CHROMADB_AVAILABLE = True
except ImportError:
    chromadb = None
    CHROMADB_AVAILABLE = False

try:
    from sentence_transformers import SentenceTransformer
    SENTENCE_TRANSFORMERS_AVAILABLE = True
except ImportError:
    SentenceTransformer = None
    SENTENCE_TRANSFORMERS_AVAILABLE = False

# Local imports
from data.functions.parse_pdf import parse_pdf, parse_pdfs_from_directory

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class VectorDBError(Exception):
    """Custom exception for vector database operations"""
    pass


class EmbeddingGenerator:
    
    def __init__(self, model_name: str = "all-MiniLM-L6-v2"):
        if not SENTENCE_TRANSFORMERS_AVAILABLE:
            raise VectorDBError("sentence-transformers not available. Install with: pip install sentence-transformers")
        
        self.model = SentenceTransformer(model_name)
        logger.info(f"Initialized SentenceTransformer with model: {model_name}")
    
    def generate_embeddings(self, texts: List[str]) -> List[List[float]]:
     
        embeddings = self.model.encode(texts, convert_to_tensor=False)
        return embeddings.tolist()


class ChromaVectorDB:
    
    def __init__(self, db_path: str = "../../chroma_db", collection_name: str = "pdf_documents"):
     
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



class PDFVectorDBManager:
    
    def __init__(self, 
                 vector_db_type: str = "chroma",
                 embedding_method: str = "sentence_transformers",
                 db_path: str = None,
                 collection_name: str = "krishi_sakha_docs"):
       
        if vector_db_type != "chroma":
            raise VectorDBError(f"Only ChromaDB is supported, got: {vector_db_type}")
        if embedding_method != "sentence_transformers":
            raise VectorDBError(f"Only sentence_transformers is supported, got: {embedding_method}")
            
        self.vector_db_type = vector_db_type
        self.embedding_method = embedding_method
        
        # Initialize embedding generator
        self.embedding_generator = EmbeddingGenerator()
        
        # Initialize ChromaDB
        db_path = db_path or "./chroma_db"
        self.vector_db = ChromaVectorDB(db_path=db_path, collection_name=collection_name)
        
        logger.info(f"Initialized PDFVectorDBManager with ChromaDB and sentence-transformers")
    
    def add_pdf_to_db(self, pdf_path: Union[str, Path], 
                     chunk_size: int = 1000, chunk_overlap: int = 200,
                     organization: str = None,
                     document_type: str = None,
                     document_category: str = None,
                     year: str = None,
                     language: str = None,
                     tags: List[str] = None,
                     custom_metadata: Dict = None):
      
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
        if where_filter:
            results = self.vector_db.search(query_embedding, n_results=n_results, where_filter=where_filter)
        else:
            results = self.vector_db.search(query_embedding, n_results=n_results)
            
        return results
    
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


# Convenience functions
def add_pdf_to_vector_db(pdf_path: Union[str, Path], 
                        db_path: str = None):
  
    manager = PDFVectorDBManager(db_path=db_path)
    manager.add_pdf_to_db(pdf_path)


def add_pdf_directory_to_vector_db(directory_path: Union[str, Path],
                                  db_path: str = None):

    manager = PDFVectorDBManager(db_path=db_path)
    manager.add_pdf_directory_to_db(directory_path)


# Example usage and testing
if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Add PDFs to Vector Database")
    parser.add_argument("--pdf", type=str, help="Path to single PDF file")
    parser.add_argument("--directory", type=str, help="Path to directory containing PDFs")
    parser.add_argument("--db-path", type=str, help="Path to store database files")
    parser.add_argument("--search", type=str, help="Search query to test")
    
    args = parser.parse_args()
    
    try:
        # Initialize manager
        manager = PDFVectorDBManager(db_path=args.db_path)
        
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