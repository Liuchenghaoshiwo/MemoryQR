# MemoryQR Project Context

## Project

MemoryQR is a public open-source app concept by Chenghao Liu.

The goal is to build a small tool that lets people store personal memories in QR-code-friendly payloads. The current repository is intentionally an early placeholder: it presents the idea, provides a static preview, and defines a tiny tested payload contract for future QR generation.

## Current State

- GitHub repository: https://github.com/Liuchenghaoshiwo/MemoryQR
- Live preview: https://liuchenghaoshiwo.github.io/MemoryQR/
- Deployment: GitHub Pages through `.github/workflows/pages.yml`
- Runtime: zero-dependency static HTML/CSS/JavaScript
- Tests: Node built-in test runner

## Important Files

- `index.html` - static app shell and public preview page
- `src/styles.css` - visual design and responsive layout
- `src/app.js` - browser-side demo behavior
- `src/memoryPayload.js` - memory payload create/parse helpers
- `test/memoryPayload.test.js` - payload contract tests
- `README.md` - public-facing repository introduction
- `.github/workflows/pages.yml` - GitHub Pages deployment workflow

## Product Direction

The eventual app should let users:

1. Write a memory with a title, message, and optional metadata.
2. Encode that memory into a QR code.
3. Save, share, print, or download the QR code.
4. Scan a MemoryQR later and recover the original memory.

Privacy matters. Prefer local-first behavior unless the user explicitly asks for accounts, cloud sync, or sharing services.

## Current Non-Goals

Do not pretend the app is complete. The current version does not yet include:

- real QR code generation
- QR scanning
- file or image attachment support
- cloud storage
- login or user accounts

## Next Good Tasks

Recommended next implementation steps:

1. Add real QR generation from the existing memory payload.
2. Add a download button for the generated QR image.
3. Add QR decode/scanning support.
4. Improve README with screenshots once the real QR flow exists.
5. Add more tests around payload size, empty fields, and invalid payloads.

## Development Notes

Use the existing lightweight static structure unless the requested feature clearly needs a framework. Keep the public repo clean and easy to understand for visitors who may want to star, fork, or learn from it.

Before claiming work is complete, run:

```bash
node --test test/*.test.js
```
