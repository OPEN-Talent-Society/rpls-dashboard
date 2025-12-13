#!/usr/bin/env python3
"""
Smart Content Chunker - Content-type aware chunking with boundary detection

Handles code, markdown, transcriptions, and generic text with intelligent
boundary detection to avoid splitting mid-sentence or mid-function.
"""

import sys
import json
import re
import hashlib
from typing import List, Dict, Tuple, Optional
from dataclasses import dataclass


@dataclass
class ChunkConfig:
    """Configuration for different content types"""
    max_size: int
    overlap: int
    min_chunk_size: int = 100


# Content type configurations
CHUNK_CONFIGS = {
    "code": ChunkConfig(max_size=1500, overlap=200),
    "markdown": ChunkConfig(max_size=2000, overlap=300),
    "transcript": ChunkConfig(max_size=3000, overlap=500),
    "transcription": ChunkConfig(max_size=3000, overlap=500),
    "text": ChunkConfig(max_size=2000, overlap=300),
    "default": ChunkConfig(max_size=2000, overlap=300),
}

# Boundary patterns
SENTENCE_ENDERS = [". ", "! ", "? ", ".\n", "!\n", "?\n"]
CODE_BOUNDARIES = [
    r"\n(def\s+\w+)",  # Python function
    r"\n(class\s+\w+)",  # Python class
    r"\n(function\s+\w+)",  # JavaScript function
    r"\n(export\s+(const|function|class)\s+\w+)",  # ES6 exports
    r"\n(public|private|protected)\s+(class|interface|enum)",  # TypeScript/Java
    r"\n(//\s*=+)",  # Comment separators
    r"\n(/\*\*)",  # JSDoc comments
]
MARKDOWN_HEADINGS = r"^(#{1,6}\s+.+)$"
TRANSCRIPT_MARKERS = [
    r"\n(\[\d{2}:\d{2}:\d{2}\])",  # Timestamp [00:00:00]
    r"\n(\d{2}:\d{2}:\d{2})",  # Timestamp 00:00:00
    r"\n([A-Z][a-z]+:)",  # Speaker: format
    r"\n(Speaker \d+:)",  # Speaker 1: format
]


def compute_hash(content: str) -> str:
    """Generate SHA256 hash for content deduplication"""
    return hashlib.sha256(content.encode("utf-8")).hexdigest()


def detect_content_type(content: str, declared_type: Optional[str] = None) -> str:
    """
    Detect content type from content or use declared type.

    Args:
        content: Text content to analyze
        declared_type: Explicitly declared content type

    Returns:
        Detected or declared content type
    """
    if declared_type and declared_type.lower() in CHUNK_CONFIGS:
        return declared_type.lower()

    # Heuristic detection
    if re.search(r"^(def|class|function|import|export)\s+", content, re.MULTILINE):
        return "code"
    if re.search(r"^#{1,6}\s+", content, re.MULTILINE):
        return "markdown"
    if re.search(r"\[\d{2}:\d{2}:\d{2}\]|Speaker \d+:", content):
        return "transcript"

    return "text"


def find_sentence_boundary(text: str, position: int, direction: str = "backward") -> int:
    """
    Find nearest sentence boundary from position.

    Args:
        text: Text to search
        position: Starting position
        direction: "backward" or "forward"

    Returns:
        Position of nearest sentence boundary
    """
    if direction == "backward":
        # Search backward for sentence ender
        search_start = max(0, position - 200)
        search_text = text[search_start:position]

        for ender in SENTENCE_ENDERS:
            last_pos = search_text.rfind(ender)
            if last_pos != -1:
                return search_start + last_pos + len(ender)

        # Fallback to newline
        last_newline = search_text.rfind("\n")
        if last_newline != -1:
            return search_start + last_newline + 1

    else:  # forward
        # Search forward for sentence ender
        search_end = min(len(text), position + 200)
        search_text = text[position:search_end]

        for ender in SENTENCE_ENDERS:
            first_pos = search_text.find(ender)
            if first_pos != -1:
                return position + first_pos + len(ender)

        # Fallback to newline
        first_newline = search_text.find("\n")
        if first_newline != -1:
            return position + first_newline + 1

    return position


def find_code_boundary(text: str, position: int) -> int:
    """
    Find nearest code boundary (function/class declaration).

    Args:
        text: Code text to search
        position: Starting position

    Returns:
        Position of nearest code boundary
    """
    search_start = max(0, position - 300)
    search_text = text[search_start:position]

    best_pos = position

    for pattern in CODE_BOUNDARIES:
        matches = list(re.finditer(pattern, search_text, re.MULTILINE))
        if matches:
            # Get last match before position
            match = matches[-1]
            candidate = search_start + match.start()
            if candidate > best_pos - position:
                best_pos = candidate

    # Fallback to double newline (paragraph break)
    double_newline = search_text.rfind("\n\n")
    if double_newline != -1:
        candidate = search_start + double_newline + 2
        if candidate > best_pos:
            best_pos = candidate

    return best_pos if best_pos != position else find_sentence_boundary(text, position)


