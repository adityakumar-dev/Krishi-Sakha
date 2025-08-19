from data.functions.add_to_vector_db import PDFVectorDBManager

manager = PDFVectorDBManager(
    db_path="./chroma_db",
    collection_name="annual_report"
)

results = manager.search_documents(
    query="",          # empty query
    n_results=10,
    year="2023"
)

# NOTE: Chroma returns nested lists → use index [0]
docs  = results.get("documents", [[]])[0]
metas = results.get("metadatas", [[]])[0]

print("Found", len(docs), "chunks with year=2023")

for doc, meta in zip(docs, metas):
    print(f"- YEAR: {meta.get('publication_year')} | PREVIEW: {doc[:120]}")


# get all chunks
all_chunks = manager.search_documents("fertilizer", year=None)
# get only 2024 chunks
chunks_2024 = manager.search_documents("fertilizer", year="2024")
# get only 2023 chunks
chunks_2023 = manager.search_documents("fertilizer", year="2023")

print("Found", len(all_chunks), "chunks with year=None")
