# MemoryQR

MemoryQR is an early prototype for a small tool that stores memories inside QR-friendly payloads.

This repository is currently a public placeholder and project shell. The first version introduces the product idea, a static preview page, and a tiny tested payload module that future QR generation can build on.

## Preview

The app is designed to run as a static site and deploy through GitHub Pages.

## Current Status

- Static landing page for the project
- Memory payload preview demo
- Tested payload creation and parsing helpers
- GitHub Pages workflow

## Roadmap

- Generate real QR codes from memory payloads
- Scan and decode MemoryQR payloads
- Add export and download options
- Explore local-first storage for private memories

## Run Locally

No dependency install is required.

```bash
python3 -m http.server 4173
```

Then open:

```text
http://localhost:4173
```

## Test

```bash
node --test test/*.test.js
```

## License

MIT
