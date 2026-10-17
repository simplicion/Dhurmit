import { describe, it, expect } from 'vitest';
import crypto from 'crypto';
import { verify180WebhookSignature } from '../../src/modules/identity/presentation/routes.js';

describe('180 Identity Authentication & Webhook Cryptographic Verification Tests', () => {
  const secret = 'whsec_4ea6988e7fca03a2bdb4f7f4316814659a1e056aeb82ce35';

  function createSignature(rawBody: string, timestamp: number, secretKey: string): string {
    const payload = `${timestamp}.${rawBody}`;
    return crypto.createHmac('sha256', secretKey).update(payload).digest('hex');
  }

  it('validates authentic webhook with valid HMAC signature and current timestamp', () => {
    const rawBody = JSON.stringify({ type: 'user.updated', data: { id: 'usr_123', email: 'organizer@180core.cloud' } });
    const timestamp = Math.floor(Date.now() / 1000);
    const signature = createSignature(rawBody, timestamp, secret);

    const isValid = verify180WebhookSignature({
      rawBody,
      signature,
      timestamp: timestamp.toString(),
      secret,
    });

    expect(isValid).toBe(true);
  });

  it('rejects webhook with expired timestamp (replay attack defense)', () => {
    const rawBody = JSON.stringify({ type: 'user.updated', data: { id: 'usr_123' } });
    const oldTimestamp = Math.floor(Date.now() / 1000) - 600; // 10 minutes ago (> 300s tolerance)
    const signature = createSignature(rawBody, oldTimestamp, secret);

    const isValid = verify180WebhookSignature({
      rawBody,
      signature,
      timestamp: oldTimestamp.toString(),
      secret,
      toleranceSeconds: 300,
    });

    expect(isValid).toBe(false);
  });

  it('rejects webhook with modified or tampered payload body', () => {
    const rawBody = JSON.stringify({ type: 'user.updated', data: { id: 'usr_123' } });
    const tamperedBody = JSON.stringify({ type: 'user.updated', data: { id: 'usr_attacker' } });
    const timestamp = Math.floor(Date.now() / 1000);
    const signature = createSignature(rawBody, timestamp, secret);

    const isValid = verify180WebhookSignature({
      rawBody: tamperedBody,
      signature,
      timestamp: timestamp.toString(),
      secret,
    });

    expect(isValid).toBe(false);
  });

  it('rejects webhook signed with an incorrect secret key', () => {
    const rawBody = JSON.stringify({ type: 'user.registered' });
    const timestamp = Math.floor(Date.now() / 1000);
    const signature = createSignature(rawBody, timestamp, 'wrong_secret_123456');

    const isValid = verify180WebhookSignature({
      rawBody,
      signature,
      timestamp: timestamp.toString(),
      secret,
    });

    expect(isValid).toBe(false);
  });

  it('returns false for missing or malformed parameters', () => {
    expect(verify180WebhookSignature({ rawBody: '', signature: 'abc', timestamp: '123', secret })).toBe(false);
    expect(verify180WebhookSignature({ rawBody: '{}', signature: '', timestamp: '123', secret })).toBe(false);
    expect(verify180WebhookSignature({ rawBody: '{}', signature: 'abc', timestamp: '', secret })).toBe(false);
    expect(verify180WebhookSignature({ rawBody: '{}', signature: 'abc', timestamp: 'not-a-number', secret })).toBe(false);
  });
});
