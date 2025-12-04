#!/usr/bin/env python3
"""
Migrate Qdrant points to unified schema.
Adds 'content' and 'indexed_at' fields where missing.

Per QDRANT-UNIFIED-SCHEMA.json:
- Required fields: type, source, content, indexed_at
- Episode content = task + input + output + critique combined
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

def generate_content(payload):
    """Generate content field based on type."""
    ptype = payload.get('type', '')

    if ptype == 'episode':
        # Combine task + input + output + critique
        parts = []
        if payload.get('task'):
            parts.append(f"Task: {payload['task']}")
        if payload.get('input'):
            parts.append(f"Input: {payload['input']}")
        if payload.get('output'):
            parts.append(f"Output: {payload['output']}")
        if payload.get('critique'):
            parts.append(f"Critique: {payload['critique']}")
        return '\n\n'.join(parts)

    elif ptype == 'pattern':
        parts = []
        if payload.get('name'):
            parts.append(f"Pattern: {payload['name']}")
        if payload.get('description'):
            parts.append(payload['description'])
        return '\n'.join(parts)

    elif ptype == 'memory':
        parts = []
        if payload.get('key'):
            parts.append(f"Key: {payload['key']}")
        if payload.get('value'):
            val = payload['value']
            if isinstance(val, dict):
                val = json.dumps(val)
            parts.append(f"Value: {val}")
        return '\n'.join(parts)

    elif ptype == 'code':
        parts = []
        if payload.get('filepath'):
            parts.append(f"File: {payload['filepath']}")
        if payload.get('content'):
            return payload['content']
        if payload.get('description'):
            parts.append(payload['description'])
        return '\n'.join(parts)

    return None

def generate_indexed_at(payload):
    """Generate indexed_at timestamp."""
    # Try to use existing timestamp
    if payload.get('created_at'):
        try:
            # Unix timestamp
            ts = int(payload['created_at'])
            return datetime.fromtimestamp(ts).isoformat() + 'Z'
        except:
            pass

    if payload.get('timestamp'):
        return payload['timestamp']

    # Default to now
    return datetime.utcnow().isoformat() + 'Z'

def migrate_point(point):
    """Migrate a single point to unified schema."""
    point_id = point['id']
    payload = point['payload']
    vector = point.get('vector', [])

    needs_update = False
    new_payload = payload.copy()

    # Add content if missing
    if not payload.get('content'):
        content = generate_content(payload)
        if content:
            new_payload['content'] = content
            needs_update = True

    # Add indexed_at if missing
    if not payload.get('indexed_at'):
        new_payload['indexed_at'] = generate_indexed_at(payload)
        needs_update = True

    # Add version if missing
    if not payload.get('version'):
        new_payload['version'] = 1
        needs_update = True

    if needs_update and vector:
        return {
            'id': point_id,
            'vector': vector,
            'payload': new_payload
        }

    return None

def upsert_points(points):
    """Upsert migrated points to Qdrant."""
    if not points:
        return 0

    # Batch upsert
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
    print("📊 Qdrant Schema Migration")
    print(f"   Collection: {COLLECTION}")
    print(f"   Endpoint: {QDRANT_URL}")

    # Fetch all points
    print("\n📥 Fetching all points...")
    points = scroll_all_points()
    print(f"   Found {len(points)} points")

    # Analyze and migrate
    print("\n🔄 Analyzing and migrating points...")
    migrated = []
    stats = {
        'already_compliant': 0,
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
            stats['already_compliant'] += 1

    print(f"\n📈 Migration Summary:")
    print(f"   Already compliant: {stats['already_compliant']}")
    print(f"   To migrate: {stats['migrated']}")
    print(f"   No vector (skipped): {stats['no_vector']}")

    print(f"\n📦 By Type:")
    for t, s in sorted(stats['by_type'].items()):
        print(f"   {t}: {s['migrated']}/{s['total']} migrated")

    if migrated:
        print(f"\n⬆️  Upserting {len(migrated)} migrated points...")
        result = upsert_points(migrated)
        if result > 0:
            print(f"\n✅ Migration complete! {result} points updated.")
        else:
            print(f"\n❌ Migration failed!")
            return 1
    else:
        print("\n✅ All points already compliant with unified schema!")

    return 0

if __name__ == '__main__':
    sys.exit(main())
