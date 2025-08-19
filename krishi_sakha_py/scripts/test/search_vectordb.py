# quick test in Python console / separate script
from data.functions.add_to_vector_db import PDFVectorDBManager
manager = PDFVectorDBManager(
    db_path="/home/linmar/Desktop/Krishi-Sakha/krishi_sakha_py/chroma_db",
    collection_name="annual_report"
)

results_all = manager.search_documents("annual report")
results_24  = manager.search_documents("annual report", year="2024")

# print("---- ALL YEARS ----")
for doc in results_all["documents"]:
    print(doc[:120])
print("---- ONLY 2024 ----")
for doc in results_24["documents"]:
    print(doc[:120])
    # results_24 = manager.search_documents("fertilizer usage", n_results=20, year="2024")

# results_24 = manager.search_documents("fertilizer usage", n_results=20, year="2024")

