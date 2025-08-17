import os
import logging
from typing import List, Dict, Optional, Union
from pathlib import Path
import hashlib
from datetime import datetime

try:
    import PyPDF2
except ImportError:
    PyPDF2 = None

try:
    import pdfplumber
except ImportError:
    pdfplumber = None

try:
    from langchain.text_splitter import RecursiveCharacterTextSplitter
    from langchain.schema import Document
except ImportError:
    RecursiveCharacterTextSplitter = None
    Document = None

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class PDFParseError(Exception):
    """Custom exception for PDF parsing errors"""
    pass

class PDFParser:
    """
    A comprehensive PDF parser for extracting text and preparing data for vector database integration.
    
    This class provides methods to:
    - Extract text from PDF files using multiple backends
    - Chunk text into manageable pieces for vector storage
    - Generate metadata for each document chunk
    - Handle various PDF formats and edge cases
    """
    
    def __init__(self, 
                 chunk_size: int = 1000, 
                 chunk_overlap: int = 200,
                 min_chunk_size: int = 100):
        """
        Initialize the PDF parser.
        
        Args:
            chunk_size: Maximum size of each text chunk
            chunk_overlap: Number of characters to overlap between chunks
            min_chunk_size: Minimum size for a chunk to be considered valid
        """
        self.chunk_size = chunk_size
        self.chunk_overlap = chunk_overlap
        self.min_chunk_size = min_chunk_size
        
        # Initialize text splitter if available
        if RecursiveCharacterTextSplitter:
            self.text_splitter = RecursiveCharacterTextSplitter(
                chunk_size=self.chunk_size,
                chunk_overlap=self.chunk_overlap,
                length_function=len,
                separators=["\n\n", "\n", ". ", " ", ""]
            )
        else:
            self.text_splitter = None
            logger.warning("LangChain not available. Using basic text splitting.")
    
    def _check_dependencies(self) -> str:
        """
        Check which PDF parsing library is available.
        
        Returns:
            str: The name of the available library ('pdfplumber', 'pypdf2', or 'none')
        """
        if pdfplumber:
            return 'pdfplumber'
        elif PyPDF2:
            return 'pypdf2'
        else:
            return 'none'
    
    def _extract_text_pdfplumber(self, pdf_path: str) -> tuple[str, Dict]:
        """
        Extract text using pdfplumber (preferred method).
        
        Args:
            pdf_path: Path to the PDF file
            
        Returns:
            tuple: (extracted_text, metadata)
        """
        text = ""
        metadata = {
            'total_pages': 0,
            'extraction_method': 'pdfplumber'
        }
        
        with pdfplumber.open(pdf_path) as pdf:
            metadata['total_pages'] = len(pdf.pages)
            
            for page_num, page in enumerate(pdf.pages, 1):
                try:
                    page_text = page.extract_text()
                    if page_text:
                        text += f"\n\n--- Page {page_num} ---\n\n{page_text}"
                except Exception as e:
                    logger.warning(f"Failed to extract text from page {page_num}: {e}")
                    continue
        
        return text.strip(), metadata
    
    def _extract_text_pypdf2(self, pdf_path: str) -> tuple[str, Dict]:
        """
        Extract text using PyPDF2 (fallback method).
        
        Args:
            pdf_path: Path to the PDF file
            
        Returns:
            tuple: (extracted_text, metadata)
        """
        text = ""
        metadata = {
            'total_pages': 0,
            'extraction_method': 'pypdf2'
        }
        
        with open(pdf_path, 'rb') as file:
            pdf_reader = PyPDF2.PdfReader(file)
            metadata['total_pages'] = len(pdf_reader.pages)
            
            for page_num, page in enumerate(pdf_reader.pages, 1):
                try:
                    page_text = page.extract_text()
                    if page_text:
                        text += f"\n\n--- Page {page_num} ---\n\n{page_text}"
                except Exception as e:
                    logger.warning(f"Failed to extract text from page {page_num}: {e}")
                    continue
        
        return text.strip(), metadata
    
    def extract_text_from_pdf(self, pdf_path: Union[str, Path]) -> tuple[str, Dict]:
        """
        Extract text from a PDF file using the best available method.
        
        Args:
            pdf_path: Path to the PDF file
            
        Returns:
            tuple: (extracted_text, metadata)
            
        Raises:
            PDFParseError: If the PDF cannot be parsed
            FileNotFoundError: If the PDF file doesn't exist
        """
        pdf_path = str(pdf_path)
        
        if not os.path.exists(pdf_path):
            raise FileNotFoundError(f"PDF file not found: {pdf_path}")
        
        if not pdf_path.lower().endswith('.pdf'):
            raise PDFParseError(f"File is not a PDF: {pdf_path}")
        
        # Check available libraries
        library = self._check_dependencies()
        
        if library == 'none':
            raise PDFParseError(
                "No PDF parsing library available. Please install 'pdfplumber' or 'PyPDF2':\n"
                "pip install pdfplumber\n"
                "or\n"
                "pip install PyPDF2"
            )
        
        try:
            if library == 'pdfplumber':
                text, metadata = self._extract_text_pdfplumber(pdf_path)
            else:  # pypdf2
                text, metadata = self._extract_text_pypdf2(pdf_path)
            
            if not text.strip():
                raise PDFParseError(f"No text could be extracted from PDF: {pdf_path}")
            
            # Add file metadata
            file_stats = os.stat(pdf_path)
            metadata.update({
                'file_path': pdf_path,
                'file_name': os.path.basename(pdf_path),
                'file_size': file_stats.st_size,
                'modified_time': datetime.fromtimestamp(file_stats.st_mtime).isoformat(),
                'text_length': len(text),
                'file_hash': self._generate_file_hash(pdf_path)
            })
            
            return text, metadata
            
        except Exception as e:
            raise PDFParseError(f"Failed to extract text from PDF {pdf_path}: {e}")
    
    def _generate_file_hash(self, file_path: str) -> str:
        """
        Generate a hash for the PDF file to detect changes.
        
        Args:
            file_path: Path to the file
            
        Returns:
            str: MD5 hash of the file
        """
        hash_md5 = hashlib.md5()
        with open(file_path, "rb") as f:
            for chunk in iter(lambda: f.read(4096), b""):
                hash_md5.update(chunk)
        return hash_md5.hexdigest()
    
    def _basic_text_split(self, text: str) -> List[str]:
        """
        Basic text splitting when LangChain is not available.
        
        Args:
            text: Text to split
            
        Returns:
            List[str]: List of text chunks
        """
        chunks = []
        start = 0
        
        while start < len(text):
            end = start + self.chunk_size
            
            # If we're not at the end, try to break at a sentence or word boundary
            if end < len(text):
                # Look for sentence boundary
                sentence_end = text.rfind('. ', start, end)
                if sentence_end > start:
                    end = sentence_end + 1
                else:
                    # Look for word boundary
                    word_end = text.rfind(' ', start, end)
                    if word_end > start:
                        end = word_end
            
            chunk = text[start:end].strip()
            if len(chunk) >= self.min_chunk_size:
                chunks.append(chunk)
            
            # Move start position with overlap
            start = max(start + 1, end - self.chunk_overlap)
        
        return chunks
    
    def chunk_text(self, text: str, metadata: Dict = None) -> List[Dict]:
        """
        Split text into chunks suitable for vector database storage.
        
        Args:
            text: Text to chunk
            metadata: Optional metadata to include with each chunk
            
        Returns:
            List[Dict]: List of chunk dictionaries with text and metadata
        """
        if not text.strip():
            return []
        
        metadata = metadata or {}
        
        # Split text into chunks
        if self.text_splitter:
            # Use LangChain's text splitter if available
            if Document:
                doc = Document(page_content=text, metadata=metadata)
                chunks = self.text_splitter.split_documents([doc])
                chunk_texts = [chunk.page_content for chunk in chunks]
            else:
                chunk_texts = self.text_splitter.split_text(text)
        else:
            # Use basic text splitting
            chunk_texts = self._basic_text_split(text)
        
        # Create chunk dictionaries with metadata
        chunked_data = []
        for i, chunk_text in enumerate(chunk_texts):
            if len(chunk_text.strip()) >= self.min_chunk_size:
                chunk_metadata = metadata.copy()
                chunk_metadata.update({
                    'chunk_index': i,
                    'chunk_size': len(chunk_text),
                    'total_chunks': len(chunk_texts),
                    'created_at': datetime.now().isoformat()
                })
                
                chunked_data.append({
                    'text': chunk_text.strip(),
                    'metadata': chunk_metadata
                })
        
        return chunked_data
    
    def parse_pdf_for_vector_db(self, pdf_path: Union[str, Path], 
                               organization: str = None,
                               document_type: str = None,
                               document_category: str = None,
                               year: str = None,
                               language: str = None,
                               tags: List[str] = None,
                               custom_metadata: Dict = None) -> List[Dict]:
        """
        Complete pipeline to parse a PDF and prepare it for vector database insertion.
        
        Args:
            pdf_path: Path to the PDF file
            organization: Name of the organization that published the document
            document_type: Type of document (e.g., 'annual_report', 'research_paper', 'policy_document')
            document_category: Category of the document (e.g., 'agriculture', 'livestock', 'fisheries')
            year: Publication year of the document
            language: Language of the document (e.g., 'english', 'hindi')
            tags: List of tags/keywords for the document
            custom_metadata: Additional custom metadata as key-value pairs
            
        Returns:
            List[Dict]: List of chunks ready for vector database insertion
            
        Raises:
            PDFParseError: If parsing fails
        """
        logger.info(f"Starting PDF parsing for: {pdf_path}")
        
        # Extract text from PDF
        text, base_metadata = self.extract_text_from_pdf(pdf_path)
        logger.info(f"Extracted {len(text)} characters from PDF")
        
        # Enhance metadata with additional information
        enhanced_metadata = base_metadata.copy()
        enhanced_metadata.update({
            'organization': organization or 'Unknown',
            'document_type': document_type or 'Unknown',
            'document_category': document_category or 'General',
            'publication_year': year or 'Unknown',
            'language': language or 'Unknown',
            'tags': tags or [],
            'document_title': Path(pdf_path).stem,  # Use filename as title
            'file_size_bytes': os.path.getsize(pdf_path) if os.path.exists(pdf_path) else 0,
        })
        
        # Add custom metadata if provided
        if custom_metadata:
            enhanced_metadata.update(custom_metadata)
        
        # Chunk the text with enhanced metadata
        chunks = self.chunk_text(text, enhanced_metadata)
        logger.info(f"Created {len(chunks)} chunks from PDF with enhanced metadata")
        
        return chunks
    
    def parse_multiple_pdfs(self, pdf_paths: List[Union[str, Path]]) -> Dict[str, List[Dict]]:
        """
        Parse multiple PDF files.
        
        Args:
            pdf_paths: List of paths to PDF files
            
        Returns:
            Dict[str, List[Dict]]: Dictionary mapping file paths to their chunks
        """
        results = {}
        errors = {}
        
        for pdf_path in pdf_paths:
            try:
                chunks = self.parse_pdf_for_vector_db(pdf_path)
                results[str(pdf_path)] = chunks
                logger.info(f"Successfully parsed {pdf_path}: {len(chunks)} chunks")
            except Exception as e:
                errors[str(pdf_path)] = str(e)
                logger.error(f"Failed to parse {pdf_path}: {e}")
        
        if errors:
            logger.warning(f"Failed to parse {len(errors)} files: {list(errors.keys())}")
        
        return results

