import express from "express";
import rateLimit from "express-rate-limit";
import helmet from "helmet";
import { extractCertificates } from "./certificates.js";
import { isAuthorized, loadConfig } from "./config.js";
import { createPass, parsePassRequest } from "./pass.js";

const config = loadConfig();
const certificates = extractCertificates(config);
const app = express();

app.set("trust proxy", 1);
app.disable("x-powered-by");
app.use(helmet());
app.use(express.json({ limit: "14mb", type: "application/json" }));

app.get("/health", (_request, response) => {
    response.json({ status: "ok" });
});

app.post(
    "/v1/passes",
    rateLimit({
        windowMs: 15 * 60 * 1000,
        limit: 30,
        standardHeaders: "draft-8",
        legacyHeaders: false,
    }),
    (request, response, next) => {
        try {
            if (!isAuthorized(request.get("X-API-Key"), config.apiKeys)) {
                return response.status(401).json({ error: "Unauthorized" });
            }

            const input = parsePassRequest(request.body);
            const pass = createPass(input, config, certificates);
            const safeSerial = input.serialNumber.replace(/[^A-Za-z0-9._-]/g, "-").slice(0, 80);

            response
                .status(200)
                .set({
                    "Content-Type": "application/vnd.apple.pkpass",
                    "Content-Disposition": `attachment; filename="idehaat-${safeSerial}.pkpass"`,
                    "Cache-Control": "no-store",
                })
                .send(pass);
        } catch (error) {
            next(error);
        }
    }
);

app.use((error, _request, response, _next) => {
    const statusCode = error.statusCode || (error.type === "entity.too.large" ? 413 : 500);
    if (statusCode >= 500) {
        console.error("Pass generation failed:", error.message);
    }

    response.status(statusCode).json({
        error: statusCode >= 500 ? "Unable to generate pass." : error.message,
        ...(error.details ? { details: error.details } : {}),
    });
});

app.listen(config.port, "0.0.0.0", () => {
    console.log(`Idehaat Wallet server is listening on port ${config.port}.`);
});
