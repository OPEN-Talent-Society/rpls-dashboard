#!/usr/bin/env python3

"""
File Test Script for Test Skill
Tests file operations and permissions
"""

import os
import sys
import tempfile
import json
from pathlib import Path

def test_file_operations():
    """Test basic file operations"""
    results = {}

    # Test 1: Write to temporary file
    try:
        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.txt') as f:
            f.write("Test content from skill script")
            temp_file = f.name

        # Test 2: Read from file
        with open(temp_file, 'r') as f:
            content = f.read()

        if content == "Test content from skill script":
            results['file_write_read'] = "✅ Pass"
        else:
            results['file_write_read'] = "❌ Fail - content mismatch"

        # Cleanup
        os.unlink(temp_file)

    except Exception as e:
        results['file_write_read'] = f"❌ Fail - {str(e)}"

    # Test 3: Directory permissions
    try:
        test_dir = Path("/tmp/skill-test")
        test_dir.mkdir(exist_ok=True)

        test_file = test_dir / "test.txt"
        test_file.write_text("Directory test")

        if test_file.exists() and test_file.read_text() == "Directory test":
            results['directory_permissions'] = "✅ Pass"
        else:
            results['directory_permissions'] = "❌ Fail - directory operations failed"

        # Cleanup
        test_file.unlink()
        test_dir.rmdir()

    except Exception as e:
        results['directory_permissions'] = f"❌ Fail - {str(e)}"

    # Test 4: JSON operations
    try:
        test_data = {"test": "data", "number": 42}
        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.json') as f:
            json.dump(test_data, f)
            json_file = f.name

        with open(json_file, 'r') as f:
            loaded_data = json.load(f)

        if loaded_data == test_data:
            results['json_operations'] = "✅ Pass"
        else:
            results['json_operations'] = "❌ Fail - JSON data mismatch"

        # Cleanup
        os.unlink(json_file)

    except Exception as e:
        results['json_operations'] = f"❌ Fail - {str(e)}"

    return results

if __name__ == "__main__":
    print("=== File Operations Test ===")
    results = test_file_operations()

    for test, result in results.items():
        print(f"{test}: {result}")

    print("=== Test Complete ===")