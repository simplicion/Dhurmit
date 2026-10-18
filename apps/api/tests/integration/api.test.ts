// apps/api/tests/integration/api.test.ts
process.env['NODE_ENV'] = 'test';
process.env['DATABASE_URL'] = 'postgres://postgres:postgres@localhost:5432/committee_ledger_test';
process.env['JWT_ACCESS_SECRET'] = 'test_access_secret_key_at_least_32_characters_long';
process.env['JWT_REFRESH_SECRET'] = 'test_refresh_secret_key_at_least_32_characters_long';

import { describe, it, expect } from 'vitest';
import request from 'supertest';
import { createApp } from '../../src/app.js';

describe('API Foundation, Health & Security Integration Tests', () => {
  const app = createApp();

  describe('Health & Observability Endpoints', () => {
    it('responds with 200 and uptime on /health/live', async () => {
      const res = await request(app).get('/health/live');
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('ok');
      expect(typeof res.body.uptime).toBe('number');
    });

    it('responds with JSON content type on health check', async () => {
      const res = await request(app).get('/health/live');
      expect(res.headers['content-type']).toMatch(/application\/json/);
    });
  });

  describe('Routing & 404 Handling', () => {
    it('returns 404 for unknown route under /api/v1', async () => {
      const res = await request(app).get('/api/v1/unregistered-path-xyz');
      expect(res.status).toBe(404);
      expect(res.body.error).toBeDefined();
      expect(res.body.error.code).toBe('NOT_FOUND');
    });

    it('returns 404 for unknown top-level route', async () => {
      const res = await request(app).get('/non-existent-top-level');
      expect(res.status).toBe(404);
      expect(res.body.error.code).toBe('NOT_FOUND');
    });
  });

  describe('Authentication Gateways & Input Validation', () => {
    it('rejects registration with missing payload', async () => {
      const res = await request(app).post('/api/v1/auth/register').send({});
      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
      expect(Array.isArray(res.body.error.details)).toBe(true);
    });

    it('rejects registration with invalid email format', async () => {
      const res = await request(app).post('/api/v1/auth/register').send({
        displayName: 'Organizer Name',
        email: 'not-an-email',
        password: 'ValidPassword123!',
      });
      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    });

    it('rejects registration with short password (< 8 chars)', async () => {
      const res = await request(app).post('/api/v1/auth/register').send({
        displayName: 'Organizer Name',
        email: 'organizer@example.com',
        password: 'short',
      });
      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    });

    it('rejects registration with short display name (< 2 chars)', async () => {
      const res = await request(app).post('/api/v1/auth/register').send({
        displayName: 'A',
        email: 'organizer@example.com',
        password: 'ValidPassword123!',
      });
      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    });

    it('rejects login with missing password', async () => {
      const res = await request(app).post('/api/v1/auth/login').send({
        email: 'organizer@example.com',
      });
      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    });

    it('rejects login with missing email', async () => {
      const res = await request(app).post('/api/v1/auth/login').send({
        password: 'Password123!',
      });
      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    });

    it('rejects refresh token request without refresh token in body', async () => {
      const res = await request(app).post('/api/v1/auth/refresh').send({});
      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    });
  });

  describe('Authorization & Bearer Token Gates', () => {
    it('rejects GET /api/v1/workspaces when no authorization header is provided', async () => {
      const res = await request(app).get('/api/v1/workspaces');
      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('UNAUTHENTICATED');
    });

    it('rejects GET /api/v1/committees when no authorization header is provided', async () => {
      const res = await request(app).get('/api/v1/committees');
      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('UNAUTHENTICATED');
    });

    it('rejects GET /api/v1/committees/:committeeId/members when no authorization header is provided', async () => {
      const res = await request(app).get('/api/v1/committees/00000000-0000-0000-0000-000000000000/members');
      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('UNAUTHENTICATED');
    });

    it('rejects protected routes when token format is not Bearer', async () => {
      const res = await request(app)
        .get('/api/v1/workspaces')
        .set('Authorization', 'Basic user:pass');
      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('UNAUTHENTICATED');
    });

    it('rejects protected routes when Bearer token is corrupted/invalid', async () => {
      const res = await request(app)
        .get('/api/v1/workspaces')
        .set('Authorization', 'Bearer invalid.tampered.jwt.signature');
      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('UNAUTHENTICATED');
    });
  });

  describe('180 Identity Integration Endpoints', () => {
    it('returns public 180 client configuration on GET /api/v1/auth/180/config', async () => {
      const res = await request(app).get('/api/v1/auth/180/config');
      expect(res.status).toBe(200);
      expect(res.body.data).toBeDefined();
      expect(res.body.data.clientId).toBe('180_client_3b759b500c4b8a04f888ec3d91a82bd3');
      expect(res.body.data.authUrl).toBeDefined();
      expect(res.body.data.apiUrl).toBeDefined();
    });

    it('rejects /api/v1/auth/180/exchange without code in body', async () => {
      const res = await request(app).post('/api/v1/auth/180/exchange').send({});
      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    });

    it('rejects /api/v1/auth/180/webhook without signature headers', async () => {
      const res = await request(app)
        .post('/api/v1/auth/180/webhook')
        .send({ type: 'user.updated' });
      expect(res.status).toBe(401);
    });
  });

  describe('Ledger Collection Recording Endpoints', () => {
    it('rejects POST /api/v1/committees/:id/collections without auth header', async () => {
      const res = await request(app)
        .post('/api/v1/committees/00000000-0000-0000-0000-000000000000/collections')
        .send({
          memberId: '00000000-0000-0000-0000-000000000001',
          amountMinor: 200000,
          receivedAt: new Date().toISOString(),
        });
      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('UNAUTHENTICATED');
    });

    it('rejects POST /api/v1/committees/:id/collections with negative or zero amount', async () => {
      // Create mock token with generateAccessToken
      const { generateAccessToken } = await import('../../src/shared/presentation/middlewares/auth.middleware.js');
      const token = generateAccessToken({
        userId: '00000000-0000-0000-0000-000000000000',
        email: 'test@example.com',
        workspaceId: '00000000-0000-0000-0000-000000000001',
      });

      const res = await request(app)
        .post('/api/v1/committees/00000000-0000-0000-0000-000000000000/collections')
        .set('Authorization', `Bearer ${token}`)
        .send({
          memberId: '00000000-0000-0000-0000-000000000002',
          amountMinor: -500,
          receivedAt: new Date().toISOString(),
        });
      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    });
  });
});
