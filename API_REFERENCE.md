# Vector 2.0 Python API Reference

**For developers extending or integrating with Vector 2.0.**

## Table of Contents

1. [ChromaDB API](#chromadb-api)
2. [Neo4j API](#neo4j-api)
3. [Chunking API](#chunking-api)
4. [Examples](#examples)

---

## ChromaDB API

### Module: `chroma/config.py`

Initialize and access collections:

```python
from chroma.config import (
    SOURCE_CODE_COLLECTION,
    DOCS_COLLECTION,
    RESEARCH_COLLECTION,
    ERRORS_COLLECTION,
    list_collections,
    reset_collection,
    get_or_create_collection,
)
```

### Functions

#### `get_or_create_collection(name: str) -> Collection`

Create or retrieve a ChromaDB collection.

```python
from chroma.config import get_or_create_collection

custom_col = get_or_create_collection("my_collection")
```

**Returns:** ChromaDB Collection object

#### `list_collections() -> dict`

Get stats on all collections.

```python
from chroma.config import list_collections

stats = list_collections()
# {
#   "source_code": {"count": 1247},
#   "docs": {"count": 85},
#   ...
# }

for name, info in stats.items():
    print(f"{name}: {info['count']} documents")
```

**Returns:** Dictionary with collection stats

#### `reset_collection(name: str) -> None`

Delete all documents in a collection.

```python
from chroma.config import reset_collection

reset_collection("source_code")  # Dangerous!
```

### Collections (Pre-defined)

#### SOURCE_CODE_COLLECTION

All source code chunks (Python, TypeScript, C++, etc.)

```python
# Add documents
SOURCE_CODE_COLLECTION.add(
    documents=["code snippet 1", "code snippet 2"],
    metadatas=[
        {"project": "drone", "file_path": "main.py", "chunk_type": "function"},
        {"project": "esp32", "file_path": "handler.cpp", "chunk_type": "function"},
    ],
    ids=["doc1", "doc2"]
)

# Query
results = SOURCE_CODE_COLLECTION.query(
    query_texts=["async queue handler"],
    n_results=5
)

for doc, meta in zip(results['documents'][0], results['metadatas'][0]):
    print(f"{meta['file_path']}: {doc[:50]}...")
```

#### DOCS_COLLECTION

Markdown and documentation files.

```python
DOCS_COLLECTION.add(
    documents=["# README\n\nThis project does X..."],
    metadatas=[{"project": "drone", "file_path": "README.md"}],
    ids=["readme_1"]
)
```

#### RESEARCH_COLLECTION

Results from research queries.

```python
RESEARCH_COLLECTION.add(
    documents=["Research: MAVLink optimization techniques..."],
    metadatas=[{"source": "/research", "timestamp": "2026-04-25"}],
    ids=["research_1"]
)
```

#### ERRORS_COLLECTION

Error messages and solutions.

```python
ERRORS_COLLECTION.add(
    documents=["TimeoutError: Queue timeout after 5s\nSolution: increase timeout or optimize handler"],
    metadatas=[{"project": "drone", "error_code": "E001"}],
    ids=["error_1"]
)
```

---

## Neo4j API

### Module: `neo4j/queries.py`

Query and modify the knowledge graph:

```python
from neo4j.queries import Neo4jQueries

queries = Neo4jQueries()

# Use queries...

queries.close()  # Clean up
```

### Methods

#### `get_all_projects() -> List[Dict]`

Fetch all Project nodes.

```python
projects = queries.get_all_projects()
# [
#   {"name": "drone", "path": "/path/to/drone", "status": "active"},
#   {"name": "esp32", "path": "/path/to/esp32", "status": "active"},
# ]

for proj in projects:
    print(f"{proj['name']}: {proj['status']}")
```

#### `get_project_files(project_name: str) -> List[Dict]`

Get all files in a project.

```python
files = queries.get_project_files("drone")
# [
#   {"path": "telemetry.py", "name": "telemetry.py", "size_bytes": 4521},
#   ...
# ]

for f in files:
    print(f"{f['path']} ({f['size_bytes']} bytes)")
```

#### `get_graph_summary() -> Dict[str, int]`

Get counts of all node types.

```python
summary = queries.get_graph_summary()
# {
#   "Project": 5,
#   "File": 234,
#   "Function": 89,
#   "Concept": 7,
# }

for label, count in summary.items():
    print(f"{label}: {count}")
```

#### `find_related_projects(project_name: str) -> List[str]`

Find projects related to a given project.

```python
related = queries.find_related_projects("drone")
# ["esp32", "automagi_in_a_can"]

for proj in related:
    print(f"Related: {proj}")
```

#### `create_relation(from_node: str, rel_type: str, to_node: str) -> bool`

Create a relationship between two nodes.

```python
# Create RELATES_TO relationship
success = queries.create_relation("drone", "RELATES_TO", "esp32")
if success:
    print("Relationship created")
```

### Running Custom Cypher

```python
from neo4j.queries import Neo4jQueries

queries = Neo4jQueries()

with queries.driver.session() as session:
    # Run custom query
    result = session.run(
        """
        MATCH (p:Project {name: $name})-[:CONTAINS]->(f:File)
        RETURN f.path, f.size_bytes
        ORDER BY f.size_bytes DESC
        LIMIT 10
        """,
        name="drone"
    )

    for record in result:
        print(f"{record['f.path']}: {record['f.size_bytes']} bytes")

queries.close()
```

---

## Chunking API

### Module: `shared/chunker.py`

Split code into chunks:

```python
from shared.chunker import (
    chunk_file,
    chunk_python_file,
    chunk_markdown_file,
    Chunk,
)
```

### Functions

#### `chunk_file(content: str, file_path: str) -> List[Chunk]`

Auto-detect file type and chunk accordingly.

```python
from shared.chunker import chunk_file

code = open("main.py").read()
chunks = chunk_file(code, "main.py")

for chunk in chunks:
    print(f"{chunk.chunk_type}: {chunk.line_start}-{chunk.line_end}")
    print(f"Text: {chunk.text[:50]}...")
```

**Returns:** List of Chunk objects

#### `chunk_python_file(content: str) -> List[Chunk]`

Python-specific chunking (AST-aware).

```python
from shared.chunker import chunk_python_file

code = """
def function1():
    pass

def function2():
    pass

class MyClass:
    def method(self):
        pass
"""

chunks = chunk_python_file(code)
# Chunks: [function1, function2, MyClass]
```

Each function/class becomes a separate chunk.

#### `chunk_markdown_file(content: str) -> List[Chunk]`

Markdown chunking (header-based).

```python
from shared.chunker import chunk_markdown_file

markdown = """
# Section 1
Content...

## Subsection
Content...

# Section 2
Content...
"""

chunks = chunk_markdown_file(markdown)
# Chunks: [Section 1, Subsection, Section 2]
```

Each header + content becomes a chunk.

### Chunk Class

```python
from shared.chunker import Chunk

chunk = Chunk(
    text="def handler(): pass",
    chunk_type="function",  # "function", "class", "docstring", "code", "markdown"
    line_start=45,
    line_end=67,
)

print(chunk.text)
print(chunk.chunk_type)
print(f"Lines {chunk.line_start}-{chunk.line_end}")
```

---

## Embedding API

### Module: Uses `sentence-transformers`

```python
from sentence_transformers import SentenceTransformer

model = SentenceTransformer('all-MiniLM-L6-v2')

# Single embedding
embedding = model.encode("your text here")
print(embedding.shape)  # (384,)

# Batch embeddings
embeddings = model.encode(["text 1", "text 2", "text 3"])
print(embeddings.shape)  # (3, 384)

# Compute similarity
from sklearn.metrics.pairwise import cosine_similarity
sim = cosine_similarity([embedding], [model.encode("another text")])[0][0]
print(f"Similarity: {sim}")  # 0.0-1.0
```

---

## Models API

### Module: `shared/models.py`

Data models (Pydantic):

```python
from shared.models import (
    ChunkMetadata,
    SearchResult,
    ProjectNode,
    FileNode,
    FunctionNode,
    ConceptNode,
)
```

### Classes

#### ChunkMetadata

```python
from shared.models import ChunkMetadata

metadata = ChunkMetadata(
    project="drone",
    file_path="telemetry.py",
    chunk_type="function",
    line_start=45,
    line_end=67,
    language="python"
)

print(metadata.project)  # "drone"
print(metadata.dict())  # JSON-serializable dict
```

#### SearchResult

```python
from shared.models import SearchResult

result = SearchResult(
    text="def parse_mavlink(): ...",
    metadata=metadata,
    similarity_score=0.95,
    document_id="doc_123"
)

print(result.similarity_score)  # 0.95
```

#### ProjectNode

```python
from shared.models import ProjectNode

proj = ProjectNode(
    name="drone",
    path="/path/to/drone",
    language="python",
    status="active",
    github_url="https://github.com/user/drone"
)
```

---

## Examples

### Example 1: Add Custom Collection

```python
from chroma.config import get_or_create_collection

# Create custom collection
tutorials = get_or_create_collection("tutorials")

# Add documents
tutorials.add(
    documents=["Tutorial content 1", "Tutorial content 2"],
    metadatas=[
        {"type": "video", "duration": "10min"},
        {"type": "article", "duration": "5min"},
    ],
    ids=["tut1", "tut2"]
)

# Query
results = tutorials.query(
    query_texts=["async programming"],
    n_results=5
)
```

### Example 2: Batch Ingest Project

```python
from pathlib import Path
from shared.chunker import chunk_file
from shared.models import ChunkMetadata
from chroma.config import SOURCE_CODE_COLLECTION

project_path = Path("../drone")
files = list(project_path.rglob("*.py"))

for file_path in files:
    content = file_path.read_text()
    chunks = chunk_file(content, str(file_path))

    for chunk in chunks:
        metadata = {
            "project": "drone",
            "file_path": str(file_path.relative_to(project_path.parent)),
            "chunk_type": chunk.chunk_type,
            "line_start": chunk.line_start,
            "line_end": chunk.line_end,
            "language": "python",
        }

        SOURCE_CODE_COLLECTION.add(
            documents=[chunk.text],
            metadatas=[metadata],
            ids=[f"{file_path.stem}_{chunk.line_start}"]
        )
```

### Example 3: Query Graph + Semantic

```python
from sentence_transformers import SentenceTransformer
from chroma.config import SOURCE_CODE_COLLECTION
from neo4j.queries import Neo4jQueries

# Semantic search
model = SentenceTransformer('all-MiniLM-L6-v2')
query_embedding = model.encode("telemetry handler")

results = SOURCE_CODE_COLLECTION.query(
    query_embeddings=[query_embedding],
    n_results=5
)

# For each result, expand via graph
queries = Neo4jQueries()

for metadata in results['metadatas'][0]:
    # Find related files
    related_files = queries.get_project_files(metadata['project'])
    print(f"Project {metadata['project']}: {len(related_files)} files")

queries.close()
```

### Example 4: Find Duplicates

```python
from sentence_transformers import SentenceTransformer
from chroma.config import SOURCE_CODE_COLLECTION

model = SentenceTransformer('all-MiniLM-L6-v2')

# User's code
user_code = "async def handler(): ..."
user_embedding = model.encode(user_code)

# Find similar
results = SOURCE_CODE_COLLECTION.query(
    query_embeddings=[user_embedding],
    n_results=10
)

# Filter by score
high_matches = [
    (doc, meta, score)
    for doc, meta, score in zip(
        results['documents'][0],
        results['metadatas'][0],
        results['distances'][0]  # Lower = more similar
    )
    if (1 - score) > 0.85  # Convert distance to similarity
]

for doc, meta, score in high_matches:
    print(f"{meta['file_path']}:{meta['line_start']} ({score:.2f})")
```

---

## Configuration

### Environment Variables

```bash
# Neo4j
NEO4J_URI=bolt+s://xxx.databases.neo4j.io
NEO4J_USERNAME=neo4j
NEO4J_PASSWORD=your_password

# ChromaDB
CHROMA_DATA_DIR=Documents/vector/chroma/data/

# Embedding model
EMBEDDING_MODEL=all-MiniLM-L6-v2  # Default
```

### ChromaDB Settings

Edit `chroma/config.py`:

```python
# Change collection distance metric
collection = client.get_or_create_collection(
    name="source_code",
    metadata={"hnsw:space": "cosine"}  # cosine, l2, ip
)
```

### Neo4j Settings

Edit `neo4j/queries.py`:

```python
# Change query timeout
result = session.run(
    query,
    parameters,
    timeout=30  # seconds
)
```

---

## Error Handling

### ChromaDB Errors

```python
from chroma.config import SOURCE_CODE_COLLECTION

try:
    SOURCE_CODE_COLLECTION.add(
        documents=[...],
        metadatas=[...],
        ids=[...]
    )
except Exception as e:
    print(f"Add failed: {e}")
```

### Neo4j Errors

```python
from neo4j import GraphDatabase

try:
    driver = GraphDatabase.driver(uri, auth=(username, password))
    driver.verify_connectivity()
except Exception as e:
    print(f"Neo4j connection failed: {e}")
```

---

## Performance Tips

### 1. Batch Operations

```python
# Bad: One at a time
for doc in documents:
    collection.add(documents=[doc], metadatas=[meta], ids=[id])

# Good: Batch
collection.add(documents=documents, metadatas=metas, ids=ids)
```

### 2. Cache Embeddings

```python
# Bad: Re-embed every time
embedding = model.encode(text)

# Good: Cache in ChromaDB
collection.add(documents=[text], embeddings=[embedding])
# ChromaDB stores embedding, no need to re-compute
```

### 3. Connection Pooling

```python
# Neo4j driver is thread-safe, reuse it
with queries.driver.session() as session:
    result1 = session.run("MATCH...")
    result2 = session.run("MATCH...")
```

---

## Testing

### Unit Test Example

```python
import pytest
from shared.chunker import chunk_python_file

def test_chunk_python():
    code = """
def func1():
    pass

def func2():
    pass
"""
    chunks = chunk_python_file(code)
    assert len(chunks) == 2
    assert chunks[0].chunk_type == "function"
```

### Integration Test Example

```python
import pytest
from chroma.config import SOURCE_CODE_COLLECTION, reset_collection

@pytest.fixture
def clean_collection():
    reset_collection("source_code")
    yield SOURCE_CODE_COLLECTION
    reset_collection("source_code")

def test_add_and_query(clean_collection):
    clean_collection.add(
        documents=["test code"],
        metadatas=[{"project": "test"}],
        ids=["test1"]
    )

    results = clean_collection.query(
        query_texts=["code"],
        n_results=1
    )
    assert len(results['documents'][0]) == 1
```

---

## Extending Vector 2.0

### Add New Collection

```python
# In chroma/config.py
CUSTOM_COLLECTION = get_or_create_collection("custom_docs")
```

### Add New Node Type

```python
# In neo4j/seed.py
def create_custom_node(tx, name: str, value: str):
    query = """
    MERGE (c:CustomNode {name: $name})
    SET c.value = $value
    """
    tx.run(query, name=name, value=value)
```

### Add New Skill

```bash
# Create skill directory
mkdir ~/.claude/skills/my-skill

# Create SKILL.md
cat > ~/.claude/skills/my-skill/SKILL.md << 'EOF'
---
name: my-skill
description: What it does
---

# /my-skill

Instructions here
EOF
```

---

**For more examples, see `Documents/vector/` Python files.**
