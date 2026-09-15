#!/usr/bin/env node
// Sets a user's role and account status.
//
//   export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.secrets/nearkart-admin.json"
//   node tool/set_role.mjs <email> <role> [status]
//
//   node tool/set_role.mjs saroja.vvce@gmail.com storeManager active

import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

const ROLES = ['customer', 'storeManager', 'admin', 'deliveryPartner'];
const STATUSES = ['active', 'pending', 'rejected'];

const PROJECT_ID = process.env.FIREBASE_PROJECT_ID ?? 'nearkart007-app';
const [email, role, status = 'active'] = process.argv.slice(2);

function fail(message) {
  console.error(`\n✖ ${message}\n`);
  process.exit(1);
}

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  fail('GOOGLE_APPLICATION_CREDENTIALS is not set.');
}
if (!email || !role) {
  fail('Usage: node tool/set_role.mjs <email> <role> [status]');
}
if (!ROLES.includes(role)) {
  fail(`Role must be one of: ${ROLES.join(', ')}`);
}
if (!STATUSES.includes(status)) {
  fail(`Status must be one of: ${STATUSES.join(', ')}`);
}

initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });

const auth = getAuth();
const db = getFirestore();

let user;
try {
  user = await auth.getUserByEmail(email);
} catch (error) {
  if (error.code === 'auth/user-not-found') {
    fail(`No account exists for ${email}.`);
  }
  throw error;
}

const ref = db.collection('users').doc(user.uid);
const before = (await ref.get()).data();

await ref.set(
  {
    name: before?.name ?? user.displayName ?? '',
    email: user.email,
    role,
    status,
    updatedAt: FieldValue.serverTimestamp(),
  },
  { merge: true },
);

console.log(
  `\n✔ ${email}\n` +
    `  role   : ${before?.role ?? 'unset'} → ${role}\n` +
    `  status : ${before?.status ?? 'unset'} → ${status}\n`,
);
