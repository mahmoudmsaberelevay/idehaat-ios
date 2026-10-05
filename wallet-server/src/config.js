import crypto from "node:crypto";

const requiredNames = [
    "API_KEYS",
    "PASS_TYPE_IDENTIFIER",
    "TEAM_IDENTIFIER",
    "PASS_P12_BASE64",
    "PASS_P12_PASSWORD",
    "WWDR_CERT_BASE64",
];

export function loadConfig(environment = process.env) {
    const missing = requiredNames.filter((name) => !environment[name]?.trim());
    if (missing.length > 0) {
        throw new Error(`Missing required environment variables: ${missing.join(", ")}`);
    }

    const apiKeys = environment.API_KEYS
        .split(",")
        .map((key) => key.trim())
        .filter(Boolean);

    if (apiKeys.some((key) => key.length < 32)) {
        throw new Error("Every API key must contain at least 32 characters.");
    }

    const passTypeIdentifier = environment.PASS_TYPE_IDENTIFIER.trim();
    if (!passTypeIdentifier.startsWith("pass.")) {
        throw new Error("PASS_TYPE_IDENTIFIER must start with 'pass.'.");
    }

    return Object.freeze({
        apiKeys,
        passTypeIdentifier,
        teamIdentifier: environment.TEAM_IDENTIFIER.trim(),
        organizationName: environment.ORGANIZATION_NAME?.trim() || "Idehaat",
        p12Base64: normalizeBase64(environment.PASS_P12_BASE64),
        p12Password: environment.PASS_P12_PASSWORD,
        wwdrBase64: normalizeBase64(environment.WWDR_CERT_BASE64),
        port: Number.parseInt(environment.PORT || "3000", 10),
    });
}

export function isAuthorized(providedKey, configuredKeys) {
    if (typeof providedKey !== "string" || providedKey.length === 0) {
        return false;
    }

    const providedDigest = crypto.createHash("sha256").update(providedKey).digest();
    return configuredKeys.some((configuredKey) => {
        const configuredDigest = crypto.createHash("sha256").update(configuredKey).digest();
        return crypto.timingSafeEqual(providedDigest, configuredDigest);
    });
}

function normalizeBase64(value) {
    return value.replace(/\s+/g, "");
}
