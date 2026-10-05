import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { zipSync } from "fflate";
import { z } from "zod";

const currentDirectory = path.dirname(fileURLToPath(import.meta.url));
const assetsDirectory = path.resolve(currentDirectory, "../assets");

const requestSchema = z.object({
    serialNumber: z.string().trim().min(1).max(128),
    title: z.string().trim().min(1).max(80),
    categoryName: z.string().trim().max(80),
    holderName: z.string().trim().max(120),
    number: z.string().trim().max(160),
    issuer: z.string().trim().max(120),
    notes: z.string().trim().max(1_500),
    expiryDate: z.iso.datetime({ offset: true }).nullable().optional(),
    backgroundColor: z.string().regex(/^#[0-9A-Fa-f]{6}$/),
    foregroundColor: z.string().regex(/^#[0-9A-Fa-f]{6}$/),
    labelColor: z.string().regex(/^#[0-9A-Fa-f]{6}$/),
    barcodeMessage: z.string().trim().min(1).max(500).nullable().optional(),
    labels: z.record(z.string(), z.string().max(80)),
    disclaimer: z.string().trim().max(1_500),
    images: z.record(z.string(), z.string()).default({}),
}).strict();

const allowedImages = new Set(["strip.png", "strip@2x.png", "strip@3x.png"]);
const pngSignature = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

export function parsePassRequest(value) {
    const result = requestSchema.safeParse(value);
    if (!result.success) {
        const details = result.error.issues.map((issue) => ({
            path: issue.path.join("."),
            message: issue.message,
        }));
        const error = new Error("Invalid pass request.");
        error.statusCode = 400;
        error.details = details;
        throw error;
    }

    for (const [name, encoded] of Object.entries(result.data.images)) {
        if (!allowedImages.has(name)) {
            throw validationError(`Unsupported image name: ${name}`);
        }
        const image = Buffer.from(encoded, "base64");
        if (image.length === 0 || image.length > 4_000_000 || !image.subarray(0, 8).equals(pngSignature)) {
            throw validationError(`${name} must be a PNG smaller than 4 MB.`);
        }
    }

    return result.data;
}

export function createPass(request, config, certificates) {
    const passJson = {
        formatVersion: 1,
        passTypeIdentifier: config.passTypeIdentifier,
        teamIdentifier: config.teamIdentifier,
        organizationName: config.organizationName,
        description: `${request.title} card`,
        serialNumber: request.serialNumber,
        logoText: request.title,
        backgroundColor: walletColor(request.backgroundColor),
        foregroundColor: walletColor(request.foregroundColor),
        labelColor: walletColor(request.labelColor),
        ...(request.expiryDate ? { expirationDate: request.expiryDate } : {}),
        storeCard: {
            headerFields: compactFields([
                field("expiry", request.labels.expiry, displayDate(request.expiryDate)),
            ]),
            primaryFields: [field("title", "", request.title)],
            secondaryFields: compactFields([
                field("holder", request.labels.holder, request.holderName),
                field("number", request.labels.number, request.number),
            ]),
            auxiliaryFields: compactFields([
                field("issuer", request.labels.issuer, request.issuer),
                field("category", request.labels.category, request.categoryName),
            ]),
            backFields: compactFields([
                field("notes", request.labels.notes, request.notes),
                field("disclaimer", request.labels.disclaimerTitle, request.disclaimer),
            ]),
        },
        ...(request.barcodeMessage ? {
            barcodes: [{
                format: "PKBarcodeFormatQR",
                message: request.barcodeMessage,
                messageEncoding: "iso-8859-1",
                altText: request.barcodeMessage,
            }],
        } : {}),
    };

    const files = {
        "pass.json": Buffer.from(JSON.stringify(passJson)),
        "icon.png": fs.readFileSync(path.join(assetsDirectory, "icon.png")),
        "icon@2x.png": fs.readFileSync(path.join(assetsDirectory, "icon@2x.png")),
        "icon@3x.png": fs.readFileSync(path.join(assetsDirectory, "icon@3x.png")),
        "logo.png": fs.readFileSync(path.join(assetsDirectory, "logo.png")),
        "logo@2x.png": fs.readFileSync(path.join(assetsDirectory, "logo@2x.png")),
        "logo@3x.png": fs.readFileSync(path.join(assetsDirectory, "logo@3x.png")),
    };

    for (const [name, encoded] of Object.entries(request.images)) {
        files[name] = Buffer.from(encoded, "base64");
    }

    const manifest = {};
    for (const [name, contents] of Object.entries(files)) {
        manifest[name] = crypto.createHash("sha1").update(contents).digest("hex");
    }
    files["manifest.json"] = Buffer.from(JSON.stringify(manifest));
    files.signature = signManifest(files["manifest.json"], certificates);

    return Buffer.from(zipSync(files, { level: 6 }));
}

function signManifest(manifest, certificates) {
    try {
        return execFileSync("openssl", [
            "smime", "-binary", "-sign",
            "-certfile", certificates.wwdrPath,
            "-signer", certificates.signerCertPath,
            "-inkey", certificates.signerKeyPath,
            "-outform", "DER",
        ], {
            input: manifest,
            stdio: ["pipe", "pipe", "pipe"],
            maxBuffer: 2_000_000,
        });
    } catch {
        throw new Error("OpenSSL could not sign the Wallet pass.");
    }
}

function walletColor(hex) {
    const red = Number.parseInt(hex.slice(1, 3), 16);
    const green = Number.parseInt(hex.slice(3, 5), 16);
    const blue = Number.parseInt(hex.slice(5, 7), 16);
    return `rgb(${red}, ${green}, ${blue})`;
}

function field(key, label, value) {
    return { key, label: label || "", value: value || "" };
}

function compactFields(fields) {
    return fields.filter((item) => item.value.length > 0);
}

function displayDate(value) {
    if (!value) return "";
    return new Intl.DateTimeFormat("en", {
        year: "numeric",
        month: "short",
        day: "numeric",
        timeZone: "UTC",
    }).format(new Date(value));
}

function validationError(message) {
    const error = new Error(message);
    error.statusCode = 400;
    return error;
}
