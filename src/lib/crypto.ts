const KEY_ALGO = {
  name: 'RSA-OAEP',
  modulusLength: 2048,
  publicExponent: new Uint8Array([1, 0, 1]),
  hash: 'SHA-256',
} as const

export async function generateKeyPair(): Promise<CryptoKeyPair> {
  return window.crypto.subtle.generateKey(KEY_ALGO, true, ['encrypt', 'decrypt'])
}

export async function exportPublicKey(key: CryptoKey): Promise<string> {
  const exported = await window.crypto.subtle.exportKey('spki', key)
  return btoa(String.fromCharCode(...new Uint8Array(exported)))
}

export async function exportPrivateKey(key: CryptoKey): Promise<string> {
  const exported = await window.crypto.subtle.exportKey('pkcs8', key)
  return btoa(String.fromCharCode(...new Uint8Array(exported)))
}

export async function importPublicKey(b64: string): Promise<CryptoKey> {
  const binary = Uint8Array.from(atob(b64), c => c.charCodeAt(0))
  return window.crypto.subtle.importKey('spki', binary.buffer, KEY_ALGO, false, ['encrypt'])
}

export async function importPrivateKey(b64: string): Promise<CryptoKey> {
  const binary = Uint8Array.from(atob(b64), c => c.charCodeAt(0))
  return window.crypto.subtle.importKey('pkcs8', binary.buffer, KEY_ALGO, false, ['decrypt'])
}

export async function encryptMessage(plaintext: string, recipientPublicKey: CryptoKey): Promise<string> {
  const encoded = new TextEncoder().encode(plaintext)
  const encrypted = await window.crypto.subtle.encrypt({ name: 'RSA-OAEP' }, recipientPublicKey, encoded)
  return btoa(String.fromCharCode(...new Uint8Array(encrypted)))
}

export async function decryptMessage(ciphertext: string, privateKey: CryptoKey): Promise<string> {
  const binary = Uint8Array.from(atob(ciphertext), c => c.charCodeAt(0))
  const decrypted = await window.crypto.subtle.decrypt({ name: 'RSA-OAEP' }, privateKey, binary.buffer)
  return new TextDecoder().decode(decrypted)
}

/**
 * Initialize crypto for a user. On first call generates a keypair and stores
 * the private key in localStorage. Returns the private key and the public key
 * (base64) for uploading to the server. On subsequent calls returns only the
 * private key (public key already uploaded).
 */
export async function initUserCrypto(
  userId: string
): Promise<{ privateKey: CryptoKey; publicKeyB64?: string }> {
  const storageKey = `ijwi_priv_${userId}`
  const existing = localStorage.getItem(storageKey)

  if (existing) {
    const privateKey = await importPrivateKey(existing)
    return { privateKey }
  }

  const keyPair = await generateKeyPair()
  const privB64 = await exportPrivateKey(keyPair.privateKey)
  const publicKeyB64 = await exportPublicKey(keyPair.publicKey)
  localStorage.setItem(storageKey, privB64)
  return { privateKey: keyPair.privateKey, publicKeyB64 }
}