# Convenience functions for easy usage
def parse_pdf(pdf_path: Union[str, Path], 
              chunk_size: int = 1000, 
              chunk_overlap: int = 200,
              organization: str = None,
              document_type: str = None,
              document_category: str = None,
              year: str = None,
              language: str = None,
              tags: List[str] = None,
              custom_metadata: Dict = None) -> List[Dict]:
    """
    Convenience function to parse a single PDF file.
    
    Args:
        pdf_path: Path to the PDF file
        chunk_size: Maximum size of each text chunk
        chunk_overlap: Number of characters to overlap between chunks
        organization: Name of the organization that published the document
        document_type: Type of document (e.g., 'annual_report', 'research_paper')
        document_category: Category of the document (e.g., 'agriculture', 'livestock')
        year: Publication year of the document
        language: Language of the document
        tags: List of tags/keywords for the document
        custom_metadata: Additional custom metadata
        
    Returns:
        List[Dict]: List of chunks ready for vector database insertion
    """
    parser = PDFParser(chunk_size=chunk_size, chunk_overlap=chunk_overlap)
    return parser.parse_pdf_for_vector_db(
        pdf_path=pdf_path,
        organization=organization,
        document_type=document_type,
        document_category=document_category,
        year=year,
        language=language,
        tags=tags,
        custom_metadata=custom_metadata
    )

