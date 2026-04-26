"""Pydantic models for Vector 2.0 system."""

from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field


class ChunkMetadata(BaseModel):
    """Metadata for a document chunk."""
    project: str
    file_path: str
    chunk_type: str  # "function", "class", "docstring", "code", "markdown"
    line_start: int
    line_end: int
    language: str  # "python", "typescript", "cpp", etc.


class SearchResult(BaseModel):
    """Result from ChromaDB semantic search."""
    text: str
    metadata: ChunkMetadata
    similarity_score: float
    document_id: str


class ProjectNode(BaseModel):
    """Neo4j Project node."""
    name: str
    path: str
    language: str
    status: str  # "active", "archived", "planned"
    github_url: Optional[str] = None
    description: Optional[str] = None


class FileNode(BaseModel):
    """Neo4j File node."""
    path: str
    name: str
    ext: str
    project: str
    size_bytes: int


class FunctionNode(BaseModel):
    """Neo4j Function node."""
    name: str
    file_path: str
    line_start: int
    line_end: int
    signature: Optional[str] = None


class ConceptNode(BaseModel):
    """Neo4j Concept node."""
    name: str
    description: Optional[str] = None
    domain: Optional[str] = None  # "robotics", "ai", "backend", etc.
