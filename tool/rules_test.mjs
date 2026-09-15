#!/usr/bin/env node
// Security-rules tests for store moderation, platform settings and order
// creation. Runs entirely against the Firestore emulator, so it needs no
// credentials and never touches production data.
//
//   npm --prefix tool run test:rules

import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, deleteField } from 'firebase/firestore';

const env = await initializeTestEnvironment({
  projectId: 'nearkart-rules-test',
  firestore: {
    rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
    host: '127.0.0.1',
    port: 8080,
  },
});

const STORE = 'store-1';
const ADMIN = 'admin-uid';
const MANAGER = 'manager-uid';
const CUSTOMER = 'customer-uid';
const CUSTOMER_PHONE = '9000000001';
const STORE_PHONE = '9000000002';

/** A well-formed order, with the contact numbers the rules expect. */
function order(overrides = {}) {
  return {
    customerId: CUSTOMER,
    customerPhone: CUSTOMER_PHONE,
    storeId: STORE,
    storePhone: STORE_PHONE,
    totalAmount: 100,
    status: 'placed',
    ...overrides,
  };
}

/** Seeds users, a store and its products with rules disabled. */
async function seed({ isActive = true, isBlacklisted = false } = {}) {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users', ADMIN), { role: 'admin', status: 'active' });
    await setDoc(doc(db, 'users', MANAGER), {
      role: 'storeManager',
      status: 'active',
    });
    await setDoc(doc(db, 'users', CUSTOMER), {
      role: 'customer',
      status: 'active',
      phone: CUSTOMER_PHONE,
    });
    await setDoc(doc(db, 'stores', STORE), {
      ownerId: MANAGER,
      name: 'Test Store',
      description: 'seed',
      phone: STORE_PHONE,
      isActive,
      isBlacklisted,
      isVerified: false,
      rating: 4,
    });
    await setDoc(doc(db, 'products', 'p1'), { storeId: STORE, name: 'Milk' });
  });
}

const asAdmin = () => env.authenticatedContext(ADMIN).firestore();
const asManager = () => env.authenticatedContext(MANAGER).firestore();
const asCustomer = () => env.authenticatedContext(CUSTOMER).firestore();

let passed = 0;
let failed = 0;

async function check(name, run) {
  try {
    await run();
    console.log(`  ✔ ${name}`);
    passed++;
  } catch (error) {
    console.log(`  ✖ ${name}\n      ${error.message}`);
    failed++;
  }
}

function group(name) {
  console.log(`\n${name}`);
}

// --- Store moderation is admin-only -------------------------------------
group('Store moderation fields');
await seed();

await check('manager cannot deactivate their own store', () =>
  assertFails(updateDoc(doc(asManager(), 'stores', STORE), { isActive: false })),
);
await check('manager cannot blacklist a store', () =>
  assertFails(
    updateDoc(doc(asManager(), 'stores', STORE), { isBlacklisted: true }),
  ),
);
await check('manager cannot self-verify', () =>
  assertFails(updateDoc(doc(asManager(), 'stores', STORE), { isVerified: true })),
);
await check('manager cannot edit their own rating', () =>
  assertFails(updateDoc(doc(asManager(), 'stores', STORE), { rating: 5 })),
);
await check('manager cannot reassign ownership', () =>
  assertFails(updateDoc(doc(asManager(), 'stores', STORE), { ownerId: ADMIN })),
);
await check('manager can still edit their own store details', () =>
  assertSucceeds(
    updateDoc(doc(asManager(), 'stores', STORE), { description: 'updated' }),
  ),
);
await check('admin can deactivate a store', () =>
  assertSucceeds(
    updateDoc(doc(asAdmin(), 'stores', STORE), { isActive: false }),
  ),
);
await check('admin can blacklist a store', () =>
  assertSucceeds(
    updateDoc(doc(asAdmin(), 'stores', STORE), {
      isBlacklisted: true,
      blacklistReason: 'Selling prohibited items',
    }),
  ),
);

// --- A blacklisted store is frozen --------------------------------------
group('Blacklisted store');
await seed({ isActive: false, isBlacklisted: true });

