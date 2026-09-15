# NearKart

**Your Neighbourhood, Online** — A hyperlocal vendor marketplace for the Indian market.

NearKart connects local vendors (kirana stores, bakeries, pharmacies, etc.) with customers in their neighbourhood. Vendors list products, accept orders, and deliver — all from one app.

## Features

### Customer
- Browse nearby stores by location
- Search stores and products
- Add to cart with quantity management
- Checkout with UPI or cash on delivery
- Real-time order tracking
- Order history and reordering

### Vendor
- Register store with profile, category, and timings
- Add/edit/manage product catalog with images
- Receive and manage orders
- Dashboard with sales analytics
- Delivery settings and radius configuration

### Platform
- Firebase Auth (Email + Phone OTP)
- Cloud Firestore for real-time data
- Firebase Storage for images
- Push notifications (FCM)
- UPI payments by deep link, paid straight to the store's UPI id
- Delivery partner integration (Porter/Dunzo/Shadowfax)
- Location-based store discovery
- Offline-aware with connectivity detection

## Architecture

```
lib/
├── core/
│   ├── config/       → Environment configuration (dev/staging/prod)
│   ├── constants/    → App-wide constants
│   ├── exceptions/   → Custom exception hierarchy
│   ├── theme/        → Material 3 theme, colors
│   └── utils/        → Validators, input sanitization
├── models/           → Data models (User, Store, Product, Order, Cart)
├── providers/        → Riverpod state management
├── services/
│   ├── firebase/     → Auth, Firestore, Storage services
│   ├── payment/      → UPI deep links
│   ├── location/     → GPS + Geocoding
│   ├── notification/ → FCM + Local notifications
│   └── delivery/     → Delivery partner API
├── screens/          → UI screens (auth, vendor, customer, cart, orders)
└── widgets/          → Reusable components
```

## Prerequisites

- Flutter 3.8+ (Dart 3.8+)
- Firebase CLI (`npm install -g firebase-tools`)
- A Firebase project
- Android Studio / Xcode

## Setup

### 1. Clone and install

```bash
cd nearkart
flutter pub get
```

### 2. Firebase Setup

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase (creates firebase_options.dart)
flutterfire configure --project=your-firebase-project-id
```

Then in `lib/main.dart`, add:
```dart
import 'firebase_options.dart';

// In main():
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
```

### 3. Deploy Firestore Rules

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
```

### 4. Environment Variables

Run with environment flags:

```bash
# Development
flutter run --dart-define=ENV=dev

# Production
flutter run --release --dart-define=ENV=prod
```

Google Sign-In uses the public Web OAuth client ID already in
`android/app/google-services.json`. Override it only when pointing at a
different Firebase project:

```bash
flutter run --dart-define=ENV=dev --dart-define=GOOGLE_SERVER_CLIENT_ID=...
```

Payments need no keys: UPI runs through the device's own UPI app, the store's
UPI id lives on the store document, and the platform's payee id is set by an
admin under **Platform settings**.

### 5. Android Setup

In `android/app/build.gradle`:
- Set `minSdkVersion 23`
- Add internet permission (already present)
- Add your `google-services.json` to `android/app/`

### 6. iOS Setup

- Add `GoogleService-Info.plist` to `ios/Runner/`
- Update `Info.plist` with location and camera permissions:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>NearKart needs location to find stores near you</string>
<key>NSCameraUsageDescription</key>
<string>NearKart needs camera to add product photos</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>NearKart needs photo access to add product images</string>
```

## Running

```bash
# Debug
flutter run

# Release (Android)
flutter build apk --release --dart-define=ENV=prod

# Release (iOS)
flutter build ios --release --dart-define=ENV=prod
```

## Testing

```bash
flutter test
flutter test --coverage
```

## Deployment Checklist

- [ ] Firebase project created and configured
- [ ] Platform payee UPI id set under admin **Platform settings**
- [ ] Firestore security rules deployed
- [ ] Storage rules deployed
- [ ] FCM configured for push notifications
- [ ] App signing configured (Android keystore / iOS certificates)
- [ ] Privacy policy and terms of service URLs set
- [ ] App store listing prepared
- [ ] Delivery partner API keys configured
- [ ] Rate limiting configured on Firebase
- [ ] Error monitoring (Firebase Crashlytics) enabled

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter 3.8+ (Dart) |
| State | Riverpod |
| Backend | Firebase (Auth, Firestore, Storage, FCM) |
| Payments | UPI deep links (url_launcher) |
| Location | Geolocator + Geocoding |
| Delivery | Porter / Dunzo / Shadowfax API |
| Analytics | Firebase Analytics |

## License

Proprietary — All rights reserved.
