"""ChromaDB configuration and collection setup for Vector 2.0."""

import chromadb
from pathlib import Path
from typing import Optional

# Data directory for ChromaDB
DATA_DIR = Path(__file__).parent / "data"
DATA_DIR.mkdir(exist_ok=True)

# Initialize PersistentClient
client = chromadb.PersistentClient(path=str(DATA_DIR))


def get_or_create_collection(name: str) -> chromadb.Collection:
    """Get or create a ChromaDB collection by name."""
    return client.get_or_create_collection(
        name=name,
        metadata={"hnsw:space": "cosine"}  # cosine similarity
    )


# Collection definitions
SOURCE_CODE_COLLECTION = get_or_create_collection("source_code")
"""All .py/.ts/.cpp/.h files chunked by function/class."""

DOCS_COLLECTION = get_or_create_collection("docs")
"""Markdown files, README, CLAUDE.md, GEMINI.md."""

RESEARCH_COLLECTION = get_or_create_collection("research")
"""Output from /research skill and docs-fetch."""

ERRORS_COLLECTION = get_or_create_collection("errors")
"""Error messages and their fixes."""


def list_collections() -> dict:
    """Get stats on all collections."""
    stats = {}
    for collection in [SOURCE_CODE_COLLECTION, DOCS_COLLECTION, RESEARCH_COLLECTION, ERRORS_COLLECTION]:
        count = collection.count()
        stats[collection.name] = {
            "count": count,
            "name": collection.name,
        }
    return stats


def reset_collection(name: str) -> None:
    """Reset a collection (delete all documents)."""
    try:
        client.delete_collection(name=name)
        get_or_create_collection(name)
        print(f"Reset collection: {name}")
    except Exception as e:
        print(f"Error resetting {name}: {e}")


if __name__ == "__main__":
    print(f"ChromaDB data dir: {DATA_DIR}")
    print(f"Collections: {list(client.list_collections())}")
    stats = list_collections()
    for name, info in stats.items():
        print(f"  {name}: {info['count']} docs")
