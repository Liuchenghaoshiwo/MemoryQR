# MemoryQR Placeholder Design

## Goal

Create a public-ready placeholder repository for MemoryQR, a small tool concept for storing memories in QR codes.

## Scope

This first version is intentionally lightweight. It presents the project idea, provides a static preview page, and includes a tiny tested payload module that future QR generation can build on. It does not implement real QR generation, account storage, image uploads, or cloud sync.

## Product Shape

The app is a single-page static site with:

- A clear `MemoryQR` identity.
- A short explanation of the concept.
- Placeholder workflow sections for writing a memory, generating a QR code, and reading it later.
- A small local demo that turns a title and message into a structured memory payload preview.
- Public repo assets: README, license, test command, and GitHub Pages workflow.

## Architecture

The repo uses zero runtime dependencies so it can run in any browser and deploy to GitHub Pages without a build step. Browser UI code lives in `src/app.js`, reusable memory payload behavior lives in `src/memoryPayload.js`, and Node's built-in test runner verifies the payload contract.

## Testing

The first tests cover the contract future QR features depend on:

- memory payloads include a stable schema id
- title and message are trimmed
- decoding rejects invalid JSON and unsupported schema versions

## Deployment

GitHub Pages will upload the repository root as a static artifact. The preview URL will become available after the repo is pushed and Pages is enabled by the workflow.
