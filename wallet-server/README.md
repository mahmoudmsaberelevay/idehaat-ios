# Idehaat Wallet Server

This service accepts card data from the Idehaat iOS app and returns a signed Apple Wallet `.pkpass`. It does not store card data.

## Required secrets

Configure these values in Render's **Environment** page. Never commit them to the repository.

| Name | Value |
|---|---|
| `API_KEYS` | The API key copied to your password manager. Multiple keys may be comma-separated. |
| `PASS_P12_BASE64` | Base64 representation of the exported Pass Type ID `.p12`. |
| `PASS_P12_PASSWORD` | Password selected when exporting the `.p12`. |
| `WWDR_CERT_BASE64` | Base64 representation of `AppleWWDRCAG4.cer`. |
| `PASS_TYPE_IDENTIFIER` | `pass.com.mahmoudsaber.idehaat.cards` |
| `TEAM_IDENTIFIER` | `8M53HJ223G` |
| `ORGANIZATION_NAME` | `Idehaat` |

On macOS, copy the certificate values without writing unencrypted copies:

```bash
base64 -i "$HOME/Documents/Certificates.p12" | pbcopy
```

Paste that clipboard value into `PASS_P12_BASE64`. Then run:

```bash
base64 -i "$HOME/Downloads/AppleWWDRCAG4.cer" | pbcopy
```

Paste the new clipboard value into `WWDR_CERT_BASE64`.

## Deploy on Render

1. Push the repository to a private Git provider repository.
2. In Render, choose **New > Blueprint** and connect the repository.
3. Render reads the root `render.yaml` file and prompts for the four private values.
4. After deployment, open `https://YOUR-SERVICE.onrender.com/health`. It should return `{"status":"ok"}`.
5. Set the iOS URL to `https://YOUR-SERVICE.onrender.com/v1/passes` and use the same API key.

## Local validation

Install dependencies and run the non-secret tests:

```bash
npm install
npm test
```

The server uses the system OpenSSL executable to sign passes. It validates that the `.p12` certificate matches the configured Pass Type ID, Team ID, and private key at startup. It refuses to start with missing, mismatched, expired, or unreadable signing material.
