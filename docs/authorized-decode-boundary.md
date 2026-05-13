# Authorized Decode Boundary MVP

MemoryQR now supports a local-first authorization boundary for encrypted QR payloads. This is an MVP decode gate, not a login system or cloud whitelist.

## Envelope Metadata

Encrypted envelopes include an `authorization` object:

```json
{
  "mode": "local-passphrase",
  "policy": "passphrase-only",
  "allowedReaderIds": []
}
```

Supported policies:

- `passphrase-only`: any scanner with the passphrase can attempt decryption.
- `local-reader-allowlist`: the scanner must provide a matching local reader ID before passphrase decryption is attempted.

Reader IDs are normalized to lowercase and may contain letters, numbers, dots, dashes, underscores, or colons.

## Decode Flow

1. Inspect the QR payload.
2. If the payload is plain MemoryQR JSON, parse it directly.
3. If the payload is encrypted, inspect the envelope authorization metadata.
4. If the policy is `local-reader-allowlist`, compare the supplied local reader ID with `allowedReaderIds`.
5. If the local reader is authorized, derive the passphrase key and decrypt the payload.

The authorization metadata is included in AES-GCM authenticated data for new encrypted envelopes, so tampering with the policy or allowlist makes decryption fail.

## Security Boundary

This MVP does not prove a reader's identity. The local reader ID is manually supplied app state, and the allowlist is visible in the QR envelope metadata.

The cryptographic privacy boundary is still the passphrase. The local allowlist is useful as an app-level decode boundary and a stable contract for future account or key-based authorization, but it should not be described as secure whitelist authorization.

## Future Direction

Future secure sharing should replace manually entered local reader IDs with a real authorization model, such as signed reader identities, public-key recipient grants, account-based ACLs, or encrypted storage references for media attachments.
