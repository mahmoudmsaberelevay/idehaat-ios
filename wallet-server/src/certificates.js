import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";

export function extractCertificates(config) {
    const certificateDirectory = fs.mkdtempSync(path.join(os.tmpdir(), "idehaat-wallet-"));
    fs.chmodSync(certificateDirectory, 0o700);

    const p12Path = path.join(certificateDirectory, "signer.p12");
    const signerCertPath = path.join(certificateDirectory, "signer.pem");
    const signerKeyPath = path.join(certificateDirectory, "signer-key.pem");
    const wwdrSourcePath = path.join(certificateDirectory, "wwdr-source.cer");
    const wwdrPath = path.join(certificateDirectory, "wwdr.pem");

    try {
        writeSecret(p12Path, decodeBase64(config.p12Base64, "PASS_P12_BASE64"));
        const commandEnvironment = {
            ...process.env,
            IDEHAAT_P12_PASSWORD: config.p12Password,
        };

        extractP12(p12Path, signerCertPath, signerKeyPath, commandEnvironment);
        fs.chmodSync(signerCertPath, 0o600);
        fs.chmodSync(signerKeyPath, 0o600);

        const wwdrBytes = decodeBase64(config.wwdrBase64, "WWDR_CERT_BASE64");
        if (wwdrBytes.toString("utf8", 0, 27).includes("-----BEGIN CERTIFICATE-----")) {
            writeSecret(wwdrPath, wwdrBytes);
        } else {
            writeSecret(wwdrSourcePath, wwdrBytes);
            runOpenSSL(["x509", "-inform", "DER", "-in", wwdrSourcePath, "-out", wwdrPath]);
            fs.chmodSync(wwdrPath, 0o600);
        }

        const signerPem = selectSignerCertificate(
            fs.readFileSync(signerCertPath, "utf8"),
            config.passTypeIdentifier
        );
        const signerKeyPem = fs.readFileSync(signerKeyPath, "utf8");
        const wwdrPem = fs.readFileSync(wwdrPath, "utf8");
        writeSecret(signerCertPath, signerPem);
        validateCertificates(signerPem, signerKeyPem, wwdrPem, config);

        fs.rmSync(p12Path, { force: true });
        fs.rmSync(wwdrSourcePath, { force: true });
        return Object.freeze({ signerCertPath, signerKeyPath, wwdrPath });
    } catch (error) {
        fs.rmSync(certificateDirectory, { recursive: true, force: true });
        if (error.message.startsWith("Certificate configuration error:")) {
            throw error;
        }
        throw new Error(
            "Certificate configuration error: unable to read the signing files. " +
            "Check PASS_P12_BASE64, PASS_P12_PASSWORD, and WWDR_CERT_BASE64."
        );
    }
}

function selectSignerCertificate(pemContents, passTypeIdentifier) {
    const certificates = pemContents.match(
        /-----BEGIN CERTIFICATE-----[\s\S]*?-----END CERTIFICATE-----/g
    ) || [];
    const expectedName = `CN=Pass Type ID: ${passTypeIdentifier}`;
    const matchingCertificate = certificates.find((certificate) => {
        try {
            return new crypto.X509Certificate(certificate).subject.includes(expectedName);
        } catch {
            return false;
        }
    });

    if (!matchingCertificate) {
        throw configurationError("the certificate does not match PASS_TYPE_IDENTIFIER.");
    }
    return `${matchingCertificate}\n`;
}

function validateCertificates(signerPem, signerKeyPem, wwdrPem, config) {
    const signer = new crypto.X509Certificate(signerPem);
    const wwdr = new crypto.X509Certificate(wwdrPem);

    if (!signer.subject.includes(`CN=Pass Type ID: ${config.passTypeIdentifier}`)) {
        throw configurationError("the certificate does not match PASS_TYPE_IDENTIFIER.");
    }
    if (!signer.subject.includes(`OU=${config.teamIdentifier}`)) {
        throw configurationError("the certificate does not match TEAM_IDENTIFIER.");
    }
    if (!wwdr.subject.includes("OU=G4")) {
        throw configurationError("WWDR_CERT_BASE64 must contain Apple WWDR G4.");
    }

    const now = Date.now();
    if (now < Date.parse(signer.validFrom) || now >= Date.parse(signer.validTo)) {
        throw configurationError("the Pass Type certificate is not currently valid.");
    }

    const privateKey = crypto.createPrivateKey(signerKeyPem);
    const publicFromKey = crypto.createPublicKey(privateKey).export({ type: "spki", format: "der" });
    const publicFromCertificate = signer.publicKey.export({ type: "spki", format: "der" });
    if (!crypto.timingSafeEqual(publicFromKey, publicFromCertificate)) {
        throw configurationError("the private key does not match the Pass Type certificate.");
    }
}

function decodeBase64(value, name) {
    const decoded = Buffer.from(value, "base64");
    if (decoded.length === 0) {
        throw configurationError(`${name} is empty or invalid.`);
    }
    return decoded;
}

function writeSecret(filePath, contents) {
    fs.writeFileSync(filePath, contents, { mode: 0o600 });
}

function runOpenSSL(argumentsList, environment = process.env) {
    execFileSync("openssl", argumentsList, {
        env: environment,
        stdio: ["ignore", "ignore", "pipe"],
        maxBuffer: 2_000_000,
    });
}

function extractP12(p12Path, certificatePath, keyPath, environment) {
    const extract = (legacy) => {
        const prefix = legacy ? ["pkcs12", "-legacy"] : ["pkcs12"];
        runOpenSSL([
            ...prefix, "-in", p12Path, "-clcerts", "-nokeys",
            "-out", certificatePath, "-passin", "env:IDEHAAT_P12_PASSWORD",
        ], environment);
        runOpenSSL([
            ...prefix, "-in", p12Path, "-nocerts", "-nodes",
            "-out", keyPath, "-passin", "env:IDEHAAT_P12_PASSWORD",
        ], environment);
    };

    try {
        extract(false);
    } catch {
        fs.rmSync(certificatePath, { force: true });
        fs.rmSync(keyPath, { force: true });
        extract(true);
    }
}

function configurationError(message) {
    return new Error(`Certificate configuration error: ${message}`);
}
