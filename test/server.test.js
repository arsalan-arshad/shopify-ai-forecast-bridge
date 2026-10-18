import { describe, it, before } from 'node:test';
import assert from 'node:assert';
import crypto from 'crypto';
import app from '../src/server.js';
import { simulateRequest } from './helpers/mockRequest.js';

describe('Shopify Forecast Bridge Server API Endpoints', () => {
  before(() => {
    process.env.SHOPIFY_WEBHOOK_SECRET = 'unit_test_secret';
  });

  it('GET /health returns 200 and UP status', async () => {
    const res = await simulateRequest(app, 'GET', '/health');

    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.json.status, 'UP');
    assert.strictEqual(res.json.service, 'shopify-ai-forecast-bridge');
  });

  it('POST /api/forecast/calculate-wma returns weighted moving average', async () => {
    const res = await simulateRequest(app, 'POST', '/api/forecast/calculate-wma', {
      body: { dailyUsage: [10, 20, 30] }
    });

    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.json.wma, 23.33);
  });

  it('POST /api/forecast/webhook processes payload with valid HMAC', async () => {
    const payload = {
      sku: 'SKU-TEST-NODE',
      productTitle: 'Heavy Duty Alternator',
      quantityOnHand: 40,
      quantityReserved: 5,
      dailyUsageHistory: [5, 6, 4, 5],
      leadTimeDays: 14,
      supplierName: 'VoltCorp'
    };
    const bodyStr = JSON.stringify(payload);
    const signature = crypto.createHmac('sha256', 'unit_test_secret').update(bodyStr).digest('base64');

    const res = await simulateRequest(app, 'POST', '/api/forecast/webhook', {
      headers: {
        'x-shopify-forecast-signature': signature
      },
      body: bodyStr
    });

    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.json.status, 'SUCCESS');
    assert.strictEqual(res.json.snapshot.sku, 'SKU-TEST-NODE');
    assert.strictEqual(res.json.snapshot.daysOfCover > 0, true);
  });

  it('POST /api/forecast/webhook rejects invalid HMAC', async () => {
    const res = await simulateRequest(app, 'POST', '/api/forecast/webhook', {
      headers: {
        'x-shopify-forecast-signature': 'bogus_signature'
      },
      body: { sku: 'SKU-TEST' }
    });

    assert.strictEqual(res.status, 401);
  });

  it('POST /api/forecast/webhook rejects missing SKU', async () => {
    const bodyStr = JSON.stringify({ productTitle: 'No SKU Product' });
    const signature = crypto.createHmac('sha256', 'unit_test_secret').update(bodyStr).digest('base64');

    const res = await simulateRequest(app, 'POST', '/api/forecast/webhook', {
      headers: {
        'x-shopify-forecast-signature': signature
      },
      body: bodyStr
    });

    assert.strictEqual(res.status, 422);
  });

  it('POST /api/forecast/chat answers grounded conversational queries', async () => {
    const res = await simulateRequest(app, 'POST', '/api/forecast/chat', {
      body: { query: 'Which products will run out before Black Friday?' }
    });

    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.json.isGrounded, true);
    assert.strictEqual(typeof res.json.content, 'string');
    assert.strictEqual(res.json.content.length > 20, true);
  });

  it('GET /api/forecast/inventory returns list of snapshots', async () => {
    const res = await simulateRequest(app, 'GET', '/api/forecast/inventory');

    assert.strictEqual(res.status, 200);
    assert.strictEqual(Array.isArray(res.json.snapshots), true);
    assert.strictEqual(res.json.count > 0, true);
  });
});
