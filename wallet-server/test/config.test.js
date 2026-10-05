import test from "node:test";
import assert from "node:assert/strict";
import { isAuthorized, loadConfig } from "../src/config.js";

const validEnvironment = {
    API_KEYS: "a".repeat(32),
    PASS_TYPE_IDENTIFIER: "pass.com.mahmoudsaber.idehaat.cards",
    TEAM_IDENTIFIER: "8M53HJ223G",
    PASS_P12_BASE64: "ZmFrZQ==",
    PASS_P12_PASSWORD: "private-password",
    WWDR_CERT_BASE64: "ZmFrZQ==",
};

test("loads a valid configuration", () => {
    const config = loadConfig(validEnvironment);
    assert.equal(config.passTypeIdentifier, "pass.com.mahmoudsaber.idehaat.cards");
    assert.deepEqual(config.apiKeys, ["a".repeat(32)]);
});

test("rejects short API keys", () => {
    assert.throws(
        () => loadConfig({ ...validEnvironment, API_KEYS: "too-short" }),
        /at least 32 characters/
    );
});

test("compares API keys", () => {
    assert.equal(isAuthorized("a".repeat(32), ["a".repeat(32)]), true);
    assert.equal(isAuthorized("b".repeat(32), ["a".repeat(32)]), false);
    assert.equal(isAuthorized(undefined, ["a".repeat(32)]), false);
});