def parse_pdfs_from_directory(directory_path: Union[str, Path], 
                             chunk_size: int = 1000, 
                             chunk_overlap: int = 200) -> Dict[str, List[Dict]]:
    """
    Parse all PDF files in a directory.
    
    Args:
        directory_path: Path to directory containing PDF files
        chunk_size: Maximum size of each text chunk
        chunk_overlap: Number of characters to overlap between chunks
        
    Returns:
        Dict[str, List[Dict]]: Dictionary mapping file paths to their chunks
    """
    directory_path = Path(directory_path)
    
    if not directory_path.exists():
        raise FileNotFoundError(f"Directory not found: {directory_path}")
    
    pdf_files = list(directory_path.glob("*.pdf"))
    
    if not pdf_files:
        logger.warning(f"No PDF files found in directory: {directory_path}")
        return {}
    
    parser = PDFParser(chunk_size=chunk_size, chunk_overlap=chunk_overlap)
    return parser.parse_multiple_pdfs(pdf_files)

# Example usage and testing
if __name__ == "__main__":
    # Example usage
    try:
        # Initialize parser
        parser = PDFParser(chunk_size=800, chunk_overlap=100)
        
        # Parse a single PDF (replace with actual path)
        # chunks = parser.parse_pdf_for_vector_db("example.pdf")
        # print(f"Parsed PDF into {len(chunks)} chunks")
        
        # Example of what the output looks like
        print("PDF Parser initialized successfully!")
        print(f"Available PDF library: {parser._check_dependencies()}")
        print("\nTo use this module:")
        print("1. parser = PDFParser()")
        print("2. chunks = parser.parse_pdf_for_vector_db('your_file.pdf')")
        print("3. Add chunks to your vector database")
        
    except Exception as e:
        print(f"Error: {e}")
        print("\nTo install required dependencies:")
        print("pip install pdfplumber langchain")