await check('manager cannot edit the store at all', () =>
  assertFails(
    updateDoc(doc(asManager(), 'stores', STORE), { description: 'nope' }),
  ),
);
await check('manager cannot lift their own blacklist', () =>
  assertFails(
    updateDoc(doc(asManager(), 'stores', STORE), { isBlacklisted: false }),
  ),
);
await check('manager cannot re-activate themselves', () =>
  assertFails(updateDoc(doc(asManager(), 'stores', STORE), { isActive: true })),
);
await check('manager cannot add products', () =>
  assertFails(
    setDoc(doc(asManager(), 'products', 'p2'), { storeId: STORE, name: 'X' }),
  ),
);
await check('manager cannot edit existing products', () =>
  assertFails(updateDoc(doc(asManager(), 'products', 'p1'), { name: 'Y' })),
);
await check('customer cannot place an order', () =>
  assertFails(setDoc(doc(asCustomer(), 'orders', 'o1'), order())),
);

// --- A deactivated store stops trading ----------------------------------
group('Deactivated store');
await seed({ isActive: false });

await check('customer cannot place an order', () =>
  assertFails(setDoc(doc(asCustomer(), 'orders', 'o2'), order())),
);
await check('manager cannot add products', () =>
  assertFails(
    setDoc(doc(asManager(), 'products', 'p3'), { storeId: STORE, name: 'X' }),
  ),
);

// --- An active store still works ----------------------------------------
group('Active store');
await seed();

await check('customer can place an order', () =>
  assertSucceeds(setDoc(doc(asCustomer(), 'orders', 'o3'), order())),
);
await check('manager can add products', () =>
  assertSucceeds(
    setDoc(doc(asManager(), 'products', 'p4'), { storeId: STORE, name: 'X' }),
  ),
);
await check('manager can change their own UPI id', () =>
  assertSucceeds(
    updateDoc(doc(asManager(), 'stores', STORE), { upiId: 'shop@okaxis' }),
  ),
);
await check('admin can change a store UPI id', () =>
  assertSucceeds(
    updateDoc(doc(asAdmin(), 'stores', STORE), { upiId: 'shop@okicici' }),
  ),
);

// --- A store created before its manager signed up ------------------------
group('Unassigned store');
await seed();
await env.withSecurityRulesDisabled(async (context) => {
  await setDoc(doc(context.firestore(), 'stores', STORE), {
    ownerId: '',
    name: 'Unassigned',
    phone: STORE_PHONE,
    isActive: false,
    isBlacklisted: false,
  });
});

await check('a manager cannot claim an ownerless store', () =>
  assertFails(
    updateDoc(doc(asManager(), 'stores', STORE), { ownerId: MANAGER }),
  ),
);
await check('a manager cannot edit a store they do not own', () =>
  assertFails(
    updateDoc(doc(asManager(), 'stores', STORE), { description: 'mine' }),
  ),
);
await check('a customer cannot order from a store with no manager', () =>
  assertFails(setDoc(doc(asCustomer(), 'orders', 'u1'), order())),
);
await check('an admin can assign a manager', () =>
  assertSucceeds(
    updateDoc(doc(asAdmin(), 'stores', STORE), { ownerId: MANAGER }),
  ),
);

// --- Contact numbers on an order must be genuine -------------------------
group('Order contact numbers');
await seed();

await check('customer cannot fake the store number', () =>
  assertFails(
    setDoc(doc(asCustomer(), 'orders', 'c1'), order({ storePhone: '9111111111' })),
  ),
);
await check('customer cannot fake their own number', () =>
  assertFails(
    setDoc(
      doc(asCustomer(), 'orders', 'c2'),
      order({ customerPhone: '9222222222' }),
    ),
  ),
);
await check('customer cannot omit the contact numbers', () =>
  assertFails(
    setDoc(doc(asCustomer(), 'orders', 'c3'), {
      customerId: CUSTOMER,
      storeId: STORE,
      totalAmount: 100,
      status: 'placed',
    }),
  ),
);

// A profile with no number cannot transact, which is what makes the phone
// requirement real rather than a client-side nicety.
await env.withSecurityRulesDisabled(async (context) => {
  await setDoc(doc(context.firestore(), 'users', CUSTOMER), {
    role: 'customer',
    status: 'active',
  });
});
await check('a customer with no number on file cannot order', () =>
  assertFails(
    setDoc(
      doc(asCustomer(), 'orders', 'c4'),
      order({ customerPhone: '' }),
    ),
  ),
);

// --- Platform settings ---------------------------------------------------
group('Platform settings');
await seed();
await env.withSecurityRulesDisabled(async (context) => {
  const db = context.firestore();
  await setDoc(doc(db, 'settings', 'platform'), { feePercent: 1 });
  await setDoc(doc(db, 'settings', 'platform_payout'), {
    accountNumber: '000111222333',
  });
});

