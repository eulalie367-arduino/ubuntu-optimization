"""Code-aware text chunking for Vector 2.0."""

import ast
import re
from typing import List, Tuple, Optional
from dataclasses import dataclass


@dataclass
class Chunk:
    """A text chunk with metadata."""
    text: str
    chunk_type: str  # "function", "class", "docstring", "code", "markdown"
    line_start: int
    line_end: int


def chunk_python_file(content: str, filename: str = "unknown.py") -> List[Chunk]:
    """
    Parse Python file and extract function/class definitions as chunks.
    Fallback to sliding window if AST parsing fails.
    """
    chunks = []
    lines = content.split("\n")

    try:
        tree = ast.parse(content)

        for node in ast.walk(tree):
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                # Extract function chunk
                func_content = "\n".join(
                    lines[node.lineno - 1 : node.end_lineno]
                )
                chunks.append(Chunk(
                    text=func_content,
                    chunk_type="function",
                    line_start=node.lineno,
                    line_end=node.end_lineno,
                ))
            elif isinstance(node, ast.ClassDef):
                # Extract class chunk
                class_content = "\n".join(
                    lines[node.lineno - 1 : node.end_lineno]
                )
                chunks.append(Chunk(
                    text=class_content,
                    chunk_type="class",
                    line_start=node.lineno,
                    line_end=node.end_lineno,
                ))
    except SyntaxError:
        # Fallback: split by double newlines
        pass

    # If no chunks found (e.g., empty file or parse failure), use sliding window
    if not chunks:
        chunks = _sliding_window_chunks(content)

    return chunks


def _sliding_window_chunks(content: str, window_size: int = 512, overlap: int = 50) -> List[Chunk]:
    """
    Fallback: split content into overlapping chunks of ~512 tokens.
    Assumes ~4 chars per token.
    """
    chunks = []
    char_per_token = 4
    char_window = window_size * char_per_token
    char_overlap = overlap * char_per_token

    lines = content.split("\n")
    current_chunk = []
    current_size = 0
    line_start = 1

    for i, line in enumerate(lines):
        current_chunk.append(line)
        current_size += len(line) + 1  # +1 for newline

        if current_size >= char_window:
            chunk_text = "\n".join(current_chunk)
            if chunk_text.strip():
                chunks.append(Chunk(
                    text=chunk_text,
                    chunk_type="code",
                    line_start=line_start,
                    line_end=i + 1,
                ))

            # Overlap: keep last few lines
            overlap_lines = max(1, len(current_chunk) // 4)
            current_chunk = current_chunk[-overlap_lines:]
            current_size = sum(len(line) + 1 for line in current_chunk)
            line_start = i + 1 - overlap_lines

    # Final chunk
    if current_chunk:
        chunk_text = "\n".join(current_chunk)
        if chunk_text.strip():
            chunks.append(Chunk(
                text=chunk_text,
                chunk_type="code",
                line_start=line_start,
                line_end=len(lines),
            ))

    return chunks


def chunk_markdown_file(content: str) -> List[Chunk]:
    """
    Split markdown by headers to create semantic chunks.
    """
    chunks = []
    lines = content.split("\n")

    current_section = []
    current_header = None
    line_start = 1

    for i, line in enumerate(lines):
        if line.startswith("#"):
            # Save previous section
            if current_section:
                section_text = "\n".join(current_section).strip()
                if section_text:
                    chunks.append(Chunk(
                        text=section_text,
                        chunk_type="markdown",
                        line_start=line_start,
                        line_end=i,
                    ))

            current_section = [line]
            current_header = line
            line_start = i + 1
        else:
            current_section.append(line)

    # Final section
    if current_section:
        section_text = "\n".join(current_section).strip()
        if section_text:
            chunks.append(Chunk(
                text=section_text,
                chunk_type="markdown",
                line_start=line_start,
                line_end=len(lines),
            ))

    return chunks


def chunk_file(content: str, file_path: str) -> List[Chunk]:
    """
    Dispatch to appropriate chunker based on file extension.
    """
    if file_path.endswith(".py"):
        return chunk_python_file(content, file_path)
    elif file_path.endswith(".md"):
        return chunk_markdown_file(content)
    elif file_path.endswith((".ts", ".tsx", ".js", ".jsx")):
        # For now, use sliding window for JS/TS
        return _sliding_window_chunks(content)
    elif file_path.endswith((".cpp", ".h", ".c")):
        # For now, use sliding window for C/C++
        return _sliding_window_chunks(content)
    else:
        # Default: sliding window
        return _sliding_window_chunks(content)
