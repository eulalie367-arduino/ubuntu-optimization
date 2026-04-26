# Vector 2.0 — Hybrid Semantic + Knowledge Graph Layer

The L5 cache tier of the Ultimate MCP System. Combines:
- **ChromaDB** (PersistentClient) — semantic search via `all-MiniLM-L6-v2` embeddings
- **Neo4j Aura Free** — knowledge graph with Projects, Files, Functions, Concepts as nodes

## Directory Structure

```
vector/
├── chroma/
│   ├── data/                  ← ChromaDB persistent storage
│   ├── config.py              ← Collection definitions + initialization
│   └── ingest.py              ← Batch ingest script for projects
├── neo4j/
│   ├── schema.cypher          ← CREATE CONSTRAINT + INDEX statements
│   ├── seed.py                ← Bootstrap graph from filesystem
│   └── queries.py             ← Reusable Cypher query library
├── shared/
│   ├── models.py              ← Pydantic models (ChunkMetadata, SearchResult, etc.)
│   └── chunker.py             ← Code-aware text chunking (Python AST, markdown, sliding window)
├── requirements.txt           ← Python dependencies
└── README.md                  ← This file
```

## Quick Start

### 1. Install Dependencies

```bash
cd Documents/vector
pip install -r requirements.txt
```

### 2. Set Up Neo4j Aura

1. Go to https://neo4j.com/cloud/platform/aura-graph-database/
2. Create a Free Aura instance
3. Download credentials (URI, username, password)
4. Set environment variables:

```bash
set NEO4J_URI=bolt+s://xxx.databases.neo4j.io
set NEO4J_USERNAME=neo4j
set NEO4J_PASSWORD=your_password
```

### 3. Bootstrap the Graph

```bash
python neo4j/seed.py
```

This creates:
- Default concept nodes (MAVLink, PID Control, YOLO, etc.)
- Project nodes from filesystem
- File nodes for each source file

### 4. Ingest Projects into ChromaDB

```bash
python chroma/ingest.py --project ../drone
python chroma/ingest.py --project ../ESP32/hello1
python chroma/ingest.py --project ../AutomagigInaCan
```

Results: embedded chunks stored in `chroma/data/` with metadata (file, line numbers, type).

## Collections in ChromaDB

| Collection | Purpose |
|---|---|
| `source_code` | All .py/.ts/.cpp/.h files, chunked by function/class |
| `docs` | Markdown files, README, CLAUDE.md, GEMINI.md |
| `research` | Output from `/research` skill |
| `errors` | Error messages and fixes |

## Neo4j Node Types

```
Project {name, path, language, status}
File    {path, name, ext, project}
Function {name, file_path, line_start, line_end}
Class   {name, file_path, inherits}
Concept {name, description, domain}
Task    {id, description, priority, status}
Agent   {name, type}
```

## Usage via MCP

Vector 2.0 is exposed via 5 new skills:

- **`/vector-status`** — Show collection sizes + graph node counts
- **`/knowledge-search <query>`** — ChromaDB semantic search → Neo4j expansion
- **`/project-map`** — Query Neo4j for dependency graph
- **`/ingest-project <path>`** — Add new project to both DBs
- **`/find-similar <snippet>`** — Find semantically similar code across all projects

## Architecture Diagram

```
Query Flow:
  User Prompt
    ↓
  ChromaDB Semantic Search (all-MiniLM-L6-v2)
    ↓
  Top-5 Chunks + Metadata
    ↓
  Neo4j Graph Expansion (neighbors, relationships)
    ↓
  Answer with Context
```

## Environment Variables

Required for Neo4j connectivity:
- `NEO4J_URI` — bolt+s connection string
- `NEO4J_USERNAME` — Neo4j username
- `NEO4J_PASSWORD` — Neo4j password

## Verification

```bash
# ChromaDB working?
python -c "from chroma.config import list_collections; print(list_collections())"

# Neo4j working?
python neo4j/queries.py

# Graph seeded?
# (check Neo4j console at neo4j.com/cloud)
```

## Integration with Existing Skills

Update these skills to write to Vector 2.0:
- **`/research`** — Write results to `research` collection
- **`/docs-fetch`** — Write docs to `docs` collection
- **`/error-log`** — Write error messages to `errors` collection

This way, all knowledge flows through L5 cache automatically.

## Performance Notes

- `all-MiniLM-L6-v2`: ~80MB, 213M downloads on HuggingFace — optimal for CPU inference
- ChromaDB PersistentClient: no server process needed, data stored locally
- Neo4j Aura Free: 100K nodes, 500K relationships (sufficient for 5-10 active projects)
- Semantic search: typical query time <100ms

## Future Extensions

1. **Automatic sync** — `/research` and `/docs-fetch` auto-write to collections
2. **Graph visualization** — `/project-map` as ASCII or GraphViz
3. **Cross-project analysis** — Find patterns across all projects
4. **Time-series integration** — Track code evolution over time
5. **LLM-augmented reasoning** — Use Claude to explain graph patterns
