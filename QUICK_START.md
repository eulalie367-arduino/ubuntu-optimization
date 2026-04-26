# Vector 2.0 Quick Start

**Time to productive:** ~45 minutes

## 1️⃣ Create Neo4j Aura Instance (5 min)

```
https://neo4j.com/cloud/platform/aura-graph-database/
→ Create Free Instance
→ Download credentials (URI, username, password)
```

Set environment variables in Command Prompt:
```cmd
setx NEO4J_URI bolt+s://your-instance.databases.neo4j.io
setx NEO4J_USERNAME neo4j
setx NEO4J_PASSWORD your_password
```

**⚠️ Restart Claude Code after `setx`**

## 2️⃣ Verify Setup (1 min)

```bash
cd Documents/vector
python verify_setup.py
```

Look for:
```
✓ chroma/data/
✓ chromadb
✓ sentence_transformers
✓ neo4j
✓ NEO4J_URI: bolt+s://...
```

## 3️⃣ Bootstrap Neo4j (2 min)

```bash
cd Documents/vector
python neo4j/seed.py
```

Creates 7 concept nodes (MAVLink, PID Control, YOLO, etc.)

## 4️⃣ Ingest Projects (20-30 min)

```bash
python chroma/ingest.py --project ../drone
python chroma/ingest.py --project ../ESP32/hello1
python chroma/ingest.py --project ../AutomagigInaCan
```

Each ingests:
- ✓ Chunks code by function/class (Python AST)
- ✓ Embeds with all-MiniLM-L6-v2
- ✓ Stores in ChromaDB
- ✓ Creates Neo4j File nodes

## 5️⃣ Verify Ingest (1 min)

```bash
/vector-status
```

Should show:
```
ChromaDB Collections:
  source_code:     1,247 docs
  docs:              85 docs

Neo4j Graph:
  Project:      3 nodes
  File:       247 nodes
```

## 🎯 Test End-to-End (2 min)

```bash
/knowledge-search "telemetry"
```

Should return top-5 chunks from drone project.

```bash
/project-map
```

Should show drone, ESP32, AutomagigInaCan nodes.

---

## Skills You Now Have

| Command | What it does |
|---------|-------------|
| `/vector-status` | Check system health |
| `/knowledge-search <query>` | Find code by concept |
| `/project-map` | See project relationships |
| `/ingest-project <path>` | Add new project |
| `/find-similar <code>` | Find matching patterns |

---

## Troubleshooting

**"neo4j connection failed"**
→ Check `echo %NEO4J_URI%` — verify credentials set and Claude Code restarted

**"chromadb error"**
→ Run `python Documents/vector/verify_setup.py` to diagnose

**"ingest hangs"**
→ Project path might have large .git or node_modules. Try smaller project first.

**Skills not showing up**
→ Restart Claude Code, then run `/vector-status`

---

## Architecture in 30 Seconds

```
Query → all-MiniLM-L6-v2 embedding → ChromaDB search → Neo4j graph expansion → Answer
         (sentence-transformers)    (PersistentClient) (Aura Free)
```

One query hits both semantic search (code similarity) and relational graph (project relationships).

---

## Next Commands

```bash
cd Documents/vector

# 1. Verify setup
python verify_setup.py

# 2. Seed Neo4j
python neo4j/seed.py

# 3. Ingest drone project
python chroma/ingest.py --project ../drone

# 4. Verify ingest
/vector-status

# 5. Try semantic search
/knowledge-search "telemetry latency"
```

**After setup, you have a fully functional AI-powered knowledge system for all your projects.**
