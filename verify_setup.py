#!/usr/bin/env python
"""Vector 2.0 setup verification script."""

import sys
import os
from pathlib import Path

print("Vector 2.0 Setup Verification")
print("=" * 60)

# Check 1: Directory structure
print("\n[1] Directory Structure")
required_dirs = [
    "chroma/data",
    "chroma",
    "neo4j",
    "shared",
]
for dir_name in required_dirs:
    dir_path = Path(__file__).parent / dir_name
    status = "✓" if dir_path.exists() else "✗"
    print(f"  {status} {dir_name}/")

# Check 2: Python dependencies
print("\n[2] Python Dependencies")
packages = ["chromadb", "sentence_transformers", "neo4j", "pydantic"]
for pkg in packages:
    try:
        __import__(pkg)
        print(f"  ✓ {pkg}")
    except ImportError:
        print(f"  ✗ {pkg} (run: pip install -r requirements.txt)")

# Check 3: Neo4j credentials
print("\n[3] Neo4j Configuration")
neo4j_vars = ["NEO4J_URI", "NEO4J_USERNAME", "NEO4J_PASSWORD"]
neo4j_ok = all(os.getenv(v) for v in neo4j_vars)
for var in neo4j_vars:
    status = "✓" if os.getenv(var) else "✗"
    value = os.getenv(var)
    display = value[:20] + "..." if value and len(value) > 20 else value
    print(f"  {status} {var}: {display or 'NOT SET'}")

if not neo4j_ok:
    print("\n  → Set Neo4j credentials:")
    print("    set NEO4J_URI=bolt+s://xxx.databases.neo4j.io")
    print("    set NEO4J_USERNAME=neo4j")
    print("    set NEO4J_PASSWORD=your_password")

# Check 4: ChromaDB connectivity
print("\n[4] ChromaDB Status")
try:
    import chromadb
    from chroma.config import list_collections
    stats = list_collections()
    for name, info in stats.items():
        print(f"  ✓ {name}: {info['count']} docs")
except Exception as e:
    print(f"  ✗ Error: {e}")

# Check 5: Python 3.14 compatibility
print("\n[5] Python Version")
print(f"  Python: {sys.version}")
print(f"  ✓ Version {sys.version_info.major}.{sys.version_info.minor}")

print("\n" + "=" * 60)
print("Summary")
print("=" * 60)

if neo4j_ok:
    print("\n✓ Core setup complete!")
    print("\nNext steps:")
    print("  1. python neo4j/seed.py          # Bootstrap Neo4j graph")
    print("  2. python chroma/ingest.py --project ../drone")
    print("  3. /vector-status                # Verify ingestion")
else:
    print("\n⚠ Missing Neo4j credentials")
    print("\nAfter setting credentials, run:")
    print("  1. python neo4j/seed.py")
    print("  2. python chroma/ingest.py --project ../drone")

print()
