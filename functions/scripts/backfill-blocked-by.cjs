// Add reverse indexes for existing blocks. Default: read-only dry run.
// Uses Application Default Credentials; never store a service-account key here.
const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore, FieldPath, FieldValue } = require('firebase-admin/firestore');
const args = process.argv.slice(2);
const projectId = args[args.indexOf('--project') + 1];
if (!args.includes('--project') || !projectId || projectId.startsWith('--')) {
  throw new Error('Usage: node scripts/backfill-blocked-by.cjs --project PROJECT_ID [--apply]');
}
initializeApp({ projectId, credential: applicationDefault() });
const db = getFirestore();
async function main() {
  let cursor;
  let missing = 0;
  do {
    let query = db.collectionGroup('blocked').orderBy(FieldPath.documentId()).limit(200);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    if (page.empty) break;
    for (const block of page.docs) {
      const parts = block.ref.path.split('/');
      if (parts.length !== 4 || parts[0] !== 'users') continue;
      const mirror = db.doc(`users/${block.id}/blockedBy/${parts[1]}`);
      await db.runTransaction(async transaction => {
        const [fresh, existing] = await Promise.all([transaction.get(block.ref), transaction.get(mirror)]);
        if (!fresh.exists || existing.exists) return;
        missing++;
        if (args.includes('--apply')) transaction.create(mirror, { createdAt: fresh.data().createdAt ?? FieldValue.serverTimestamp() });
      });
    }
    cursor = page.docs.at(-1);
    if (page.size < 200) break;
  } while (cursor);
  console.log(`${args.includes('--apply') ? 'Applied' : 'Dry run'}: ${missing} missing reverse block indexes.`);
}
main().catch(error => { console.error(error.message); process.exitCode = 1; });
