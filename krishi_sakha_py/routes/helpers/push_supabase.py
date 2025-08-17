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
        if 'created_at' not in data:
            data['created_at'] = datetime.now().isoformat()

        result = supabase.table(table_name).insert([data]).execute()

        if result.data and not result.error:
            logger.info(f"Successfully inserted data into {table_name}")
            return True
        else:
            logger.error(f"Failed to insert data: {result.error}")
            return False

    except Exception as e:
        logger.error(f"Error inserting data into {table_name}: {e}")
        return False
