#!/usr/bin/env node
// Seeds one store + one order assigned to a delivery partner so the
// "Navigate to customer" flow can be exercised end to end.
//
// Credentials are never stored in this repo: the script relies on Application
// Default Credentials, so point GOOGLE_APPLICATION_CREDENTIALS at a service
// account key that lives outside the working tree.
//
//   export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.secrets/nearkart-admin.json"
//   npm --prefix tool install
//   npm --prefix tool run seed:delivery
//
// Re-running is idempotent: it rewrites the same store/order documents and
// resets the order back to "readyForPickup".

import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, GeoPoint, getFirestore } from 'firebase-admin/firestore';

const PROJECT_ID = process.env.FIREBASE_PROJECT_ID ?? 'nearkart007-app';
const PARTNER_EMAIL = process.env.PARTNER_EMAIL ?? 'dhruva.ganesh31@gmail.com';
const STORE_MANAGER_EMAIL = process.env.STORE_MANAGER_EMAIL;
const CUSTOMER_EMAIL = process.env.CUSTOMER_EMAIL;

const STORE_ID = process.env.STORE_ID ?? 'seed-store-koramangala';
const ORDER_ID = process.env.ORDER_ID ?? 'seed-order-koramangala';

// Koramangala, Bangalore. Store and customer sit ~1km apart so the Google Maps
// hand-off has a real route to draw.
const STORE_LATITUDE = 12.9279;
const STORE_LONGITUDE = 77.6271;
const CUSTOMER_LATITUDE = 12.9352;
const CUSTOMER_LONGITUDE = 77.6245;

function fail(message) {
  console.error(`\n✖ ${message}\n`);
  process.exit(1);
}

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  fail(
    'GOOGLE_APPLICATION_CREDENTIALS is not set.\n' +
      '  Firebase Console → Project settings → Service accounts → Generate new private key,\n' +
      '  save it OUTSIDE this repository, then:\n' +
      '    export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.secrets/nearkart-admin.json"',
  );
}

initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });

const auth = getAuth();
const db = getFirestore();

async function uidForEmail(email, label) {
  try {
    return await auth.getUserByEmail(email);
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      fail(
        `No ${label} account exists for ${email}.\n` +
          '  Sign up with that address in the app first, then re-run this script.',
      );
    }
    throw error;
  }
}

// The order read rule calls ownsStore(storeId), which does a get() on the store
// document. A store owned by a real manager keeps that rule evaluable.
async function resolveStoreOwner(partnerUid) {
  if (STORE_MANAGER_EMAIL) {
    const manager = await uidForEmail(STORE_MANAGER_EMAIL, 'store manager');
    return manager.uid;
  }

  for (const role of ['storeManager', 'vendor', 'admin']) {
    const match = await db
      .collection('users')
      .where('role', '==', role)
      .limit(1)
      .get();
    if (!match.empty) {
      console.log(`• Store owner: existing ${role} (${match.docs[0].id})`);
      return match.docs[0].id;
    }
  }

  console.warn(
    '! No store manager or admin found — falling back to the delivery partner as store owner.',
  );
  return partnerUid;
}

async function resolveCustomer() {
  if (CUSTOMER_EMAIL) {
    const customer = await uidForEmail(CUSTOMER_EMAIL, 'customer');
    return { id: customer.uid, name: customer.displayName ?? 'Test Customer' };
  }

  const match = await db
    .collection('users')
    .where('role', '==', 'customer')
    .limit(1)
    .get();
  if (!match.empty) {
    const data = match.docs[0].data();
    return { id: match.docs[0].id, name: data.name ?? 'Test Customer' };
  }

  return { id: 'seed-test-customer', name: 'Test Customer' };
}

async function main() {
  console.log(`\nSeeding test delivery in ${PROJECT_ID}\n`);

  const partner = await uidForEmail(PARTNER_EMAIL, 'delivery partner');
  console.log(`• Delivery partner: ${PARTNER_EMAIL} (${partner.uid})`);

  // hasRole() denies anything that is not an active account, so approve here.
  await db.collection('users').doc(partner.uid).set(
    {
      name: partner.displayName ?? 'Dhruva Ganesh',
      email: partner.email,
      phone: partner.phoneNumber ?? '',
      role: 'deliveryPartner',
      status: 'active',
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  console.log('• Approved as an active deliveryPartner');

  const ownerId = await resolveStoreOwner(partner.uid);
  const customer = await resolveCustomer();
  console.log(`• Customer: ${customer.name} (${customer.id})`);

  await db.collection('stores').doc(STORE_ID).set(
    {
      ownerId,
      name: 'NearKart Test Store',
      description: 'Seeded store used for delivery navigation testing.',
      category: 'General',
      phone: '9876543210',
      address: '80 Feet Road, 4th Block, Koramangala',
      city: 'Bangalore',
      pincode: '560034',
      latitude: STORE_LATITUDE,
      longitude: STORE_LONGITUDE,
      upiId: '',
      isOpen: true,
      isVerified: true,
      offersDelivery: true,
      deliveryMode: 'own',
      deliveryPartnerId: partner.uid,
      deliveryRadius: 5.0,
      deliveryFee: 30.0,
      minOrderAmount: 99.0,
      rating: 0.0,
      totalRatings: 0,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  console.log(`• Store ready: stores/${STORE_ID}`);

  const items = [
    { productId: 'seed-rice', name: 'Sona Masoori Rice 5kg', price: 420, quantity: 1 },
    { productId: 'seed-milk', name: 'Milk 1L', price: 62, quantity: 2 },
  ];
  const subtotal = items.reduce((sum, item) => sum + item.price * item.quantity, 0);
  const deliveryFee = 30;
  const platformFee = 5;

  await db.collection('orders').doc(ORDER_ID).set({
    customerId: customer.id,
    customerName: customer.name,
    customerPhone: '9876501234',
    storeId: STORE_ID,
    storeName: 'NearKart Test Store',
    items,
    subtotal,
    deliveryFee,
    platformFee,
    totalAmount: subtotal + deliveryFee + platformFee,
    status: 'readyForPickup',
    deliveryType: 'delivery',
    deliveryAddress: '3rd Cross, 5th Block, Koramangala, Bangalore 560095',
    deliveryNotes: 'Call on arrival. Gate code 1234.',
    deliveryLocation: new GeoPoint(CUSTOMER_LATITUDE, CUSTOMER_LONGITUDE),
    storeLocation: new GeoPoint(STORE_LATITUDE, STORE_LONGITUDE),
    deliveryMode: 'own',
    assignedDeliveryPartnerId: partner.uid,
    paymentMethod: 'cod',
    paymentStatus: 'pending',
    isPaid: false,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  console.log(`• Order ready: orders/${ORDER_ID}`);

  console.log(
    `\n✔ Done. Sign in as ${PARTNER_EMAIL} to see the delivery and tap "Navigate to customer".\n`,
  );
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
