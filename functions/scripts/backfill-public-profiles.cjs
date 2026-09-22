#!/usr/bin/env node
/*
 * Backfill users/{uid} -> publicProfiles/{uid}. Dry-run is the default.
 *
 * node scripts/backfill-public-profiles.cjs --project bitewise-1d266
 * node scripts/backfill-public-profiles.cjs --project bitewise-1d266 --apply
 *
 * Uses Application Default Credentials; this file contains no credentials.
 */
const { applicationDefault, initializeApp } = require('firebase-admin/app');
const { FieldPath, getFirestore } = require('firebase-admin/firestore');

const args = process.argv.slice(2);
const projectIndex = args.indexOf('--project');
const projectId = projectIndex >= 0 ? args[projectIndex + 1] : undefined;
const apply = args.includes('--apply');

if (!projectId || projectId.startsWith('--')) {
  console.error('Usage: node scripts/backfill-public-profiles.cjs --project PROJECT_ID [--apply]');
  process.exit(2);
}

initializeApp({ credential: applicationDefault(), projectId });
const db = getFirestore();
const publicFields = [
  'displayName', 'displayNameLower', 'username', 'usernameLower', 'photoUrl',
  'bio', 'role', 'businessName', 'businessVerificationStatus',
  'ownedRestaurantId', 'messagePrivacy', 'followerCount', 'followingCount',
  'postCount', 'suspended', 'createdAt', 'updatedAt',
];

function publicProfile(data) {
  return Object.fromEntries(
    publicFields
      .filter(key => data[key] !== undefined)
      .map(key => [key, data[key]]),
  );
}

async function main() {
  let cursor;
  let scanned = 0;
  let written = 0;
  do {
    let query = db.collection('users').orderBy(FieldPath.documentId()).limit(400);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    if (page.empty) break;
    scanned += page.size;
    if (apply) {
      const batch = db.batch();
      for (const doc of page.docs) {
        batch.set(db.doc(`publicProfiles/${doc.id}`), publicProfile(doc.data()));
      }
      await batch.commit();
      written += page.size;
    }
    cursor = page.docs.at(-1);
    console.log(`${apply ? 'Applied' : 'Would write'} ${scanned} public profiles so far.`);
  } while (cursor);
  console.log(`${apply ? `Wrote ${written}` : `Dry run: would write ${scanned}`} public profiles in ${projectId}.`);
}

main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
