"""Reusable Neo4j Cypher queries for Vector 2.0."""

from neo4j import GraphDatabase
from typing import List, Dict, Any
import os


class Neo4jQueries:
    """Query library for knowledge graph."""

    def __init__(self):
        uri = os.getenv("NEO4J_URI")
        username = os.getenv("NEO4J_USERNAME")
        password = os.getenv("NEO4J_PASSWORD")

        if not all([uri, username, password]):
            raise ValueError("Neo4j credentials not set in environment")

        self.driver = GraphDatabase.driver(uri, auth=(username, password))

    def get_all_projects(self) -> List[Dict[str, Any]]:
        """Fetch all Project nodes."""
        with self.driver.session() as session:
            result = session.run(
                "MATCH (p:Project) RETURN p.name as name, p.path as path, p.status as status"
            )
            return [dict(r) for r in result]

    def get_project_files(self, project_name: str) -> List[Dict[str, Any]]:
        """Get all files in a project."""
        with self.driver.session() as session:
            result = session.run(
                """
                MATCH (p:Project {name: $project})-[:CONTAINS]->(f:File)
                RETURN f.path as path, f.name as name, f.size_bytes as size_bytes
                ORDER BY f.name
                """,
                project=project_name
            )
            return [dict(r) for r in result]

    def get_graph_summary(self) -> Dict[str, int]:
        """Get counts of all node types."""
        with self.driver.session() as session:
            result = session.run(
                """
                MATCH (n)
                RETURN labels(n)[0] as label, count(*) as count
                ORDER BY label
                """
            )
            return {record["label"]: record["count"] for record in result}

    def find_related_projects(self, project_name: str) -> List[str]:
        """Find projects related to a given project."""
        with self.driver.session() as session:
            result = session.run(
                """
                MATCH (p:Project {name: $name})-[:RELATES_TO|:PART_OF]-(related:Project)
                RETURN related.name as name
                """,
                name=project_name
            )
            return [record["name"] for record in result]

    def create_relation(self, from_node: str, rel_type: str, to_node: str) -> bool:
        """Create a relationship between two nodes."""
        with self.driver.session() as session:
            session.run(
                f"""
                MATCH (a {{name: $from}})
                MATCH (b {{name: $to}})
                MERGE (a)-[:{rel_type}]->(b)
                """,
                **{"from": from_node, "to": to_node}
            )
        return True

    def close(self):
        """Close the driver."""
        self.driver.close()


if __name__ == "__main__":
    # Test queries
    try:
        queries = Neo4jQueries()

        print("Projects:")
        for proj in queries.get_all_projects():
            print(f"  {proj}")

        print("\nGraph Summary:")
        for label, count in queries.get_graph_summary().items():
            print(f"  {label}: {count}")

        queries.close()
    except Exception as e:
        print(f"Error: {e}")
