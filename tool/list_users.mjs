#!/usr/bin/env node
// Lists every account with its role, status and sign-in providers.
//
//   export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.secrets/nearkart-admin.json"
//   node tool/list_users.mjs
//
// Pass --markdown to print a table that can be pasted into docs/users.md.

import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

const PROJECT_ID = process.env.FIREBASE_PROJECT_ID ?? 'nearkart007-app';
const asMarkdown = process.argv.includes('--markdown');

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('\n✖ GOOGLE_APPLICATION_CREDENTIALS is not set.\n');
  process.exit(1);
}

initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });

const auth = getAuth();
const db = getFirestore();

const { users } = await auth.listUsers(1000);
const docs = await db.collection('users').get();
const profiles = new Map(docs.docs.map((doc) => [doc.id, doc.data()]));

const rows = users
  .map((user) => {
    const profile = profiles.get(user.uid) ?? {};
    return {
      name: profile.name || user.displayName || '—',
      email: user.email ?? '—',
      phone: profile.phone || '—',
      role: profile.role ?? 'unset',
      status: profile.status ?? 'unset',
      providers: user.providerData.map((p) => p.providerId).join(', ') || '—',
      uid: user.uid,
      created: user.metadata.creationTime,
    };
  })
  .sort((a, b) => a.role.localeCompare(b.role) || a.email.localeCompare(b.email));

// Flag any Firestore profile with no matching Auth account.
const orphans = [...profiles.keys()].filter(
  (uid) => !users.some((user) => user.uid === uid),
);

if (asMarkdown) {
  console.log('| Name | Email | Role | Status | Sign-in | UID |');
  console.log('| --- | --- | --- | --- | --- | --- |');
  for (const row of rows) {
    console.log(
      `| ${row.name} | ${row.email} | \`${row.role}\` | ${row.status} | ` +
        `${row.providers} | \`${row.uid}\` |`,
    );
  }
} else {
  console.table(rows);
}

console.log(`\n${rows.length} account(s).`);
if (orphans.length > 0) {
  console.log(`⚠ Firestore profiles with no Auth account: ${orphans.join(', ')}`);
}
