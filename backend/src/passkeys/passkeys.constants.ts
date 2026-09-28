// WebAuthn configuration, driven by env vars with production defaults.

// A challenge must be used within this window or it expires.
export const WEBAUTHN_CHALLENGE_TTL_MS = 5 * 60 * 1000; // 5 minutes

export function getRpId(): string {
  return process.env.WEBAUTHN_RP_ID || 'clausulazos.vercel.app';
}

export function getRpName(): string {
  return process.env.WEBAUTHN_RP_NAME || 'Clausulazos';
}

/**
 * Allowed origins for WebAuthn ceremonies. They must match the RP ID's domain (or a subdomain),
 * protocol included. Extend or replace them with WEBAUTHN_ORIGINS (comma-separated).
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
