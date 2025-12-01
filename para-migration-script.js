#!/usr/bin/env node

/**
 * PARA Migration Script for SiYuan Cortex
 * Migrates 314 documents from 6 legacy notebooks to PARA structure
 *
 * Strategy: Export MD → Create in target → Delete source (moveDocs API broken)
 */

const API_BASE = 'https://cortex.aienablement.academy';
const API_TOKEN = '0fkvtzw0jrat2oht';

// Migration Map
const MIGRATIONS = [
  {
    source: '20251103053955-h52lp56',
    sourceName: 'Growth Experiments',
    target: '20251201183343-543piyt',
    targetName: 'Areas',
    targetPath: '/Growth-Experiments',
    count: 8
  },
  {
    source: '20251103053916-bq6qbgu',
    sourceName: 'Agents',
    target: '20251201183343-543piyt',
    targetName: 'Areas',
    targetPath: '/Agents',
    count: 101
  },
  {
    source: '20251103053906-ivmb3mg',
    sourceName: 'Ops Runbooks',
    target: '20251201183343-543piyt',
    targetName: 'Areas',
    targetPath: '/Ops-Runbooks',
    count: 9
  },
  {
    source: '20251103053840-moamndp',
    sourceName: 'Knowledge Base',
    target: '20251201183343-ujsixib',
    targetName: 'Resources',
    targetPath: '/Knowledge-Base',
    count: 90
  },
  {
    source: '20251103053932-xwbuvts',
    sourceName: 'Tools & Scripts',
    target: '20251201183343-ujsixib',
    targetName: 'Resources',
    targetPath: '/Tools-Scripts',
    count: 13
  },
  {
    source: '20251103053911-8ex6uns',
    sourceName: 'Projects (Legacy)',
    target: '20251201183343-xf2snc8',
    targetName: 'Projects',
    targetPath: '/Active-Projects',
    count: 93
  }
];

async function siyuanRequest(endpoint, payload = {}) {
  const response = await fetch(`${API_BASE}${endpoint}`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${API_TOKEN}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(payload)
  });
  return response.json();
}

async function getDocumentList(notebookId) {
  const result = await siyuanRequest('/api/query/sql', {
    stmt: `SELECT id, content FROM blocks WHERE type='d' AND box='${notebookId}' ORDER BY created ASC`
  });
  return result.data || [];
}

async function exportMarkdown(docId) {
  const result = await siyuanRequest('/api/export/exportMdContent', {
    id: docId
  });
  return result.data;
}

async function createDocument(notebook, path, title, markdown) {
  const result = await siyuanRequest('/api/filetree/createDocWithMd', {
    notebook,
    path: `${path}/${title}`,
    markdown
  });
  return result.data; // Returns new document ID
}

async function deleteDocument(notebookId, docPath) {
  const result = await siyuanRequest('/api/filetree/removeDoc', {
    notebook: notebookId,
    path: docPath
  });
  return result;
}

async function migrateDocument(doc, migration) {
  console.log(`  → Migrating: ${doc.content} (${doc.id})`);

  try {
    // 1. Export markdown
    const mdData = await exportMarkdown(doc.id);
    if (!mdData || !mdData.content) {
      console.error(`    ✗ Failed to export ${doc.id}`);
      return { success: false, id: doc.id, error: 'Export failed' };
    }

    // 2. Create in target notebook
    const newDocId = await createDocument(
      migration.target,
      migration.targetPath,
      doc.content || 'Untitled',
      mdData.content
    );

    if (!newDocId) {
      console.error(`    ✗ Failed to create ${doc.id} in target`);
      return { success: false, id: doc.id, error: 'Create failed' };
    }

    console.log(`    ✓ Created ${newDocId} in ${migration.targetName}`);

    // 3. Delete from source (optional - comment out for safety during testing)
    // await deleteDocument(migration.source, `/${doc.id}.sy`);

    return { success: true, oldId: doc.id, newId: newDocId };
  } catch (error) {
    console.error(`    ✗ Error migrating ${doc.id}:`, error.message);
    return { success: false, id: doc.id, error: error.message };
  }
}

async function migrateBatch(migration) {
  console.log(`\n📦 ${migration.sourceName} → ${migration.targetName}`);
  console.log(`   Expected: ${migration.count} documents`);

  const docs = await getDocumentList(migration.source);
  console.log(`   Found: ${docs.length} documents`);

  const results = {
    total: docs.length,
    success: 0,
    failed: 0,
    errors: []
  };

  for (const doc of docs) {
    const result = await migrateDocument(doc, migration);
    if (result.success) {
      results.success++;
    } else {
      results.failed++;
      results.errors.push(result);
    }

    // Rate limiting: 100ms between operations
    await new Promise(resolve => setTimeout(resolve, 100));
  }

  console.log(`   ✓ Success: ${results.success}`);
  console.log(`   ✗ Failed: ${results.failed}`);

  return results;
}

async function runMigration() {
  console.log('🚀 Starting PARA Migration');
  console.log('==========================\n');

  const summary = {
    totalDocs: 0,
    successDocs: 0,
    failedDocs: 0,
    batches: []
  };

  for (const migration of MIGRATIONS) {
    const result = await migrateBatch(migration);
    summary.totalDocs += result.total;
    summary.successDocs += result.success;
    summary.failedDocs += result.failed;
    summary.batches.push({
      name: migration.sourceName,
      ...result
    });
  }

  console.log('\n\n📊 MIGRATION SUMMARY');
  console.log('====================');
  console.log(`Total Documents: ${summary.totalDocs}`);
  console.log(`✓ Migrated: ${summary.successDocs} (${(summary.successDocs/summary.totalDocs*100).toFixed(1)}%)`);
  console.log(`✗ Failed: ${summary.failedDocs}`);

  if (summary.failedDocs > 0) {
    console.log('\n⚠️  Failed Migrations:');
    summary.batches.forEach(batch => {
      if (batch.failed > 0) {
        console.log(`\n${batch.name}:`);
        batch.errors.forEach(err => {
          console.log(`  - ${err.id}: ${err.error}`);
        });
      }
    });
  }

  console.log('\n✅ Migration Complete!');
  console.log('\nNext steps:');
  console.log('1. Verify documents in target notebooks');
  console.log('2. Uncomment delete logic in script');
  console.log('3. Re-run to delete source documents');
  console.log('4. Delete empty legacy notebooks');
}

// Execute
runMigration().catch(console.error);
