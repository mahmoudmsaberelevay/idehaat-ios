import test from "node:test";
import assert from "node:assert/strict";
import { createPassJson } from "../src/pass.js";

const request = {
    serialNumber: "test-card",
    title: "National ID",
    categoryName: "National ID",
    holderName: "Test User",
    number: "29104030102991",
    issuer: "Civil Registry",
    notes: "",
    expiryDate: null,
    backgroundColor: "#1C2840",
    foregroundColor: "#FFFFFF",
    labelColor: "#DCE6EA",
    barcodeMessage: null,
    labels: {
        expiry: "EXPIRES",
        holder: "NAME",
        number: "NUMBER",
        issuer: "ISSUER",
        category: "TYPE",
        notes: "NOTES",
        disclaimerTitle: "NOTE",
    },
    disclaimer: "Personal copy.",
    images: {},
};

const config = {
    passTypeIdentifier: "pass.com.mahmoudsaber.idehaat.cards",
    teamIdentifier: "8M53HJ223G",
    organizationName: "Idehaat",
};

test("keeps strip artwork clear of large primary-field text", () => {
    const pass = createPassJson(request, config);

    assert.equal(pass.logoText, "National ID");
    assert.equal("primaryFields" in pass.storeCard, false);
    assert.equal(pass.storeCard.auxiliaryFields[1].value, "National ID");
});
