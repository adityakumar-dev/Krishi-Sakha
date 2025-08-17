#!/usr/bin/env python3
"""
Script to add PDF documents to vector database for the Krishi Sakha application.

This script provides an easy way to:
1. Add individual PDF files to the vector database
2. Add all PDFs from a directory to the vector database
3. Search the vector database for testing

Usage Examples:
    # Add a single PDF
    python scripts/add_pdfs_to_vectordb.py --pdf "path/to/document.pdf"
    
    # Add all PDFs from a directory
    python scripts/add_pdfs_to_vectordb.py --directory "path/to/pdf_directory"
    
    # Add PDFs and test search
    python scripts/add_pdfs_to_vectordb.py --directory "data/pdfs" --search "agriculture techniques"
    
    # Use different vector database backend
    python scripts/add_pdfs_to_vectordb.py --directory "data/pdfs" --db-type faiss
    
    # Use Gemini embeddings
    python scripts/add_pdfs_to_vectordb.py --directory "data/pdfs" --embedding gemini
"""

import sys
import os
from pathlib import Path

# Add the project root to Python path
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

import argparse
import logging
from data.functions.add_to_vector_db import PDFVectorDBManager

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def main():
    parser = argparse.ArgumentParser(
        description="Add PDF documents to vector database for Krishi Sakha",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    
    # Input options
    input_group = parser.add_mutually_exclusive_group(required=True)
    input_group.add_argument("--pdf", type=str, help="Path to single PDF file")
    input_group.add_argument("--directory", type=str, help="Path to directory containing PDFs")
    input_group.add_argument("--search-only", action="store_true", help="Search existing database without adding new documents")
    
    # Database configuration
    parser.add_argument("--db-type", type=str, choices=["chroma", "faiss"], default="chroma",
                       help="Vector database type (default: chroma)")
    parser.add_argument("--embedding", type=str, choices=["sentence_transformers", "gemini"], 
                       default="sentence_transformers", help="Embedding method (default: sentence_transformers)")
    parser.add_argument("--db-path", type=str, help="Custom path to store database files")
    parser.add_argument("--collection", type=str, default="krishi_sakha_docs",
                       help="Collection/index name (default: krishi_sakha_docs)")
    
    # Text processing options
    parser.add_argument("--chunk-size", type=int, default=1000,
                       help="Text chunk size (default: 1000)")
    parser.add_argument("--chunk-overlap", type=int, default=200,
                       help="Text chunk overlap (default: 200)")
    
    # Metadata options
    parser.add_argument("--organization", type=str,
                       help="Organization that published the document(s)")
    parser.add_argument("--document-type", type=str,
                       help="Type of document (e.g., annual_report, research_paper, policy_document)")
    parser.add_argument("--document-category", type=str,
                       help="Category of document (e.g., agriculture, livestock, fisheries)")
    parser.add_argument("--year", type=str,
                       help="Publication year of the document")
    parser.add_argument("--language", type=str,
                       help="Language of the document (e.g., english, hindi)")
    parser.add_argument("--tags", type=str, nargs="*",
                       help="Tags/keywords for the document (space-separated)")
    
    # Testing and search options
    parser.add_argument("--search", type=str, help="Search query (required for --search-only mode)")
    parser.add_argument("--search-results", type=int, default=3,
                       help="Number of search results to show (default: 3)")
    parser.add_argument("--filter-organization", type=str,
                       help="Filter search results by organization")
    parser.add_argument("--filter-document-type", type=str,
                       help="Filter search results by document type")
    parser.add_argument("--filter-category", type=str,
                       help="Filter search results by document category")
    parser.add_argument("--filter-year", type=str,
                       help="Filter search results by publication year")
    parser.add_argument("--filter-language", type=str,
                       help="Filter search results by language")
    
    # Utility options
    parser.add_argument("--verbose", "-v", action="store_true", help="Enable verbose logging")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be done without actually doing it")
    
    args = parser.parse_args()
    
    # Configure logging level
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    try:
        # Validate input paths (skip validation for search-only mode)
        if not args.search_only:
            if args.pdf:
                pdf_path = Path(args.pdf)
                if not pdf_path.exists():
                    logger.error(f"PDF file not found: {pdf_path}")
                    return 1
                if not pdf_path.suffix.lower() == '.pdf':
                    logger.error(f"File is not a PDF: {pdf_path}")
                    return 1
            
            if args.directory:
                dir_path = Path(args.directory)
                if not dir_path.exists():
                    logger.error(f"Directory not found: {dir_path}")
                    return 1
                if not dir_path.is_dir():
                    logger.error(f"Path is not a directory: {dir_path}")
                    return 1
        
        # Show configuration
        logger.info("=== Krishi Sakha PDF to Vector DB ===")
        logger.info(f"Vector DB Type: {args.db_type}")
        logger.info(f"Embedding Method: {args.embedding}")
        logger.info(f"Collection Name: {args.collection}")
        logger.info(f"Chunk Size: {args.chunk_size}")
        logger.info(f"Chunk Overlap: {args.chunk_overlap}")
        
        if args.dry_run:
            logger.info("DRY RUN MODE - No actual processing will occur")
            if args.search_only:
                logger.info("Would search existing database")
            elif args.pdf:
                logger.info(f"Would process PDF: {args.pdf}")
            else:
                logger.info(f"Would process directory: {args.directory}")
            return 0
        
        # Initialize manager
        logger.info("Initializing PDF Vector DB Manager...")
        manager = PDFVectorDBManager(
            vector_db_type=args.db_type,
            embedding_method=args.embedding,
            db_path=args.db_path,
            collection_name=args.collection
        )
        
        # Process PDFs or search existing database
        if args.search_only:
            logger.info("Search-only mode: Skipping PDF processing")
        elif args.pdf:
            logger.info(f"Processing single PDF: {args.pdf}")
            manager.add_pdf_to_db(
                pdf_path=args.pdf,
                chunk_size=args.chunk_size,
                chunk_overlap=args.chunk_overlap,
                organization=args.organization,
                document_type=args.document_type,
                document_category=args.document_category,
                year=args.year,
                language=args.language,
                tags=args.tags
            )
        else:
            logger.info(f"Processing PDF directory: {args.directory}")
            # For directory processing, we'll apply the same metadata to all PDFs
            # In a real scenario, you might want to read metadata from a CSV file or similar
            manager.add_pdf_directory_to_db(
                directory_path=args.directory,
                chunk_size=args.chunk_size,
                chunk_overlap=args.chunk_overlap,
                organization=args.organization,
                document_type=args.document_type,
                document_category=args.document_category,
                year=args.year,
                language=args.language,
                tags=args.tags
            )


        
        # Validate search requirements for search-only mode
        if args.search_only and not args.search:
            logger.error("--search query is required when using --search-only mode")
            return 1
        
        # Test search if requested
        if args.search:
            logger.info(f"Testing search with query: '{args.search}'")
            
            # Apply search filters if specified
            search_kwargs = {
                'query': args.search,
                'n_results': args.search_results
            }
            
            if args.filter_organization:
                search_kwargs['organization'] = args.filter_organization
            if args.filter_document_type:
                search_kwargs['document_type'] = args.filter_document_type
            if args.filter_category:
                search_kwargs['document_category'] = args.filter_category
            if args.filter_year:
                search_kwargs['year'] = args.filter_year
            if args.filter_language:
                search_kwargs['language'] = args.filter_language
            
            results = manager.search_documents(**search_kwargs)
            
            # Display applied filters
            filters_applied = []
            if args.filter_organization:
                filters_applied.append(f"Organization: {args.filter_organization}")
            if args.filter_document_type:
                filters_applied.append(f"Type: {args.filter_document_type}")
            if args.filter_category:
                filters_applied.append(f"Category: {args.filter_category}")
            if args.filter_year:
                filters_applied.append(f"Year: {args.filter_year}")
            if args.filter_language:
                filters_applied.append(f"Language: {args.filter_language}")
            
            print(f"\n=== Search Results for: '{args.search}' ===")
            if filters_applied:
                print(f"Filters applied: {', '.join(filters_applied)}")
            
            # ChromaDB returns results in a nested list format
            documents = results.get('documents', [[]])[0] if results.get('documents') else []
            metadatas = results.get('metadatas', [[]])[0] if results.get('metadatas') else []
            distances = results.get('distances', [[]])[0] if results.get('distances') else []
            
            if not documents:
                print("No results found.")
            else:
                for i, doc in enumerate(documents):
                    metadata = metadatas[i] if i < len(metadatas) else {}
                    print(f"\n--- Result {i+1} ---")
                    print(f"Source: {metadata.get('source_file', 'Unknown')}")
                    print(f"Organization: {metadata.get('organization', 'Unknown')}")
                    print(f"Document Type: {metadata.get('document_type', 'Unknown')}")
                    print(f"Category: {metadata.get('document_category', 'Unknown')}")
                    print(f"Year: {metadata.get('publication_year', 'Unknown')}")
                    print(f"Language: {metadata.get('language', 'Unknown')}")
                    print(f"Tags: {metadata.get('tags', 'None')}")
                    print(f"Page Count: {metadata.get('total_pages', 'Unknown')}")
                    if distances and i < len(distances):
                        print(f"Similarity Score: {distances[i]:.4f}")
                    print(f"Text Preview: {doc[:300]}...")
                    print("-" * 50)
        
        logger.info("✅ PDF processing completed successfully!")
        return 0
        
    except KeyboardInterrupt:
        logger.info("Process interrupted by user")
        return 1
    except Exception as e:
        logger.error(f"Error during processing: {e}")
        if args.verbose:
            import traceback
            traceback.print_exc()
        
        # Provide helpful error messages
        if "chromadb" in str(e).lower():
            print("\n💡 Install ChromaDB: pip install chromadb")
        elif "sentence_transformers" in str(e).lower():
            print("\n💡 Install Sentence Transformers: pip install sentence-transformers")
        elif "faiss" in str(e).lower():
            print("\n💡 Install FAISS: pip install faiss-cpu")
        elif "gemini" in str(e).lower():
            print("\n💡 Check your Gemini API key configuration")
        
        return 1


if __name__ == "__main__":
    exit(main())
