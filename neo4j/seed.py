"""Bootstrap Neo4j knowledge graph from filesystem + AutoForge registry."""

import sys
import os
from pathlib import Path
from datetime import datetime
import json

# Neo4j driver
from neo4j import GraphDatabase

# Check if Neo4j credentials are set
NEO4J_URI = os.getenv("NEO4J_URI")
NEO4J_USERNAME = os.getenv("NEO4J_USERNAME")
NEO4J_PASSWORD = os.getenv("NEO4J_PASSWORD")

if not all([NEO4J_URI, NEO4J_USERNAME, NEO4J_PASSWORD]):
    print("ERROR: Neo4j credentials not set. Please set:")
    print("  - NEO4J_URI")
    print("  - NEO4J_USERNAME")
    print("  - NEO4J_PASSWORD")
    print("\nExample:")
    print("  set NEO4J_URI=bolt+s://xxx.databases.neo4j.io")
    print("  set NEO4J_USERNAME=neo4j")
    print("  set NEO4J_PASSWORD=your_password")
    sys.exit(1)


def get_driver():
    """Create and return Neo4j driver."""
    try:
        driver = GraphDatabase.driver(
            NEO4J_URI,
            auth=(NEO4J_USERNAME, NEO4J_PASSWORD)
        )
        driver.verify_connectivity()
        return driver
    except Exception as e:
        print(f"ERROR: Failed to connect to Neo4j: {e}")
        sys.exit(1)


def create_project_node(tx, project_name: str, project_path: str, language: str, status: str = "active"):
    """Create or update a Project node."""
    query = """
    MERGE (p:Project {name: $name})
    SET p.path = $path,
        p.language = $language,
        p.status = $status,
        p.updated_at = datetime()
    RETURN p
    """
    tx.run(query, name=project_name, path=project_path, language=language, status=status)


def create_file_nodes(tx, project_name: str, project_dir: str):
    """Create File nodes for a project."""
    project_path = Path(project_dir).resolve()

    skip_dirs = {'.git', 'node_modules', '__pycache__', 'venv', '.venv', 'dist', 'build'}

    file_count = 0
    for file_path in project_path.rglob("*"):
        if file_path.is_file():
            # Skip certain directories
            if any(skip in file_path.parts for skip in skip_dirs):
                continue

            try:
                size_bytes = file_path.stat().st_size
                ext = file_path.suffix

                query = """
                MERGE (f:File {path: $path, project: $project})
                SET f.name = $name,
                    f.ext = $ext,
                    f.size_bytes = $size_bytes,
                    f.updated_at = datetime()
                WITH f
                MATCH (p:Project {name: $project})
                MERGE (p)-[:CONTAINS]->(f)
                """

                tx.run(
                    query,
                    path=str(file_path.relative_to(project_path.parent)),
                    project=project_name,
                    name=file_path.name,
                    ext=ext,
                    size_bytes=size_bytes
                )
                file_count += 1
            except Exception as e:
                print(f"  [WARN] Error processing {file_path.name}: {e}")

    return file_count


def create_concept_nodes(tx):
    """Create default Concept nodes."""
    concepts = [
        ("MAVLink", "Communication protocol for drones", "robotics"),
        ("PID Control", "Proportional-Integral-Derivative feedback loop", "control"),
        ("YOLO", "Real-time object detection", "cv"),
        ("NATS", "Message-oriented middleware", "backend"),
        ("FastAPI", "Modern Python web framework", "backend"),
        ("Neo4j", "Graph database", "database"),
        ("ChromaDB", "Vector database for embeddings", "database"),
    ]

    for name, description, domain in concepts:
        query = """
        MERGE (c:Concept {name: $name})
        SET c.description = $description,
            c.domain = $domain
        """
        tx.run(query, name=name, description=description, domain=domain)

    return len(concepts)


def bootstrap_projects(driver, projects: list[dict]):
    """
    Bootstrap multiple projects into graph.

    projects: [{"name": "drone", "path": "/path/to/drone", "language": "python"}]
    """
    total_files = 0

    for proj in projects:
        name = proj["name"]
        path = proj["path"]
        language = proj.get("language", "mixed")

        print(f"\n  Creating project node: {name}")
        with driver.session() as session:
            session.write_transaction(create_project_node, name, path, language)

        # Create file nodes
        print(f"  Scanning files in {name}...")
        with driver.session() as session:
            file_count = create_file_nodes(session, name, path)
            total_files += file_count
        print(f"    Created {file_count} file nodes")

    return total_files


def seed_graph(driver):
    """Main seeding function."""
    print("="*60)
    print("Seeding Neo4j Knowledge Graph")
    print("="*60)

    # Create default concepts
    print("\nCreating concept nodes...")
    with driver.session() as session:
        concept_count = session.write_transaction(create_concept_nodes)
    print(f"  Created {concept_count} concept nodes")

    # Bootstrap priority projects (customize as needed)
    projects_to_ingest = [
        {
            "name": "drone",
            "path": "C:/Users/patrick/Documents/drone",
            "language": "python"
        },
    ]

    # Only ingest if paths exist
    projects = [p for p in projects_to_ingest if Path(p["path"]).exists()]

    if projects:
        total_files = bootstrap_projects(driver, projects)
        print(f"\n  Total file nodes created: {total_files}")
    else:
        print("\nNo projects found to ingest (check paths)")

    # Print summary
    with driver.session() as session:
        result = session.run("MATCH (n) RETURN labels(n) as label, count(*) as count")
        print("\n" + "="*60)
        print("Graph Summary:")
        print("="*60)
        for record in result:
            label = record["label"][0] if record["label"] else "unknown"
            count = record["count"]
            print(f"  {label}: {count}")


def main():
    driver = get_driver()
    try:
        seed_graph(driver)
        print("\n✓ Seeding complete!")
    finally:
        driver.close()


if __name__ == "__main__":
    main()
