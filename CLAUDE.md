# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Taxi App** — a ride-hailing application (like Uber) with WhatsApp-based driver communication. The system consists of two Flutter mobile apps (rider + driver) sharing one Firebase backend.

## Repository Structure

```
/
├── rider_app/              # Rider Flutter app (Provider, 8 screens)
│   ├── lib/
│   │   ├── main.dart       # Firebase init, Provider setup
│   │   ├── app.dart        # MaterialApp with named routes
│   │   ├── theme.dart      # Green theme
│   │   ├── providers/
│   │   │   ├── auth_provider.dart   # Phone auth, user profile
│   │   │   └── ride_provider.dart   # Nearby drivers, booking, ride tracking
│   │   ├── screens/
│   │   │   ├── splash_screen.dart
│   │   │   ├── login_screen.dart
│   │   │   ├── otp_screen.dart
│   │   │   ├── home_screen.dart
│   │   │   ├── nearby_drivers_screen.dart
│   │   │   ├── ride_tracking_screen.dart
│   │   │   ├── ride_history_screen.dart
│   │   │   └── profile_screen.dart
│   │   └── widgets/
│   │       ├── driver_card.dart
│   │       └── ride_status_banner.dart
│   └── pubspec.yaml
├── driver_app/             # Driver Flutter app (Provider, 8 screens)
│   ├── lib/
│   │   ├── main.dart       # Firebase init, Provider setup
│   │   ├── app.dart        # MaterialApp with named routes
│   │   ├── theme.dart      # Blue theme
│   │   ├── providers/
│   │   │   ├── auth_provider.dart    # Phone auth, driver profile
│   │   │   ├── driver_provider.dart  # Online/offline, GPS streaming
│   │   │   └── ride_provider.dart    # Incoming requests, ride status mgmt
│   │   ├── screens/
│   │   │   ├── splash_screen.dart
│   │   │   ├── login_screen.dart
│   │   │   ├── otp_screen.dart
│   │   │   ├── registration_screen.dart
│   │   │   ├── home_screen.dart
│   │   │   ├── active_ride_screen.dart
│   │   │   ├── ride_history_screen.dart
│   │   │   └── profile_screen.dart
│   │   └── widgets/
│   │       ├── ride_request_card.dart
│   │       └── ride_status_banner.dart
│   └── pubspec.yaml
├── shared/                 # Shared Dart package (models, services, constants)
│   ├── lib/
│   │   ├── models/         # UserModel, DriverModel, RideModel
│   │   ├── services/       # AuthService, FirestoreService, LocationService
│   │   ├── utils/          # WhatsAppHelper, Geohash
│   │   └── constants.dart
│   └── pubspec.yaml
├── firebase/               # Firebase config
│   ├── functions/          # Cloud Functions (Node.js, v2 API)
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

### Rider App
```bash
cd rider_app && flutter create .        # Generate platform dirs (first time)
cd rider_app && flutter pub get         # Get dependencies
cd rider_app && flutter analyze         # Analyze for errors
cd rider_app && flutter run             # Run rider app
```

### Driver App
```bash
cd driver_app && flutter create .       # Generate platform dirs (first time)
cd driver_app && flutter pub get        # Get dependencies
cd driver_app && flutter analyze        # Analyze for errors
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

## Rider App (`rider_app/`)

### State Management — Provider
- **AuthProvider** — wraps `AuthService`, manages phone auth flow (verifyPhone → submitOtp), loads `UserModel`, update name, sign out
- **RideProvider** — wraps `FirestoreService` + `LocationService`, manages GPS pickup, nearby driver search, ride booking (auto-calculates distance/fare), real-time ride streaming, ride history, cancel

### Screen Flow
```
Splash → (auth check) → Login → OTP → Home
                                        ↓
Home (pickup/dropoff input) → Nearby Drivers (select) → Ride Tracking (real-time)
                                                              ↓
                                                        WhatsApp link to driver
Home drawer → Ride History
           → Profile
```

### Routes
- `/` — SplashScreen
- `/login` — LoginScreen (name + phone)
- `/otp` — OtpScreen (6-digit code, name passed via route args)
- `/home` — HomeScreen (address input, GPS auto-set, drawer nav)
- `/nearby-drivers` — NearbyDriversScreen (driver cards, book confirmation)
- `/ride-tracking` — RideTrackingScreen (status banner, ride details, WhatsApp, cancel)
- `/ride-history` — RideHistoryScreen (streamed ride list)
- `/profile` — ProfileScreen (view/edit name)

## Driver App (`driver_app/`)

### State Management — Provider
- **AuthProvider** — wraps `AuthService`, manages phone auth, loads `DriverModel` (checks if driver doc exists), `registerDriver()` creates new driver doc
- **DriverProvider** — wraps `FirestoreService` + `LocationService`, manages online/offline toggle with continuous GPS streaming (`getPositionStream`), auto-updates driver location in Firestore
- **RideProvider** — wraps `FirestoreService`, listens to `driverRidesStream`, splits into incoming requests vs active ride, manages status progression: accept → start → complete / cancel

### Screen Flow
```
Splash → (auth + driver doc check) → Login → OTP → Registration (new) → Home
                                                      ↓ (existing)
                                                     Home
                                                      ↓
Home (online/offline, incoming requests) → Active Ride (status progression)
Home drawer → Ride History
           → Profile
```

### Routes
- `/` — SplashScreen (checks auth + driver doc existence)
- `/login` — LoginScreen (phone only)
- `/otp` — OtpScreen (existing driver → home, new → register)
- `/register` — RegistrationScreen (name, car model, plate, rate/km)
- `/home` — HomeScreen (approval notice, online toggle, ride request cards, active ride banner)
- `/active-ride` — ActiveRideScreen (Start Ride → Complete Ride, WhatsApp, cancel)
- `/ride-history` — RideHistoryScreen (completed/cancelled rides)
- `/profile` — ProfileScreen (stats, vehicle info, approval badge)

### Driver Approval Flow
New drivers register with `isApproved: false`. The home screen shows a "Pending Approval" state and hides the online toggle until an admin approves via Cloud Functions (admin SDK). Drivers cannot self-approve (enforced by security rules).
