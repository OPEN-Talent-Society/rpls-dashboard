#!/usr/bin/env python3
"""
Migrate Qdrant points to FULLY unified schema with nested metadata.

Per QDRANT-UNIFIED-SCHEMA.json:
- Root fields: type, source, content, indexed_at, topic, category, version
- Type-specific fields go in metadata.{type} object

This ensures ALL points have the same root-level structure.
"""

import json
import os
import sys
from datetime import datetime
import requests

# Configuration
QDRANT_URL = os.environ.get('QDRANT_URL', 'https://qdrant.harbor.fyi')
QDRANT_API_KEY = os.environ.get('QDRANT_API_KEY')
COLLECTION = 'agent_memory'

if not QDRANT_API_KEY:
    print("Error: QDRANT_API_KEY not set")
    sys.exit(1)

headers = {
    'api-key': QDRANT_API_KEY,
    'Content-Type': 'application/json'
}

# Standard root-level fields (same for ALL types)
STANDARD_ROOT_FIELDS = {'type', 'source', 'content', 'indexed_at', 'topic', 'category', 'embedding_model', 'updated_at', 'version'}

# Type-specific fields that should be nested
TYPE_SPECIFIC_FIELDS = {
    'wiki': {'file_path', 'markdown_headers', 'last_modified', 'word_count'},
    'learning': {'notebook_id', 'block_id', 'tags', 'related_tasks', 'learning_type'},
    'episode': {'session_id', 'task', 'input', 'output', 'critique', 'reward', 'success', 'agentdb_id', 'created_at', 'latency_ms', 'tokens_used'},
    'pattern': {'name', 'description', 'examples', 'frequency', 'success_rate'},
    'code': {'filepath', 'language', 'repository', 'commit_sha', 'line_range'},
    'memory': {'key', 'value', 'namespace', 'ttl'},
    'decision': {'context', 'options', 'chosen', 'rationale'},
    'finding': {'severity', 'impact', 'recommendation'},
    'tool': {'tool_name', 'version', 'usage_pattern'}
}

def scroll_all_points():
    """Fetch all points from collection."""
    all_points = []
    offset = None

    while True:
        payload = {'limit': 100, 'with_payload': True, 'with_vector': True}
        if offset:
            payload['offset'] = offset

        resp = requests.post(
            f'{QDRANT_URL}/collections/{COLLECTION}/points/scroll',
            headers=headers,
            json=payload
        )
        data = resp.json()

        if 'result' not in data or not data['result']['points']:
            break

        all_points.extend(data['result']['points'])
        offset = data['result'].get('next_page_offset')

        if not offset:
            break

    return all_points

def restructure_payload(payload):
    """Restructure payload to unified schema with nested metadata."""
    ptype = payload.get('type', 'unknown')

    # Start with standard fields
    new_payload = {
        'type': ptype,
        'source': payload.get('source', 'unknown'),
        'content': payload.get('content', ''),
        'indexed_at': payload.get('indexed_at', datetime.utcnow().isoformat() + 'Z'),
        'version': payload.get('version', 1)
    }

    # Add optional standard fields if present
    if payload.get('topic'):
        new_payload['topic'] = payload['topic']
    if payload.get('category'):
        new_payload['category'] = payload['category']
    if payload.get('embedding_model'):
        new_payload['embedding_model'] = payload['embedding_model']
    if payload.get('updated_at'):
        new_payload['updated_at'] = payload['updated_at']

    # Collect type-specific fields into metadata
    type_fields = TYPE_SPECIFIC_FIELDS.get(ptype, set())
    metadata_content = {}

    for key, value in payload.items():
        if key not in STANDARD_ROOT_FIELDS and key in type_fields:
            metadata_content[key] = value

    # Only add metadata if there are type-specific fields
    if metadata_content:
        new_payload['metadata'] = {ptype: metadata_content}

    return new_payload

def migrate_point(point):
    """Migrate a single point to nested schema."""
    point_id = point['id']
    payload = point['payload']
    vector = point.get('vector', [])

    if not vector:
        return None

    # Check if already has nested metadata structure
    if 'metadata' in payload and isinstance(payload['metadata'], dict):
        ptype = payload.get('type')
        if ptype and ptype in payload['metadata']:
            # Already migrated
            return None

    # Check if has any type-specific fields at root level
    ptype = payload.get('type', 'unknown')
    type_fields = TYPE_SPECIFIC_FIELDS.get(ptype, set())

    has_root_type_fields = any(k in payload for k in type_fields)

    if not has_root_type_fields:
        # No type-specific fields to nest
        return None

    new_payload = restructure_payload(payload)

    return {
        'id': point_id,
        'vector': vector,
        'payload': new_payload
    }

def upsert_points(points):
    """Upsert migrated points to Qdrant."""
    if not points:
        return 0

    for i in range(0, len(points), 50):
        batch = points[i:i+50]
        resp = requests.put(
            f'{QDRANT_URL}/collections/{COLLECTION}/points',
            headers=headers,
            json={'points': batch}
        )
        if resp.status_code != 200:
            print(f"Error upserting batch: {resp.text}")
            return -1
        print(f"  Upserted batch {i//50 + 1}: {len(batch)} points")

    return len(points)

def main():
    print("📊 Qdrant Nested Schema Migration")
    print(f"   Collection: {COLLECTION}")
    print(f"   Endpoint: {QDRANT_URL}")
    print(f"\n   Standard root fields: {sorted(STANDARD_ROOT_FIELDS)}")

    # Fetch all points
    print("\n📥 Fetching all points...")
    points = scroll_all_points()
    print(f"   Found {len(points)} points")

    # Analyze and migrate
    print("\n🔄 Restructuring payloads to nested schema...")
    migrated = []
    stats = {
        'already_nested': 0,
        'no_type_fields': 0,
        'migrated': 0,
        'no_vector': 0,
        'by_type': {}
    }

    for p in points:
        ptype = p['payload'].get('type', 'unknown')
        stats['by_type'][ptype] = stats['by_type'].get(ptype, {'total': 0, 'migrated': 0})
        stats['by_type'][ptype]['total'] += 1

        if not p.get('vector'):
            stats['no_vector'] += 1
            continue

        result = migrate_point(p)
        if result:
            migrated.append(result)
            stats['migrated'] += 1
            stats['by_type'][ptype]['migrated'] += 1
        else:
            # Check why not migrated
            if 'metadata' in p['payload']:
                stats['already_nested'] += 1
            else:
                stats['no_type_fields'] += 1

    print(f"\n📈 Migration Summary:")
    print(f"   Already nested: {stats['already_nested']}")
    print(f"   No type-specific fields: {stats['no_type_fields']}")
    print(f"   To migrate: {stats['migrated']}")
    print(f"   No vector (skipped): {stats['no_vector']}")

    print(f"\n📦 By Type:")
    for t, s in sorted(stats['by_type'].items()):
        print(f"   {t}: {s['migrated']}/{s['total']} need restructuring")

    if migrated:
        print(f"\n⬆️  Upserting {len(migrated)} restructured points...")
        result = upsert_points(migrated)
        if result > 0:
            print(f"\n✅ Migration complete! {result} points restructured.")
        else:
            print(f"\n❌ Migration failed!")
            return 1
    else:
        print("\n✅ All points already have proper nested structure!")

    # Show sample of restructured payload
    if migrated:
        print("\n📝 Sample restructured payload:")
        sample = migrated[0]['payload']
        print(f"   Root keys: {sorted(sample.keys())}")
        if 'metadata' in sample:
            print(f"   Metadata: {sample['metadata']}")

    return 0

if __name__ == '__main__':
    sys.exit(main())
