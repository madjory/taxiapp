# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Taxi App** — a ride-hailing application (like Uber) with WhatsApp-based driver communication. The system consists of two Flutter mobile apps (rider + driver) sharing one Firebase backend.

## Repository Structure

```
/
├── rider_app/          # Rider Flutter app
├── driver_app/         # Driver Flutter app
├── shared/             # Shared Dart package (models, services, constants)
│   ├── lib/
│   │   ├── models/     # UserModel, DriverModel, RideModel
│   │   ├── services/   # AuthService, FirestoreService, LocationService
│   │   ├── utils/      # WhatsAppHelper, Geohash
│   │   └── constants.dart
│   └── pubspec.yaml
├── firebase/           # Firebase config
│   ├── functions/      # Cloud Functions (Node.js, v2 API)
│   │   ├── index.js
│   │   └── package.json
│   ├── firestore.rules
│   └── firestore.indexes.json
├── firebase.json
├── .firebaserc
└── CLAUDE.md
```

## Key Commands

### Cloud Functions
```bash
cd firebase/functions && npm install    # Install dependencies
cd firebase/functions && npm run lint   # Lint functions
cd firebase/functions && npm test       # Run tests
```

### Shared Dart Package
```bash
cd shared && dart pub get               # Get dependencies
cd shared && dart analyze               # Analyze for errors
```

### Flutter Apps (once created)
```bash
cd rider_app && flutter run             # Run rider app
cd driver_app && flutter run            # Run driver app
```

### Firebase Deploy
```bash
firebase deploy --only firestore:rules  # Deploy security rules
firebase deploy --only functions        # Deploy cloud functions
firebase deploy                         # Deploy everything
```

## Architecture

### Backend (Firebase)
- **Firestore** — three collections: `users`, `drivers`, `rides`
- **Cloud Functions v2** (Node.js) — `onDriverLocationUpdate`, `getNearbyDrivers`, `createRideRequest`, `updateRideStatus`
- **FCM** — push notifications for ride events
- **Auth** — phone number authentication

### Shared Dart Package (`shared/`)
- **Models** — `UserModel`, `DriverModel`, `RideModel` with Firestore serialization
- **Services** — `AuthService` (phone auth), `FirestoreService` (CRUD + Cloud Functions calls), `LocationService` (GPS)
- **Utils** — `WhatsAppHelper` (deep links with Google Maps), `Geohash` (proximity encoding)

### Data Flow
```
Rider App → Cloud Functions → Firestore → Driver App (real-time listeners)
                            → FCM Push → Driver App (notifications)
Rider App → WhatsApp deep link → Driver's WhatsApp
```

### Firestore Collections

**`users`** — rider profiles (uid, name, phone, createdAt)
**`drivers`** — driver profiles (uid, name, phone, carModel, plateNumber, ratePerKm, isOnline, isApproved, location, geohash, rating, totalRides, createdAt)
**`rides`** — ride requests (riderId, driverId, pickup/dropoff locations+addresses, estimatedDistance, estimatedFare, status, timestamps, ratings)

### Ride Status Flow
`requested` → `accepted` → `in_progress` → `completed`
Any active state → `cancelled`

### Security Rules
- Riders: read own user doc, create/read own rides, cancel own active rides
- Drivers: read/update own driver doc (cannot self-approve), read/update assigned rides
- Admin actions (driver approval): Cloud Functions only (admin SDK)
- Phone numbers: returned only via Cloud Functions, not directly readable

### Geohash Proximity Queries
Drivers have a `geohash` field auto-computed by the `onDriverLocationUpdate` Cloud Function. The `getNearbyDrivers` function uses geohash range queries via `geofire-common` to efficiently find drivers within a radius.
