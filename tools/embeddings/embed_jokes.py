### For initial embedding of jokes database, not newly added jokes ###

import os
import time
from typing import List, Dict, Any, Optional

from dotenv import load_dotenv
from supabase import create_client, Client
from sentence_transformers import SentenceTransformer
from tqdm import tqdm

TABLE = 'jokes'
ID_COL = 'id'
TEXT_COL = 'text'
EMB_COL = 'embedding'

MODEL_NAME = 'BAAI/bge-small-en-v1.5'
BATCH_FETCH = 500
BATCH_EMBED = 64
MAX_ROWS: Optional[int] = 20000

def get_env(name: str) -> str:
    val = os.getenv(name)
    if not val:
        raise RuntimeError(f"Missing environment variable: {name}")
    return val

def chunked(lst: List[Any], n: int) -> List[List[Any]]:
    return [lst[i:i + n] for i in range(0, len(lst), n)]

def main():
    load_dotenv()  

    supabase_url = get_env("SUPABASE_URL")
    supabase_key = get_env("SUPABASE_SERVICE_ROLE_KEY")

    sb: Client = create_client(supabase_url, supabase_key)

    print(f"Loading embedding model: {MODEL_NAME}")
    model = SentenceTransformer(MODEL_NAME)

    normalize = True

    processed = 0
    page = 0

    print("Starting embedding backfill...")

    while True:
        if MAX_ROWS is not None and processed >= MAX_ROWS:
            print(f"Reached MAX_ROWS={MAX_ROWS}. Stopping.")
            break

        start = page * BATCH_FETCH
        end = start + BATCH_FETCH - 1

        resp = (
            sb.table(TABLE)
              .select(f"{ID_COL},{TEXT_COL}")
              .is_(EMB_COL, "null")
              .range(start, end)
              .execute()
        )

        rows: List[Dict[str, Any]] = resp.data or []
        if not rows:
            print("No more rows missing embeddings. Done.")
            break

        if MAX_ROWS is not None:
            rows = rows[: max(0, MAX_ROWS - processed)]

        texts = [r[TEXT_COL] or "" for r in rows]
        ids = [r[ID_COL] for r in rows]

        # BGE: prepend instruction for retrieval
        if MODEL_NAME.startswith("BAAI/bge-"):
            texts_for_model = [f"Represent this sentence for retrieval: {t}" for t in texts]
        else:
            texts_for_model = texts

        embeddings: List[List[float]] = []

        for sub_texts in tqdm(chunked(texts_for_model, BATCH_EMBED), desc=f"Embedding page {page}"):
            vecs = model.encode(
                sub_texts,
                normalize_embeddings=normalize,
                show_progress_bar=False,
            )
            embeddings.extend([v.tolist() for v in vecs])

        updates = [
            {ID_COL: jid, EMB_COL: emb}
            for jid, emb in zip(ids, embeddings)
        ]

        # Write back in chunks to avoid payload limits
        for u_chunk in chunked(updates, 200):
            sb.table(TABLE).upsert(u_chunk).execute()

        processed += len(rows)
        print(f"Updated {len(rows)} rows (total processed: {processed})")

        page += 1

    print("Embedding backfill complete.")


if __name__ == "__main__":
    main()
