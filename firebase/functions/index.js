const {onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue, GeoPoint} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const {geohashForLocation, geohashQueryBounds, distanceBetween} = require("geofire-common");

initializeApp();

const db = getFirestore();
const GEOHASH_PRECISION = 6;

// ---------------------------------------------------------------------------
// Helper: send FCM push notification to a driver's device
// ---------------------------------------------------------------------------
async function sendDriverNotification(driverUid, title, body, data = {}) {
  const driverDoc = await db.collection("drivers").doc(driverUid).get();
  if (!driverDoc.exists) return;

  const fcmToken = driverDoc.data().fcmToken;
  if (!fcmToken) return;

  const message = {
    token: fcmToken,
    notification: {title, body},
    data: Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, String(v)]),
    ),
  };

  await getMessaging().send(message);
}

// ---------------------------------------------------------------------------
// onDriverLocationUpdate — recalculate geohash when driver location changes
// ---------------------------------------------------------------------------
exports.onDriverLocationUpdate = onDocumentUpdated(
    "drivers/{driverId}",
    async (event) => {
      const before = event.data.before.data();
      const after = event.data.after.data();

      // Only recalculate if location actually changed
      if (!after.location) return null;
      if (
        before.location &&
        before.location.latitude === after.location.latitude &&
        before.location.longitude === after.location.longitude
      ) {
        return null;
      }

      const lat = after.location.latitude;
      const lng = after.location.longitude;
      const hash = geohashForLocation([lat, lng], GEOHASH_PRECISION);

      return event.data.after.ref.update({geohash: hash});
    },
);

// ---------------------------------------------------------------------------
// getNearbyDrivers — callable: find online, approved drivers near a location
// ---------------------------------------------------------------------------
exports.getNearbyDrivers = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in.");
  }

  const {latitude, longitude, radiusKm = 10} = request.data;
  if (latitude == null || longitude == null) {
    throw new HttpsError("invalid-argument", "latitude and longitude required.");
  }

  const center = [latitude, longitude];
  const radiusMeters = radiusKm * 1000;
  const bounds = geohashQueryBounds(center, radiusMeters);

  const queries = bounds.map(([start, end]) =>
    db.collection("drivers")
        .where("isOnline", "==", true)
        .where("isApproved", "==", true)
        .orderBy("geohash")
        .startAt(start)
        .endAt(end)
        .get(),
  );

  const snapshots = await Promise.all(queries);

  const drivers = [];
  for (const snap of snapshots) {
    for (const doc of snap.docs) {
      const data = doc.data();
      if (!data.location) continue;

      const distKm = distanceBetween(
          [data.location.latitude, data.location.longitude],
          center,
      );

      if (distKm <= radiusKm) {
        drivers.push({
          uid: doc.id,
          name: data.name,
          carModel: data.carModel,
          plateNumber: data.plateNumber,
          ratePerKm: data.ratePerKm,
          rating: data.rating,
          totalRides: data.totalRides,
          distanceKm: Math.round(distKm * 100) / 100,
          location: {
            latitude: data.location.latitude,
            longitude: data.location.longitude,
          },
        });
      }
    }
  }

  // Sort by distance
  drivers.sort((a, b) => a.distanceKm - b.distanceKm);
  return {drivers};
});

// ---------------------------------------------------------------------------
// createRideRequest — callable: create a ride and notify the driver
// ---------------------------------------------------------------------------
exports.createRideRequest = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in.");
  }

  const {
    driverId,
    pickupLatitude,
    pickupLongitude,
    pickupAddress,
    dropoffLatitude,
    dropoffLongitude,
    dropoffAddress,
    estimatedDistance,
    estimatedFare,
  } = request.data;

  if (!driverId || pickupLatitude == null || pickupLongitude == null ||
      dropoffLatitude == null || dropoffLongitude == null) {
    throw new HttpsError("invalid-argument", "Missing required ride fields.");
  }

  const rideRef = db.collection("rides").doc();
  const rideData = {
    riderId: request.auth.uid,
    driverId,
    pickupLocation: new GeoPoint(pickupLatitude, pickupLongitude),
    pickupAddress: pickupAddress || "",
    dropoffLocation: new GeoPoint(dropoffLatitude, dropoffLongitude),
    dropoffAddress: dropoffAddress || "",
    estimatedDistance: estimatedDistance || 0,
    estimatedFare: estimatedFare || 0,
    status: "requested",
    createdAt: FieldValue.serverTimestamp(),
    completedAt: null,
    riderRating: null,
    driverRating: null,
  };

  await rideRef.set(rideData);

  // Notify the driver
  await sendDriverNotification(
      driverId,
      "New Ride Request",
      `Pickup: ${pickupAddress || "See app"}`,
      {rideId: rideRef.id, type: "ride_request"},
  );

  return {rideId: rideRef.id};
});

// ---------------------------------------------------------------------------
// updateRideStatus — callable: accept, decline, start, complete, or cancel
// ---------------------------------------------------------------------------
exports.updateRideStatus = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in.");
  }

  const {rideId, status} = request.data;
  const validStatuses = ["accepted", "in_progress", "completed", "cancelled"];

  if (!rideId || !validStatuses.includes(status)) {
    throw new HttpsError("invalid-argument", "Invalid rideId or status.");
  }

  const rideRef = db.collection("rides").doc(rideId);
  const rideSnap = await rideRef.get();

  if (!rideSnap.exists) {
    throw new HttpsError("not-found", "Ride not found.");
  }

  const ride = rideSnap.data();
  const uid = request.auth.uid;

  // Authorization: driver can accept/start/complete, rider can cancel
  if (["accepted", "in_progress", "completed"].includes(status)) {
    if (ride.driverId !== uid) {
      throw new HttpsError("permission-denied", "Only the assigned driver can update this ride.");
    }
  }

  if (status === "cancelled") {
    if (ride.riderId !== uid && ride.driverId !== uid) {
      throw new HttpsError("permission-denied", "Only the rider or driver can cancel.");
    }
  }

  // State machine validation
  const transitions = {
    requested: ["accepted", "cancelled"],
    accepted: ["in_progress", "cancelled"],
    in_progress: ["completed", "cancelled"],
  };

  if (!transitions[ride.status] || !transitions[ride.status].includes(status)) {
    throw new HttpsError(
        "failed-precondition",
        `Cannot transition from '${ride.status}' to '${status}'.`,
    );
  }

  const updateData = {status};
  if (status === "completed") {
    updateData.completedAt = FieldValue.serverTimestamp();
  }

  await rideRef.update(updateData);

  // Send notifications
  if (status === "accepted") {
    // Notify rider that driver accepted
    const riderDoc = await db.collection("users").doc(ride.riderId).get();
    if (riderDoc.exists && riderDoc.data().fcmToken) {
      const driverDoc = await db.collection("drivers").doc(ride.driverId).get();
      const driverName = driverDoc.exists ? driverDoc.data().name : "Your driver";
      await getMessaging().send({
        token: riderDoc.data().fcmToken,
        notification: {
          title: "Ride Accepted!",
          body: `${driverName} is on the way.`,
        },
        data: {rideId, type: "ride_accepted"},
      });
    }
  }

  return {success: true};
});
