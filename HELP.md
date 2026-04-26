# Vector 2.0 Help Guide

Complete reference for the hybrid semantic + knowledge graph system.

## Table of Contents

1. [Getting Started](#getting-started)
2. [Skills Reference](#skills-reference)
3. [Python API](#python-api)
4. [ChromaDB Collections](#chromadb-collections)
5. [Neo4j Graph Structure](#neo4j-graph-structure)
6. [Troubleshooting](#troubleshooting)
7. [Performance & Tuning](#performance--tuning)
8. [Advanced Usage](#advanced-usage)

---

## Getting Started

### What is Vector 2.0?

Vector 2.0 is a **hybrid knowledge system** combining:
- **ChromaDB** — semantic search via embeddings (find by meaning)
- **Neo4j** — knowledge graph (find by relationships)

Together: powerful queries like "Find all async telemetry handlers across my projects" or "Show me functions that call parse_mavlink_message."

### First Query

After setup, try:
```bash
/knowledge-search "async queue handling"
```

Returns:
- Top-5 code chunks from all projects
- Line numbers for quick navigation
- Related files/functions from graph

### Architecture Overview

```
                    Your Projects
                          ↓
           ┌──────────────┼──────────────┐
           ↓              ↓              ↓
       drone          ESP32       AutomagigInaCan
           │              │              │
           └──────────────┼──────────────┘
                          ↓
           ┌──────────────────────────────┐
           │  Vector 2.0 (L5 Cache)       │
           ├──────────────┬───────────────┤
           │   ChromaDB   │    Neo4j      │
           │(Embeddings)  │  (Graph DB)   │
           └──────────────┴───────────────┘
                          ↓
           ┌──────────────────────────────┐
           │   Claude + Gemini (both)     │
           │  (shared knowledge)          │
           └──────────────────────────────┘
```

### Setup Checklist

- [ ] Neo4j Aura instance created
- [ ] Environment variables set (NEO4J_URI, etc.)
- [ ] `python neo4j/seed.py` completed
- [ ] At least one project ingested
- [ ] `/vector-status` shows non-zero counts

---

## Skills Reference

### /vector-status

**Check system health.**

```bash
/vector-status
```

Output:
```
ChromaDB Collections:
  source_code:     1,247 docs
  docs:              85 docs
  research:          22 docs
  errors:             0 docs

Neo4j Graph:
  Project:      5 nodes
  File:       234 nodes
  Function:    89 nodes
  Concept:      7 nodes

Status: ✓ Nominal
```

**Use when:**
- Verifying ingest completed
- Checking collection sizes
- Diagnosing why searches return no results

---

### /knowledge-search

**Find code by meaning, not keywords.**

```bash
/knowledge-search "MAVLink telemetry processing"
```

```bash
/knowledge-search "async event loop with queue"
```

```bash
/knowledge-search "PID control loop tuning"
```

**How it works:**
1. Embeds your query with all-MiniLM-L6-v2
2. Finds top-5 semantically similar chunks in ChromaDB
3. Walks Neo4j graph to find related functions/files
4. Returns chunks + context

**Output includes:**
- Chunk text with line numbers
- Similarity score (0.0-1.0)
- Project/file location
- Related functions from graph

**Best practices:**
- Use **technical terms** ("telemetry", "PID", "async")
- Be **specific** ("MAVLink protocol handling" vs "communication")
- Multiple queries work well ("async handlers" → "queue implementation" → "message serialization")

**Searches across:**
- source_code — .py/.ts/.cpp/.h files
- docs — markdown, README, CLAUDE.md
- research — previous research results
- errors — error messages and fixes

---

### /project-map

**Visualize your project dependency graph.**

```bash
/project-map
```

```bash
/project-map --detailed
```

Output:
```
PROJECT DEPENDENCY MAP

[drone] ──────────────────────┐
  Status: active              │
  Files: 42                   │
  Path: C:/Users/patrick/...  │
                              │
                  ┌───────────┴──────────┐
                  │                      │
          [ESP32/hello1]       [AutomagigInaCan]
            Status: active       Status: active
            Files: 18            Files: 156

RELATIONSHIPS:
  drone → ESP32/hello1: RELATES_TO (firmware)
  drone → AutomagigInaCan: PART_OF (orchestration)

SHARED CONCEPTS:
  MAVLink (drone, ESP32)
  FastAPI (drone, AutomagigInaCan)
  NATS (AutomagigInaCan, Micro-phase2-v2)
```

**With --detailed:**
- Concept associations
- External dependencies
- Last update timestamp
- Function call patterns

**Use when:**
- Understanding project relationships
- Planning new integrations
- Impact analysis
- Onboarding new developers

---

### /ingest-project

**Add a project to Vector 2.0.**

```bash
/ingest-project Documents/drone
```

```bash
/ingest-project /path/to/project --output results.json
```

Output:
```
============================================================
Ingesting: drone
Path: C:\Users\patrick\Documents\drone
============================================================
  [OK] main.py: 12 chunks
  [OK] telemetry.py: 18 chunks
  [OK] orchestrate.py: 24 chunks
  ...

drone Summary:
  Files: 42
  Chunks: 1,247
  Duration: 8.34s
```

**What gets indexed:**
- `.py`, `.ts`, `.tsx`, `.js`, `.jsx` — code
- `.cpp`, `.h`, `.c` — C/C++ code
- `.md`, `.txt` — documentation

**What gets skipped:**
- `.git`, `node_modules`, `__pycache__`, `venv`
- Binary files, files > 10MB
- `.env`, `.secrets`, credential files

**Creates in Neo4j:**
- Project node
- File nodes
- DEPENDS_ON relationships (from imports)
- Links to Concept nodes

**Use when:**
- Adding new project to knowledge base
- Re-indexing after major refactor
- Updating semantic search with latest code

---

### /find-similar

**Find matching code patterns across projects.**

```bash
/find-similar
async def listen():
    while True:
        msg = await queue.get()
        process(msg)
```

```bash
/find-similar "import asyncio\nasync def handler():"
```

Output:
```
TOP 10 SIMILAR CHUNKS

1. drone/telemetry.py:45-67 [0.95 similarity]
   async def listen_telemetry():
       while True:
           msg = await telem_queue.get()
           await process_telemetry(msg)

2. AutomagigInaCan/listener.py:102-125 [0.92 similarity]
   async def main_listener():
       while loop_active:
           item = await message_queue.get()
           handle_message(item)

3. ESP32/async_main.py:78-95 [0.87 similarity]
   ...
```

**Similarity scoring:**
- **0.90+** — Functionally identical
- **0.80-0.89** — Same pattern, different details
- **0.70-0.79** — Related concept
- **<0.70** — Tangentially related

**Best for:**
- Refactoring (find all instances of pattern)
- Deduplication (identify repeated code)
- Learning (see how others solved it)
- Code review (check consistency)

---

## Python API

### Using ChromaDB Directly

```python
from Documents.vector.chroma.config import SOURCE_CODE_COLLECTION, list_collections

# Check collection sizes
stats = list_collections()
print(stats)  # {"source_code": {"count": 1247}, ...}

# Search for similar chunks
results = SOURCE_CODE_COLLECTION.query(
    query_texts=["async queue handler"],
    n_results=5
)

for doc, metadata in zip(results['documents'][0], results['metadatas'][0]):
    print(f"{metadata['file_path']}:{metadata['line_start']}")
    print(doc[:200])
```

### Using Neo4j Directly

```python
from Documents.vector.neo4j.queries import Neo4jQueries

queries = Neo4jQueries()

# Get all projects
projects = queries.get_all_projects()
for proj in projects:
    print(proj['name'], proj['status'])

# Get files in a project
files = queries.get_project_files('drone')
for f in files:
    print(f['path'], f['size_bytes'])

# Get graph summary
summary = queries.get_graph_summary()
print(summary)  # {'Project': 5, 'File': 234, ...}

queries.close()
```

### Chunking Code Manually

```python
from Documents.vector.shared.chunker import chunk_file

code = open("my_file.py").read()
chunks = chunk_file(code, "my_file.py")

for chunk in chunks:
    print(f"{chunk.chunk_type}: {chunk.line_start}-{chunk.line_end}")
    print(chunk.text[:100])
```

---

## ChromaDB Collections

### source_code

**All source code chunks.**

Storage: `Documents/vector/chroma/data/`

Metadata per chunk:
```json
{
  "project": "drone",
  "file_path": "telemetry.py",
  "chunk_type": "function",
  "line_start": 45,
  "line_end": 67,
  "language": "python"
}
```

Chunking strategy:
- **Python (.py):** AST-aware (extract function/class definitions)
- **Markdown (.md):** Section-based (split by headers)
- **Other (.ts, .cpp):** Sliding window (512 tokens, 50 token overlap)

### docs

**Documentation files.**

Includes:
- `README.md` files from projects
- `CLAUDE.md` / `GEMINI.md`
- Inline documentation
- Architecture docs

### research

**Results from `/research` skill.**

Populated by:
- Web research summaries
- Code analysis results
- Design documents
- Meeting notes

### errors

**Error messages and solutions.**

Used for:
- Debugging (find similar errors)
- Learning (understand solutions)
- Pattern detection (repeated issues)

---

## Neo4j Graph Structure

### Node Labels

```
:Project {name, path, language, status, github_url, description}
:File {path, name, ext, project, size_bytes}
:Function {name, file_path, line_start, line_end, signature}
:Class {name, file_path, inherits}
:Concept {name, description, domain}
:Task {id, description, priority, status}
:Agent {name, type}
```

### Relationships

```
(File)-[:DEPENDS_ON]->(File)           # imports/includes
(Function)-[:CALLS]->(Function)        # execution flow
(Class)-[:IMPLEMENTS]->(Concept)       # maps to theory
(Project)-[:HAS_TASK]->(Task)          # PM tracking
(Agent)-[:PERFORMS]->(Task)            # responsibility
(Project)-[:RELATES_TO]->(Project)     # cross-repo dependencies
(Project)-[:PART_OF]->(Project)        # sub-projects
(File)-[:CONTAINS]->(Function)         # file structure
(File)-[:CONTAINS]->(Class)
```

### Example Queries

Find all functions that call `parse_mavlink_message`:
```cypher
MATCH (f:Function {name: "parse_mavlink_message"})<-[:CALLS]-(caller:Function)
RETURN caller.name, caller.file_path
```

Find projects that depend on FastAPI:
```cypher
MATCH (c:Concept {name: "FastAPI"})<-[:IMPLEMENTS]-(class:Class)
    <-[:CONTAINS]-(f:File)<-[:CONTAINS]-(p:Project)
RETURN p.name
```

Find shortest path between two concepts:
```cypher
MATCH path = shortestPath(
  (a:Concept {name: "MAVLink"})-[*]-(b:Concept {name: "PID Control"})
)
RETURN path
```

---

## Troubleshooting

### "Neo4j connection failed"

**Symptom:** Skills fail with "Neo4j connection refused"

**Solution:**
```bash
# 1. Check credentials are set
echo %NEO4J_URI%
echo %NEO4J_USERNAME%

# 2. Verify instance is running
# → Check https://neo4j.com/cloud

# 3. Restart Claude Code
# (environment variables take effect on startup)

# 4. Test connection
python -c "from neo4j import GraphDatabase; d=GraphDatabase.driver(uri); d.verify_connectivity()"
```

### "ChromaDB not initialized"

**Symptom:** "No such file: chroma/data/"

**Solution:**
```bash
cd Documents/vector
python -c "from chroma.config import list_collections; print(list_collections())"

# This auto-creates chroma/data/ and initializes collections
```

### "No results from /knowledge-search"

**Symptom:** Empty results despite projects being ingested

**Reasons:**
1. No projects ingested yet
   ```bash
   /vector-status  # Check if collections have docs
   ```

2. Query too specific
   ```bash
   # Bad: /knowledge-search "the telemetry queue"
   # Good: /knowledge-search "telemetry queue"
   ```

3. Wrong terminology
   ```bash
   # Bad: /knowledge-search "listener function"
   # Good: /knowledge-search "async queue handler"
   ```

**Solution:**
- Run `/vector-status` to verify collections are populated
- Try different keywords
- Check `/project-map` to see ingested projects

### Ingest script hangs

**Symptom:** `python chroma/ingest.py --project ../drone` doesn't finish

**Reasons:**
1. Large .git directory being scanned
   - Solution: Git is skipped, but check if path is correct

2. Very large file being embedded
   - Solution: Files >10MB are skipped by default

3. Python AST parsing slow on large files
   - Solution: Fallback to sliding window happens automatically

**Diagnostic:**
```bash
# Check what's being scanned
python -c "
from pathlib import Path
project = Path('../drone')
files = list(project.rglob('*.py'))
print(f'Found {len(files)} Python files')
"
```

### "/vector-status shows 0 docs"

**Symptom:** Collections exist but are empty

**Solution:**
```bash
# Ingest a project
python chroma/ingest.py --project ../drone

# Verify
/vector-status  # Should now show non-zero counts
```

### Skills not showing up in Claude Code

**Symptom:** `/vector-status` command not recognized

**Solution:**
1. Restart Claude Code
2. Verify skill files exist:
   ```bash
   ls ~/.claude/skills/vector-status/SKILL.md
   ```
3. Run:
   ```bash
   claude skill list
   ```

---

## Performance & Tuning

### Typical Performance

| Operation | Time | Notes |
|-----------|------|-------|
| Embed 512 tokens | ~50ms | all-MiniLM-L6-v2 on CPU |
| ChromaDB search (top-10) | <100ms | Cosine similarity |
| Neo4j graph walk (1 hop) | <50ms | Single relationship |
| Full query (semantic + graph) | ~200ms | End-to-end |
| Ingest 50-file project | 5-10s | Parallelizable |

### Optimization Tips

**For faster ingest:**
```bash
# Ingest smaller projects first
python chroma/ingest.py --project ../ESP32/hello1

# Larger projects in background
python chroma/ingest.py --project ../AutomagigInaCan &
```

**For faster searches:**
- Use specific technical terms
- Avoid common words ("the", "function", "code")
- Refine with second query if needed

**For Neo4j:**
- Indexes are pre-created on common queries
- Large graph walks (>3 hops) may be slow
- Use shortestPath() to find relationships

---

## Advanced Usage

### Custom Chunking

```python
from Documents.vector.shared.chunker import chunk_python_file

code = open("complex.py").read()
chunks = chunk_python_file(code)

# Chunks are automatically function/class-aware
for chunk in chunks:
    print(f"{chunk.chunk_type} at {chunk.line_start}-{chunk.line_end}")
```

### Embedding Custom Text

```python
from sentence_transformers import SentenceTransformer

model = SentenceTransformer('all-MiniLM-L6-v2')
embedding = model.encode("your text here")

# Use for ChromaDB search
print(embedding.shape)  # (384,)
```

### Batch Operations

```python
from Documents.vector.chroma.config import SOURCE_CODE_COLLECTION

# Add multiple documents
SOURCE_CODE_COLLECTION.add(
    documents=[doc1, doc2, doc3],
    metadatas=[meta1, meta2, meta3],
    ids=["id1", "id2", "id3"]
)

# Batch query
results = SOURCE_CODE_COLLECTION.query(
    query_texts=["query1", "query2"],
    n_results=10
)
```

### Neo4j Transactions

```python
from Documents.vector.neo4j.queries import Neo4jQueries

queries = Neo4jQueries()

# Create relationships
queries.create_relation("drone", "RELATES_TO", "ESP32")

# Run custom query
with queries.driver.session() as session:
    result = session.run(
        "MATCH (p:Project {name: $name}) RETURN p",
        name="drone"
    )
    for record in result:
        print(record)
```

### Time-Series Analysis

Future: Track code evolution using git commits:
```cypher
MATCH (file:File)-[:MODIFIED_IN]->(commit:Commit)
WHERE commit.timestamp > datetime() - duration('P30D')
RETURN file.path, count(commit) as changes_30d
ORDER BY changes_30d DESC
```

---

## FAQ

**Q: Can I search across multiple projects?**
A: Yes! `/knowledge-search` searches all ingested projects simultaneously.

**Q: How do I update a project after code changes?**
A: Re-run `/ingest-project path` — it replaces old embeddings with new ones.

**Q: Can Gemini use the same knowledge graph?**
A: Yes! Both Claude and Gemini point to same Neo4j Aura instance for shared knowledge.

**Q: What if a project has 10,000 functions?**
A: Neo4j Free tier supports 100K nodes. 10K functions per project is fine.

**Q: How long are embeddings cached?**
A: ChromaDB stores indefinitely. Re-ingest only when code changes.

**Q: Can I delete a collection?**
A: Yes: `python -c "from chroma.config import reset_collection; reset_collection('source_code')"`

**Q: Is there a web UI?**
A: Not yet. Neo4j has a web console at https://neo4j.com/cloud for visualization.

---

**Still stuck?** Check `IMPLEMENTATION_SUMMARY.md` or `QUICK_START.md`.
