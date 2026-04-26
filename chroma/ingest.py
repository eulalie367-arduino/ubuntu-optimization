"""Batch ingest script for ChromaDB — chunk and embed source files."""

import argparse
import sys
from pathlib import Path
from datetime import datetime
import json

# Add parent to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from shared.chunker import chunk_file, Chunk
from shared.models import ChunkMetadata
from config import SOURCE_CODE_COLLECTION, DOCS_COLLECTION


# Files to skip
SKIP_DIRS = {'.git', 'node_modules', '__pycache__', 'venv', '.venv', '.env', 'dist', 'build'}
SKIP_FILES = {'.DS_Store', 'thumbs.db'}
EXTENSIONS = {'.py', '.ts', '.tsx', '.js', '.jsx', '.cpp', '.h', '.c', '.md', '.txt'}


def walk_project(project_path: str) -> list[Path]:
    """Walk project directory and yield source files."""
    project_dir = Path(project_path).resolve()

    if not project_dir.exists():
        raise FileNotFoundError(f"Project path not found: {project_dir}")

    files = []
    for item in project_dir.rglob("*"):
        if item.is_file():
            # Skip directories
            if any(skip_dir in item.parts for skip_dir in SKIP_DIRS):
                continue
            # Skip files
            if item.name in SKIP_FILES:
                continue
            # Only include known extensions
            if item.suffix in EXTENSIONS:
                files.append(item)

    return files


def ingest_file(
    file_path: Path,
    project_name: str,
    collection_name: str = "source_code"
) -> int:
    """
    Read, chunk, and embed a single file.
    Returns: number of chunks added.
    """
    try:
        content = file_path.read_text(encoding='utf-8', errors='ignore')
    except Exception as e:
        print(f"  [SKIP] {file_path.name}: {e}")
        return 0

    chunks = chunk_file(content, str(file_path))
    if not chunks:
        return 0

    # Get collection based on file type
    if file_path.suffix == '.md':
        collection = DOCS_COLLECTION
    else:
        collection = SOURCE_CODE_COLLECTION

    # Add chunks to collection
    chunk_count = 0
    for chunk in chunks:
        try:
            metadata = {
                "project": project_name,
                "file_path": str(file_path.relative_to(Path(project_name).parent.parent if project_name.startswith('.') else Path(project_name).parent)),
                "chunk_type": chunk.chunk_type,
                "line_start": chunk.line_start,
                "line_end": chunk.line_end,
                "language": file_path.suffix.lstrip('.'),
            }

            # Chromadb stores embedding, so we just need text + metadata
            collection.add(
                documents=[chunk.text],
                metadatas=[metadata],
                ids=[f"{file_path.stem}_{chunk.line_start}"],
            )
            chunk_count += 1
        except Exception as e:
            print(f"  [ERROR] Chunk {chunk.line_start}-{chunk.line_end}: {e}")
            continue

    return chunk_count


def ingest_project(project_path: str) -> dict:
    """
    Ingest all source files from a project.
    Returns: {files: int, chunks: int, errors: int, duration: float}
    """
    start = datetime.now()
    project_dir = Path(project_path).resolve()
    project_name = project_dir.name

    print(f"\n{'='*60}")
    print(f"Ingesting: {project_name}")
    print(f"Path: {project_dir}")
    print(f"{'='*60}")

    files = walk_project(project_dir)
    total_chunks = 0
    total_files = 0

    for file_path in sorted(files):
        chunk_count = ingest_file(file_path, project_name)
        if chunk_count > 0:
            print(f"  [OK] {file_path.name}: {chunk_count} chunks")
            total_chunks += chunk_count
            total_files += 1
        else:
            print(f"  [EMPTY] {file_path.name}")

    duration = (datetime.now() - start).total_seconds()

    result = {
        "project": project_name,
        "files": total_files,
        "chunks": total_chunks,
        "duration_sec": round(duration, 2),
        "timestamp": datetime.now().isoformat(),
    }

    print(f"\n{project_name} Summary:")
    print(f"  Files: {total_files}")
    print(f"  Chunks: {total_chunks}")
    print(f"  Duration: {duration:.2f}s")

    return result


def main():
    parser = argparse.ArgumentParser(description="Ingest project into ChromaDB")
    parser.add_argument("--project", required=True, help="Path to project directory")
    parser.add_argument("--output", help="Save results to JSON file")

    args = parser.parse_args()

    result = ingest_project(args.project)

    if args.output:
        output_path = Path(args.output)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(json.dumps(result, indent=2))
        print(f"\nResults saved to: {output_path}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