await check('anyone may read the fee rule', () =>
  assertSucceeds(getDoc(doc(asCustomer(), 'settings', 'platform'))),
);
await check('a customer cannot change the fee', () =>
  assertFails(
    updateDoc(doc(asCustomer(), 'settings', 'platform'), { feePercent: 0 }),
  ),
);
await check('a store manager cannot change the fee', () =>
  assertFails(
    updateDoc(doc(asManager(), 'settings', 'platform'), { feePercent: 0 }),
  ),
);
await check('an admin can change the fee', () =>
  assertSucceeds(
    updateDoc(doc(asAdmin(), 'settings', 'platform'), { feePercent: 2 }),
  ),
);
await check('a customer cannot read the payout bank details', () =>
  assertFails(getDoc(doc(asCustomer(), 'settings', 'platform_payout'))),
);
await check('a store manager cannot read the payout bank details', () =>
  assertFails(getDoc(doc(asManager(), 'settings', 'platform_payout'))),
);
await check('an admin can read the payout bank details', () =>
  assertSucceeds(getDoc(doc(asAdmin(), 'settings', 'platform_payout'))),
);

// --- Stores with no moderation fields stay usable ------------------------
group('Legacy store without moderation fields');
await env.clearFirestore();
await env.withSecurityRulesDisabled(async (context) => {
  const db = context.firestore();
  await setDoc(doc(db, 'users', MANAGER), {
    role: 'storeManager',
    status: 'active',
  });
  await setDoc(doc(db, 'users', CUSTOMER), {
    role: 'customer',
    status: 'active',
    phone: CUSTOMER_PHONE,
  });
  await setDoc(doc(db, 'stores', STORE), { ownerId: MANAGER, name: 'Legacy' });
});

// A store that has not recorded a number yet: the order carries none either,
// and the app falls back to reading the store document.
await check('customer can order from a store with no number', () =>
  assertSucceeds(
    setDoc(doc(asCustomer(), 'orders', 'o4'), order({ storePhone: '' })),
  ),
);
await check('manager can edit details', () =>
  assertSucceeds(
    updateDoc(doc(asManager(), 'stores', STORE), { description: 'ok' }),
  ),
);
await check('manager still cannot self-verify', () =>
  assertFails(updateDoc(doc(asManager(), 'stores', STORE), { isVerified: true })),
);

// --- Admin account administration ---------------------------------------
group('Admin user management');
await seed();

const NEW_USER = 'new-user-uid';
const newProfile = (overrides = {}) => ({
  name: 'New Manager',
  email: 'new.manager@example.com',
  phone: '9000000003',
  role: 'storeManager',
  status: 'active',
  ...overrides,
});

await check('an admin can create a profile for somebody else', () =>
  assertSucceeds(setDoc(doc(asAdmin(), 'users', NEW_USER), newProfile())),
);
await check('an admin can create it already active, skipping approval', () =>
  assertSucceeds(
    setDoc(doc(asAdmin(), 'users', 'new-user-2'), newProfile({
      status: 'active',
      role: 'deliveryPartner',
    })),
  ),
);
await check('a manager cannot create a profile for somebody else', () =>
  assertFails(setDoc(doc(asManager(), 'users', 'sneaky-uid'), newProfile())),
);
await check('a customer cannot create a profile for somebody else', () =>
  assertFails(setDoc(doc(asCustomer(), 'users', 'sneaky-uid'), newProfile())),
);
await check('an admin can deactivate an account', () =>
  assertSucceeds(
    updateDoc(doc(asAdmin(), 'users', MANAGER), { status: 'suspended' }),
  ),
);

// Deactivation has to actually take effect: hasRole() requires an active
// account, so a suspended manager must lose their store permissions.
await check('a deactivated manager can no longer edit their store', () =>
  assertFails(
    updateDoc(doc(asManager(), 'stores', STORE), { description: 'nope' }),
  ),
);
await check('a deactivated account cannot reactivate itself', () =>
  assertFails(
    updateDoc(doc(asManager(), 'users', MANAGER), { status: 'active' }),
  ),
);
await check('an admin can reactivate an account', () =>
  assertSucceeds(
    updateDoc(doc(asAdmin(), 'users', MANAGER), { status: 'active' }),
  ),
);
await check('a customer still cannot change their own role', () =>
  assertFails(
    updateDoc(doc(asCustomer(), 'users', CUSTOMER), { role: 'admin' }),
  ),
);

await env.cleanup();

console.log(`\n${passed} passed, ${failed} failed\n`);
process.exit(failed === 0 ? 0 : 1);
