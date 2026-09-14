// WebAuthn browser bridge for Clausulazos.
//
// The backend (@simplewebauthn/server) speaks JSON with base64url-encoded
// binary fields (challenge, credential ids, etc.) — exactly the format
// @simplewebauthn/browser would produce/consume. The native
// `navigator.credentials.create()/get()` APIs, however, need real
// ArrayBuffers for those same fields. This file is the translation layer,
// so the Dart side (lib/core/webauthn/webauthn_client.dart) only ever
// has to deal with plain JSON.
(function () {
  function bufferToBase64url(buffer) {
    const bytes = new Uint8Array(buffer);
    let str = '';
    for (let i = 0; i < bytes.length; i++) str += String.fromCharCode(bytes[i]);
    return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  }

  function base64urlToBuffer(base64url) {
    const padding = '='.repeat((4 - (base64url.length % 4)) % 4);
    const base64 = (base64url + padding).replace(/-/g, '+').replace(/_/g, '/');
    const str = atob(base64);
    const bytes = new Uint8Array(str.length);
    for (let i = 0; i < str.length; i++) bytes[i] = str.charCodeAt(i);
    return bytes.buffer;
  }

  function transformCreationOptions(options) {
    const transformed = Object.assign({}, options);
    transformed.challenge = base64urlToBuffer(options.challenge);
    transformed.user = Object.assign({}, options.user, {
      id: base64urlToBuffer(options.user.id),
    });
    if (options.excludeCredentials) {
      transformed.excludeCredentials = options.excludeCredentials.map(function (c) {
        return Object.assign({}, c, { id: base64urlToBuffer(c.id) });
      });
    }
    return transformed;
  }

  function transformRequestOptions(options) {
    const transformed = Object.assign({}, options);
    transformed.challenge = base64urlToBuffer(options.challenge);
    if (options.allowCredentials) {
      transformed.allowCredentials = options.allowCredentials.map(function (c) {
        return Object.assign({}, c, { id: base64urlToBuffer(c.id) });
      });
    }
    return transformed;
  }

  function credentialToJSON(credential) {
    const response = credential.response;
    const clientExtensionResults = credential.getClientExtensionResults
      ? credential.getClientExtensionResults()
      : {};

    const json = {
      id: credential.id,
      rawId: bufferToBase64url(credential.rawId),
      type: credential.type,
      clientExtensionResults: clientExtensionResults,
      response: {
        clientDataJSON: bufferToBase64url(response.clientDataJSON),
      },
    };

    if (credential.authenticatorAttachment) {
      json.authenticatorAttachment = credential.authenticatorAttachment;
    }

    if (response.attestationObject) {
      // Registration ceremony.
      json.response.attestationObject = bufferToBase64url(response.attestationObject);
      if (response.getTransports) {
        try {
          json.response.transports = response.getTransports();
        } catch (e) {
          /* not fatal — transports are informational only */
        }
      }
      if (response.getAuthenticatorData) {
        try {
          json.response.authenticatorData = bufferToBase64url(response.getAuthenticatorData());
        } catch (e) {
          /* optional field */
        }
      }
      if (response.getPublicKeyAlgorithm) {
        try {
          json.response.publicKeyAlgorithm = response.getPublicKeyAlgorithm();
        } catch (e) {
          /* optional field */
        }
      }
      if (response.getPublicKey) {
        try {
          const pk = response.getPublicKey();
          if (pk) json.response.publicKey = bufferToBase64url(pk);
        } catch (e) {
          /* optional field */
        }
      }
    } else {
      // Authentication ceremony.
      json.response.authenticatorData = bufferToBase64url(response.authenticatorData);
      json.response.signature = bufferToBase64url(response.signature);
      if (response.userHandle) {
        json.response.userHandle = bufferToBase64url(response.userHandle);
      }
    }

    return json;
  }

  window.clausulazosWebAuthn = {
    isSupported: function () {
      return !!(
        window.PublicKeyCredential &&
        window.navigator.credentials &&
        window.navigator.credentials.create
      );
    },

    isPlatformAuthenticatorAvailable: async function () {
      if (
        !window.PublicKeyCredential ||
        !window.PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable
      ) {
        return false;
      }
      try {
        return await window.PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable();
      } catch (e) {
        return false;
      }
    },

    register: async function (optionsJsonString) {
      const options = JSON.parse(optionsJsonString);
      const publicKey = transformCreationOptions(options);
      const credential = await navigator.credentials.create({ publicKey: publicKey });
      if (!credential) throw new Error('No se ha podido crear la passkey.');
      return JSON.stringify(credentialToJSON(credential));
    },

    authenticate: async function (optionsJsonString) {
      const options = JSON.parse(optionsJsonString);
      const publicKey = transformRequestOptions(options);
      const credential = await navigator.credentials.get({ publicKey: publicKey });
      if (!credential) throw new Error('No se ha podido verificar la passkey.');
      return JSON.stringify(credentialToJSON(credential));
    },
  };
})();
