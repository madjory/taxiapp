const {describe, it} = require("node:test");
const assert = require("node:assert");

// Set required env vars so firebase-admin initializes without a real project
process.env.GCLOUD_PROJECT = "test-project";
process.env.FIREBASE_CONFIG = JSON.stringify({projectId: "test-project"});

describe("Cloud Functions exports", () => {
  it("should export all expected functions", () => {
    const functions = require("../index");

    assert.ok(functions.onDriverLocationUpdate, "onDriverLocationUpdate should be exported");
    assert.ok(functions.getNearbyDrivers, "getNearbyDrivers should be exported");
    assert.ok(functions.createRideRequest, "createRideRequest should be exported");
    assert.ok(functions.updateRideStatus, "updateRideStatus should be exported");
  });

  it("should export exactly 4 functions", () => {
    const functions = require("../index");
    const exported = Object.keys(functions);
    assert.strictEqual(exported.length, 4, `Expected 4 exports, got: ${exported.join(", ")}`);
  });
});
