# Accounts and roles

Current state of the `nearkart007-app` Firebase project. Regenerate this table
with `node tool/list_users.mjs --markdown` (see [Refreshing this doc](#refreshing-this-doc)).

Last verified: 13 September 2026.

## Current accounts

| Name | Email | Role | Status | Phone | Sign-in | UID |
| --- | --- | --- | --- | --- | --- | --- |
| Dhruva | manjula.kollegal@gmail.com | `admin` | active | 9742721601 | password | `NqGiW1KQfgViqwrJIB5jxd9ptQv1` |
| thej | theja.anaga@gmail.com | `customer` | unset | 9742721601 | google.com | `jAqDTXEKXfgzqQ8J3ZIVrJkbwM12` |
| subbanna | dhruva.ganesh31@gmail.com | `deliveryPartner` | active | 9742721601 | password | `KXTnoU6a8gcdaJ7aMX2yxoTIVr93` |
| Saroja H | saroja.vvce@gmail.com | `storeManager` | active | 7406542703 | google.com, password | `RDYNSROWk7VWvv4QRJWOtv0pXvx1` |

Notes on the rows above:

- Three accounts share the number **9742721601**. The Add Store form looks a
  manager up by email or phone, so searching by that number reports an
  ambiguous match rather than picking one; search by email instead. Giving them
  distinct numbers would avoid it.

- **theja.anaga@gmail.com** has no `status` field. Customers are never gated on
  approval, so the app treats a missing status as active. Only store managers
  and delivery partners need an admin to approve them.
- **saroja.vvce@gmail.com** has both Google and password sign-in. The password
  provider was added purely for emulator testing and **should be removed before
  production**.
- **dhruva.ganesh31@gmail.com** was originally the project's only store
  manager. It was converted to `deliveryPartner` to test the delivery map flow,
  which is why Saroja now holds the store-manager role.

## Roles

The role lives in `users/{uid}.role` and decides which shell the app routes to
after sign-in. It is **not** the same as project IAM — the Firebase Console's
"Users and permissions" page controls who can administer the Firebase project,
and has no effect on the app.

| Role | Lands on | Can do |
| --- | --- | --- |
| `customer` | `CustomerShell` | Browse stores, order, track, save addresses and wishlist |
| `storeManager` | `VendorShell` | Manage their own store, products, orders, timings and payments |
| `deliveryPartner` | `DeliveryPartnerShell` | See assigned orders, navigate, mark delivered |
| `admin` | `AdminShell` | Approve accounts, create stores, assign managers |

`vendor` is accepted as a legacy alias for `storeManager` in both
`UserRole.fromStoredValue` and `firestore.rules`, so older documents keep
working.

## Account status

| Status | Meaning |
| --- | --- |
| `active` | Can sign in and use the app |
| `pending` | Awaiting admin approval; store managers and delivery partners are held at a waiting screen |
| `rejected` | The registration was never approved |
| `suspended` | Access withdrawn from an account that had been approved |

`rejected` and `suspended` both block everything — security rules only grant a
role to an `active` account — but they are kept apart so the person is told the
truth: a rejected applicant sees "Registration was not approved", a deactivated
one sees "Account deactivated". Deactivating is reversible at any time.

## Phone numbers

Every persona must have a mobile number, because the parties to an order call
each other from the app. Email is optional: sign-up, profile and admin user
forms accept an empty email, and login accepts either an email or a 10-digit
mobile number.

- Sign-up collects a mobile number and rejects anything but 10 digits.
- Google sign-in never supplies one, so those accounts (and any account created
  before this requirement) are held at `PhoneCaptureScreen` after sign-in until
  they add one.
- It cannot be cleared afterwards; **Account & profile** requires 10 digits.
- Firestore rules enforce it server-side rather than trusting the app: an order
  can only be created if it carries the customer's own recorded number and the
  store's, so a customer with no number on file cannot place an order at all.

Numbers are copied onto each order (`customerPhone`, `storePhone`,
`deliveryPartnerPhone`) rather than read from `users`, because rules
deliberately stop a customer reading another person's profile. The store writes
the delivery partner's number when it assigns them, since a store manager is
the only non-admin allowed to read a delivery partner's profile.

## Owned stores

| Store | Id | Owner |
| --- | --- | --- |
| NearKart Test Store | `seed-store-koramangala` | Saroja H (`storeManager`) |

The project currently holds 1 store, 2 products and 1 order. A store manager
with no store sees a "No store assigned yet" card and the store settings rows
are disabled, because an admin has to create the store and assign it.

The reverse also works: an admin can create a store before its manager has an
account. Such a store is created deactivated and shows a **No manager** badge,
and the "Store active" switch stays locked until a manager is assigned from
**Store details → Store manager → Assign manager**, so customers never see a
store whose orders would reach nobody.

## Changing roles and status

All the scripts below need admin credentials. The service account key must live
**outside** the repository and be referenced through the environment — never
commit a key or hardcode its path:

```sh
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.secrets/nearkart-admin.json"
```

Promote or approve an account:

```sh
node tool/set_role.mjs saroja.vvce@gmail.com storeManager active
```

Roles must be one of `customer`, `storeManager`, `admin`, `deliveryPartner`;
status one of `active`, `pending`, `rejected`, `suspended`.

None of this needs a script any more. **Admin shell → Manage users** lists every
account with search and role/status filters, and can:

- **Add** an account for anyone — name, email, phone and role. No password is
  set by the admin: the account is opened with a single-use value from a secure
  generator that is never shown or stored, and the person is emailed a link to
  choose their own. The admin's own session is unaffected, because the account
  is created through a second Firebase app instance.
- **Edit** name, phone, role and status.
- **Deactivate** and reactivate, which is what `suspended` is for.
- **Send a password reset** to somebody locked out.

Role and status are locked on the admin's own account so they cannot remove
their own access and leave nobody able to restore it.

The **Add user** form is also offered inline wherever a manager lookup finds
nothing — both the Add Store dialog and **Store details → Store manager** — so a
shop and its owner can be set up in one pass. Creating an account for someone
else requires the `admin` role in Firestore rules.

## Test sign-in credentials

Test passwords are **deliberately not recorded in this repository**. Treat the
codebase as public: any credential written into a file here is compromised.

To get a working password login for a persona, generate a fresh one. The script
prints the password to stdout once and never stores it:

```sh
node tool/set_password.mjs saroja.vvce@gmail.com storeManager active
```

Pass your own value through the `TEST_PASSWORD` environment variable if you need
a specific one. Setting a password only affects that account's Firebase Auth
record for NearKart — it does not touch the person's real Google account.

## Refreshing this doc

```sh
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.secrets/nearkart-admin.json"
node tool/list_users.mjs --markdown
```

`list_users.mjs` joins Firebase Auth accounts with their Firestore profiles and
warns about any `users/{uid}` document that has no matching Auth account. Paste
its output into [Current accounts](#current-accounts) and update the
"Last verified" date.
