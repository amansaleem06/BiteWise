#!/usr/bin/env node
/*
 * Fill missing legacy user fields and create missing publicProfiles/{uid}.
 * Dry-run is the default. The script only adds missing private fields and
 * creates missing public profiles. The existing profile Cloud Function may
 * subsequently refresh a public projection from its private source.
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
const requiredDefaults = {
  messagePrivacy: 'everyone',
  followerCount: 0,
  followingCount: 0,
  postCount: 0,
  emailVerified: false,
};
const requiredSourceFields = ['email', 'displayName', 'role', 'createdAt', 'updatedAt'];

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
  let missing = 0;
  let legacy = 0;
  let written = 0;
  do {
    let query = db.collection('users').orderBy(FieldPath.documentId()).limit(400);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    if (page.empty) break;
    scanned += page.size;
    const publicRefs = page.docs.map(doc => db.doc(`publicProfiles/${doc.id}`));
    const existing = await db.getAll(...publicRefs);
    for (let i = 0; i < page.docs.length; i++) {
      const source = page.docs[i].data();
      const absentSourceFields = requiredSourceFields.filter(key => source[key] === undefined);
      if (absentSourceFields.length) {
        throw new Error(`${page.docs[i].id} is missing ${absentSourceFields.join(',')}; inspect manually before applying`);
      }
      const additions = Object.fromEntries(
        Object.entries(requiredDefaults).filter(([key]) => source[key] === undefined),
      );
      if (source.messagePrivacy === undefined && existing[i].exists) {
        additions.messagePrivacy = existing[i].data().messagePrivacy || 'everyone';
      }
      if (source.displayNameLower === undefined) {
        additions.displayNameLower = source.displayName.toLowerCase();
      }
      if (Object.keys(additions).length) legacy++;
      if (!existing[i].exists) missing++;
      if (Object.keys(additions).length || !existing[i].exists) {
        console.log(`${page.docs[i].id}: ${Object.keys(additions).length ? `add ${Object.keys(additions).join(',')}` : 'no private changes'}; ${existing[i].exists ? 'public exists' : 'create public'}`);
      }
      if (apply) {
        let created = false;
        await db.runTransaction(async transaction => {
          created = false;
          const privateDoc = await transaction.get(page.docs[i].ref);
          const publicDoc = await transaction.get(publicRefs[i]);
          if (!privateDoc.exists) return;
          const current = privateDoc.data();
          const currentAdditions = Object.fromEntries(
            Object.entries(requiredDefaults).filter(([key]) => current[key] === undefined),
          );
          if (current.messagePrivacy === undefined && publicDoc.exists) {
            currentAdditions.messagePrivacy = publicDoc.data().messagePrivacy || 'everyone';
          }
          if (current.displayNameLower === undefined) {
            currentAdditions.displayNameLower = current.displayName.toLowerCase();
          }
          if (Object.keys(currentAdditions).length) transaction.update(privateDoc.ref, currentAdditions);
          if (!publicDoc.exists) {
            transaction.create(publicRefs[i], publicProfile({ ...current, ...currentAdditions }));
            created = true;
          }
        });
        if (created) written++;
      }
    }
    cursor = page.docs.at(-1);
  } while (cursor);
  console.log(`Scanned ${scanned} users; ${legacy} legacy private records; ${missing} missing public profiles; ${apply ? `created ${written}` : 'dry run only'} in ${projectId}.`);
}

main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
