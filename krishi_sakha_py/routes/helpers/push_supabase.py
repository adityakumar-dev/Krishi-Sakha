import logging
from typing import Dict, Any
from datetime import datetime
from configs.supabase_key import SUPABASE

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

supabase = SUPABASE

def push_to_supabase(table_name: str, data: Dict[str, Any]) -> bool:
    if not supabase:
        logger.error("Supabase client not initialized")
        return False

    try:
        

        result = supabase.table(table_name).insert([data]).execute()

        print(result)
        logger.info(f"Successfully inserted data into {table_name}")

    except Exception as e:
        logger.error(f"Error inserting data into {table_name}: {e}")
        return False