def find_markdown_boundary(text: str, position: int) -> int:
    """
    Find nearest markdown boundary (heading).

    Args:
        text: Markdown text to search
        position: Starting position

    Returns:
        Position of nearest heading or sentence boundary
    """
    search_start = max(0, position - 300)
    search_text = text[search_start:position]

    # Find last heading before position
    matches = list(re.finditer(MARKDOWN_HEADINGS, search_text, re.MULTILINE))
    if matches:
        match = matches[-1]
        return search_start + match.start()

    # Fallback to sentence boundary
    return find_sentence_boundary(text, position)


def find_transcript_boundary(text: str, position: int) -> int:
    """
    Find nearest transcript boundary (speaker turn, timestamp).

    Args:
        text: Transcript text to search
        position: Starting position

    Returns:
        Position of nearest speaker/timestamp boundary
    """
    search_start = max(0, position - 400)
    search_text = text[search_start:position]

    best_pos = position

    for pattern in TRANSCRIPT_MARKERS:
        matches = list(re.finditer(pattern, search_text, re.MULTILINE))
        if matches:
            match = matches[-1]
            candidate = search_start + match.start()
            if candidate > best_pos - position:
                best_pos = candidate

    # Fallback to sentence boundary
    if best_pos == position:
        return find_sentence_boundary(text, position)

    return best_pos


def find_boundary(text: str, position: int, content_type: str) -> int:
    """
    Find appropriate boundary based on content type.

    Args:
        text: Text content
        position: Target position
        content_type: Type of content

    Returns:
        Adjusted position at appropriate boundary
    """
    if content_type == "code":
        return find_code_boundary(text, position)
    elif content_type == "markdown":
        return find_markdown_boundary(text, position)
    elif content_type in ["transcript", "transcription"]:
        return find_transcript_boundary(text, position)
    else:
        return find_sentence_boundary(text, position)


def chunk_content(
    content: str,
    content_type: str,
    metadata: Optional[Dict] = None
) -> List[Dict]:
    """
    Chunk content intelligently based on type and boundaries.

    Args:
        content: Text content to chunk
        content_type: Type of content
        metadata: Optional metadata to include in chunks

    Returns:
        List of chunk dictionaries
    """
    # Get configuration for content type
    config = CHUNK_CONFIGS.get(content_type, CHUNK_CONFIGS["default"])

    # Short content - no chunking needed
    if len(content) < 500:
        return [{
            "text": content,
            "index": 0,
            "total": 1,
            "content_type": content_type,
            "metadata": metadata or {},
            "hash": compute_hash(content),
            "char_count": len(content),
        }]

    chunks = []
    start = 0

    while start < len(content):
        # Calculate end position
        end = min(start + config.max_size, len(content))

        # Adjust end to boundary if not at actual end
        if end < len(content):
            end = find_boundary(content, end, content_type)

        # Extract chunk
        chunk_text = content[start:end].strip()

        if chunk_text:  # Only add non-empty chunks
            chunks.append({
                "text": chunk_text,
                "index": len(chunks),
                "total": 0,  # Will update after loop
                "content_type": content_type,
                "metadata": metadata or {},
                "hash": compute_hash(chunk_text),
                "char_count": len(chunk_text),
                "start_pos": start,
                "end_pos": end,
            })

        # Move start position (with overlap)
        start = max(start + 1, end - config.overlap)

    # Update total count
    total = len(chunks)
    for chunk in chunks:
        chunk["total"] = total

    return chunks


def main():
    """Main entry point - reads JSON from stdin, outputs chunks to stdout"""
    try:
        # Read input from stdin
        input_data = json.load(sys.stdin)

        # Extract fields
        content = input_data.get("content", "")
        declared_type = input_data.get("content_type")
        metadata = input_data.get("metadata", {})

        if not content:
            print(json.dumps({
                "error": "No content provided",
                "chunks": []
            }), file=sys.stdout)
            sys.exit(1)

        # Detect content type
        content_type = detect_content_type(content, declared_type)

        # Chunk content
        chunks = chunk_content(content, content_type, metadata)

        # Output results
        result = {
            "success": True,
            "content_type": content_type,
            "chunk_count": len(chunks),
            "total_chars": len(content),
            "chunks": chunks
        }

        print(json.dumps(result, indent=2), file=sys.stdout)
        sys.exit(0)

    except json.JSONDecodeError as e:
        error_result = {
            "success": False,
            "error": f"Invalid JSON input: {str(e)}",
            "chunks": []
        }
        print(json.dumps(error_result), file=sys.stdout)
        sys.exit(1)

    except Exception as e:
        error_result = {
            "success": False,
            "error": f"Chunking failed: {str(e)}",
            "chunks": []
        }
        print(json.dumps(error_result), file=sys.stdout)
        sys.exit(1)


if __name__ == "__main__":
    main()
