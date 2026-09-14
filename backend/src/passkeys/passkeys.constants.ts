// Centralized WebAuthn/Passkey configuration. Everything here is driven by
// env vars with sane production defaults, so nothing needs to be
// hardcoded per-environment and dev/prod can both work out of the box.

// A challenge must be used within this window or it's rejected as expired.
export const WEBAUTHN_CHALLENGE_TTL_MS = 5 * 60 * 1000; // 5 minutes

export function getRpId(): string {
  return process.env.WEBAUTHN_RP_ID || 'clausulazos.vercel.app';
}

export function getRpName(): string {
  return process.env.WEBAUTHN_RP_NAME || 'Clausulazos';
}

/**
 * Allowed origins for WebAuthn ceremonies. Must match the RP ID's domain
 * (or a subdomain) exactly, protocol included. Configure via
 * WEBAUTHN_ORIGINS (comma-separated) to add/replace entries — e.g. for a
 * custom domain — without touching code.
 */
export function getExpectedOrigins(): string[] {
  const configured = process.env.WEBAUTHN_ORIGINS;
  if (configured) {
    return configured.split(',').map((o) => o.trim()).filter(Boolean);
  }
  return [
    'https://clausulazos.vercel.app',
    // Local development (flutter run -d chrome / web-server default ports).
    'http://localhost:5000',
    'http://localhost:3000',
    'http://localhost:8080',
  ];
}
