#!/usr/bin/env node
// Gives an account an email/password sign-in method for testing, creating the
// account if it does not exist yet.
//
// The password is NEVER written to this repository. Supply your own through
// TEST_PASSWORD, or let the script generate a random one and print it once.
//
//   export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.secrets/nearkart-admin.json"
//   node tool/set_password.mjs <email> [role] [status]

import { randomBytes } from 'node:crypto';
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

const ROLES = ['customer', 'storeManager', 'admin', 'deliveryPartner'];
const PROJECT_ID = process.env.FIREBASE_PROJECT_ID ?? 'nearkart007-app';
const [email, role, status = 'active'] = process.argv.slice(2);

function fail(message) {
  console.error(`\n✖ ${message}\n`);
  process.exit(1);
}

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  fail('GOOGLE_APPLICATION_CREDENTIALS is not set.');
}
if (!email) {
  fail('Usage: node tool/set_password.mjs <email> [role] [status]');
}
if (role && !ROLES.includes(role)) {
  fail(`Role must be one of: ${ROLES.join(', ')}`);
}

// Generated, not hardcoded: a fresh value every run, printed only to stdout.
const password =
  process.env.TEST_PASSWORD ?? `${randomBytes(9).toString('base64url')}aA1!`;
const generated = !process.env.TEST_PASSWORD;

initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });

const auth = getAuth();
const db = getFirestore();

let user;
let created = false;
try {
  user = await auth.getUserByEmail(email);
  user = await auth.updateUser(user.uid, { password });
} catch (error) {
  if (error.code !== 'auth/user-not-found') throw error;
  user = await auth.createUser({ email, password, emailVerified: true });
  created = true;
}

if (role) {
  await db.collection('users').doc(user.uid).set(
    {
      name: user.displayName ?? email.split('@')[0],
      email,
      role,
      status,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

const providers = user.providerData.map((p) => p.providerId).join(', ');

console.log(`\n✔ ${created ? 'Created' : 'Updated'} ${email}`);
console.log(`  uid       : ${user.uid}`);
if (role) console.log(`  role      : ${role} (${status})`);
console.log(`  providers : ${providers}`);
if (generated) {
  console.log(`\n  PASSWORD  : ${password}`);
  console.log('  Shown once and stored nowhere — copy it now.\n');
} else {
  console.log('\n  Password set from TEST_PASSWORD.\n');
}
