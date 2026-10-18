import { describe, it } from 'node:test';
import assert from 'node:assert';
import crypto from 'crypto';
import {
  calculateWMA,
  calculateDaysOfCover,
  calculateReorderPoint,
  determineRiskLevel,
  verifyShopifyHmac
} from '../src/services/forecastBridge.js';

describe('Shopify Forecast Bridge Calculation Engine', () => {
  describe('calculateWMA', () => {
    it('calculates weighted moving average correctly for 3 days [10, 20, 30]', () => {
      // weights: [1, 2, 3] -> sum = 6
      // weighted sum: 10*1 + 20*2 + 30*3 = 10 + 40 + 90 = 140
      // 140 / 6 = 23.333... -> 23.33
      const result = calculateWMA([10, 20, 30]);
      assert.strictEqual(result, 23.33);
    });

    it('returns 0 for empty or invalid input', () => {
      assert.strictEqual(calculateWMA([]), 0);
      assert.strictEqual(calculateWMA(null), 0);
    });

    it('supports custom weights', () => {
      // weights: [1, 1, 2] -> sum = 4
      // weighted sum: 10*1 + 10*1 + 20*2 = 10 + 10 + 40 = 60 / 4 = 15
      const result = calculateWMA([10, 10, 20], [1, 1, 2]);
      assert.strictEqual(result, 15);
    });
  });

  describe('calculateDaysOfCover', () => {
    it('calculates days of cover based on available inventory and velocity', () => {
      // onHand: 100, reserved: 20 -> available: 80, velocity: 4 -> 20.0
      assert.strictEqual(calculateDaysOfCover(100, 20, 4), 20.0);
    });

    it('returns 999 if velocity is zero and available stock exists', () => {
      assert.strictEqual(calculateDaysOfCover(50, 0, 0), 999.0);
    });

    it('returns 0 if available stock is zero or negative', () => {
      assert.strictEqual(calculateDaysOfCover(10, 20, 5), 0.0);
    });
  });

  describe('calculateReorderPoint', () => {
    it('calculates reorder point incorporating lead time and safety buffer', () => {
      // velocity: 5, leadTime: 14, safety: 3 -> 5 * (14 + 3) = 85
      assert.strictEqual(calculateReorderPoint(5, 14, 3), 85);
    });
  });

  describe('determineRiskLevel', () => {
    it('returns CRITICAL when days of cover <= lead time', () => {
      assert.strictEqual(determineRiskLevel(10, 14), 'CRITICAL');
      assert.strictEqual(determineRiskLevel(14, 14), 'CRITICAL');
    });

    it('returns REORDER_SOON when days of cover <= 1.5 * lead time', () => {
      assert.strictEqual(determineRiskLevel(18, 14), 'REORDER_SOON');
      assert.strictEqual(determineRiskLevel(21, 14), 'REORDER_SOON');
    });

    it('returns HEALTHY when days of cover > 1.5 * lead time', () => {
      assert.strictEqual(determineRiskLevel(30, 14), 'HEALTHY');
    });
  });

  describe('verifyShopifyHmac', () => {
    const secret = 'test_secret_123';
    const body = JSON.stringify({ sku: 'SKU-001' });

    it('validates a correct base64 HMAC signature', () => {
      const sig = crypto.createHmac('sha256', secret).update(body).digest('base64');
      assert.strictEqual(verifyShopifyHmac(body, sig, secret), true);
    });

    it('validates a correct hex HMAC signature', () => {
      const sig = crypto.createHmac('sha256', secret).update(body).digest('hex');
      assert.strictEqual(verifyShopifyHmac(body, sig, secret), true);
    });

    it('rejects an invalid signature', () => {
      assert.strictEqual(verifyShopifyHmac(body, 'invalid_sig', secret), false);
      assert.strictEqual(verifyShopifyHmac(body, null, secret), false);
    });
  });
});
