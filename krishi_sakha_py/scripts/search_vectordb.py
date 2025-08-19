#!/usr/bin/env python3
"""
Simple script to search existing ChromaDB vector database.

This script provides an easy way to search the existing vector database
without adding new documents.

Usage Examples:
    # Basic search
    python scripts/search_vectordb.py --search "wheat production"
    
    # Search with organization filter
    python scripts/search_vectordb.py --search "agriculture policy" --organization "FAO"
    
    # Search with multiple filters
    python scripts/search_vectordb.py --search "crop yields" --organization "WHO" --year "2023" --results 5
    
    # Backend is fixed to ChromaDB with sentence-transformers embeddings.
"""

import sys
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
        description="Search existing ChromaDB vector database",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    
    # Search options
    parser.add_argument("--search", type=str, required=True,
                       help="Search query")
    parser.add_argument("--results", type=int, default=5,
                       help="Number of search results to show (default: 5)")
    
    # Database configuration (fixed to ChromaDB + sentence-transformers)
    parser.add_argument("--db-path", type=str, help="Custom path to database files")
    parser.add_argument("--collection", type=str, default="krishi_sakha_docs",
                       help="Collection/index name (default: krishi_sakha_docs)")
    
    # Search filters
    parser.add_argument("--organization", type=str,
                       help="Filter by organization")
    parser.add_argument("--document-type", type=str,
                       help="Filter by document type")
    parser.add_argument("--category", type=str,
                       help="Filter by document category")
    parser.add_argument("--year", type=str,
                       help="Filter by publication year")
    parser.add_argument("--language", type=str,
                       help="Filter by language")
    
    # Utility options
    parser.add_argument("--verbose", "-v", action="store_true", help="Enable verbose logging")
    parser.add_argument("--list-organizations", action="store_true", 
                       help="List all organizations in the database")
    
    args = parser.parse_args()
    
    # Configure logging level
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    try:
        logger.info("=== Krishi Sakha Vector DB Search (Chroma + sentence-transformers) ===")
        logger.info(f"Collection Name: {args.collection}")
        
        # Initialize manager
        logger.info("Initializing PDF Vector DB Manager...")
        manager = PDFVectorDBManager(
            db_path=args.db_path,
            collection_name=args.collection
        )
        
        # List organizations if requested
        if args.list_organizations:
            logger.info("Retrieving organizations from database...")
            organizations = manager.get_organizations()
            print(f"\n=== Organizations in Database ===")
            if organizations:
                for i, org in enumerate(organizations, 1):
                    print(f"{i}. {org}")
            else:
                print("No organizations found in database.")
            print()
        
        # Perform search
        logger.info(f"Searching for: '{args.search}'")
        
        # Build search parameters
        search_kwargs = {
            'query': args.search,
            'n_results': args.results
        }
        
        if args.organization:
            search_kwargs['organization'] = args.organization
        if args.document_type:
            search_kwargs['document_type'] = args.document_type
        if args.category:
            search_kwargs['document_category'] = args.category
        if args.year:
            search_kwargs['year'] = args.year
        if args.language:
            search_kwargs['language'] = args.language
        
        results = manager.search_documents(**search_kwargs)
        
        # Display results
        print(f"\n=== Search Results for: '{args.search}' ===")
        
        # Show applied filters
        filters_applied = []
        if args.organization:
            filters_applied.append(f"Organization: {args.organization}")
        if args.document_type:
            filters_applied.append(f"Type: {args.document_type}")
        if args.category:
            filters_applied.append(f"Category: {args.category}")
        if args.year:
            filters_applied.append(f"Year: {args.year}")
        if args.language:
            filters_applied.append(f"Language: {args.language}")
        
        if filters_applied:
            print(f"Filters applied: {', '.join(filters_applied)}")
        
        # ChromaDB returns results in a nested list format
        documents = results.get('documents', [[]])[0] if results.get('documents') else []
        metadatas = results.get('metadatas', [[]])[0] if results.get('metadatas') else []
        distances = results.get('distances', [[]])[0] if results.get('distances') else []
        
        if not documents:
            print("No results found.")
        else:
            print(f"Found {len(documents)} results:")
            
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
        
        logger.info("✅ Search completed successfully!")
        return 0
        
    except KeyboardInterrupt:
        logger.info("Search interrupted by user")
        return 1
    except Exception as e:
        logger.error(f"Error during search: {e}")
        if args.verbose:
            import traceback
            traceback.print_exc()
        
        # Provide helpful error messages
        if "chromadb" in str(e).lower():
            print("\n💡 Install ChromaDB: pip install chromadb")
        elif "sentence_transformers" in str(e).lower():
            print("\n💡 Install Sentence Transformers: pip install sentence-transformers")
        elif "collection" in str(e).lower():
            print("\n💡 No existing collection found. Add some documents first.")
        
        return 1


if __name__ == "__main__":
    exit(main())
