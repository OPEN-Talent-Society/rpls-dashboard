# Test Skill Examples

## Example Usage Scenarios

### 1. Basic Health Check
**User request**: "Run a quick health check on our infrastructure"

**Expected response**: I'll use the test-skill to run basic connectivity and service health checks.

### 2. File Operations Testing
**User request**: "Test if file operations are working properly"

**Expected response**: Let me test file operations using the test-skill scripts.

### 3. Template Generation
**User request**: "Generate a test status report"

**Expected response**: I'll create a test report using the test-skill template.

## Sample Commands

```bash
# Run health check script
.claude/skills/test-skill/scripts/health-check.sh

# Run file operations test
python3 .claude/skills/test-skill/scripts/file-test.py

# Generate report from template
# (Variables would be: {{timestamp}}, {{test_type}}, {{status}}, etc.)
```

## Expected Outputs

### Health Check Output
```
=== Infrastructure Health Check ===
Time: Sat Oct 25 20:25:52 PDT 2025

1. Network Connectivity Tests:
   ✅ Internet connectivity
2. DNS Resolution Tests:
   ✅ wiki.aienablement.academy resolves
   ✅ ops.aienablement.academy resolves
3. HTTPS Connectivity Tests:
   ✅ Docmost health endpoint responding
   ✅ NocoDB health endpoint responding

=== Health Check Complete ===
```

### File Test Output
```
=== File Operations Test ===
file_write_read: ✅ Pass
directory_permissions: ✅ Pass
json_operations: ✅ Pass
=== Test Complete ===
```