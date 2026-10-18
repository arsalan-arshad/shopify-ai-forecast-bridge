import crypto from 'crypto';

/**
 * Validates Shopify HMAC-SHA256 signature using timing-safe comparison.
 * @param {string|Buffer} rawBody
 * @param {string} signature - Header signature (base64 or hex)
 * @param {string} secret - Shared secret key
 * @returns {boolean}
 */
export function verifyShopifyHmac(rawBody, signature, secret) {
  if (!signature || !secret || !rawBody) {
    return false;
  }

  const hmac = crypto.createHmac('sha256', secret).update(rawBody);
  const digestBase64 = hmac.digest('base64');
  const hmacHex = crypto.createHmac('sha256', secret).update(rawBody).digest('hex');

  try {
    const sigBuffer = Buffer.from(signature);
    const expectedBase64Buffer = Buffer.from(digestBase64);
    const expectedHexBuffer = Buffer.from(hmacHex);

    if (sigBuffer.length === expectedBase64Buffer.length && crypto.timingSafeEqual(sigBuffer, expectedBase64Buffer)) {
      return true;
    }
    if (sigBuffer.length === expectedHexBuffer.length && crypto.timingSafeEqual(sigBuffer, expectedHexBuffer)) {
      return true;
    }
    return false;
  } catch (_e) {
    return false;
  }
}

/**
 * Calculates Weighted Moving Average (WMA) for daily consumption.
 * @param {number[]} dailyUsage - Array of daily consumption numbers (most recent last)
 * @param {number[]} [customWeights] - Optional custom weights
 * @returns {number} Rounded to 2 decimal places
 */
export function calculateWMA(dailyUsage, customWeights) {
  if (!Array.isArray(dailyUsage) || dailyUsage.length === 0) {
    return 0;
  }

  const n = dailyUsage.length;
  const weights =
    Array.isArray(customWeights) && customWeights.length === n
      ? customWeights
      : Array.from({ length: n }, (_, i) => i + 1); // [1, 2, 3, ...]

  const totalWeight = weights.reduce((sum, w) => sum + w, 0);
  if (totalWeight === 0) return 0;

  const weightedSum = dailyUsage.reduce((sum, val, idx) => sum + (val || 0) * weights[idx], 0);
  return Math.round((weightedSum / totalWeight) * 100) / 100;
}

/**
 * Calculates Days of Cover.
 * @param {number} quantityOnHand
 * @param {number} quantityReserved
 * @param {number} dailyVelocity
 * @returns {number}
 */
export function calculateDaysOfCover(quantityOnHand = 0, quantityReserved = 0, dailyVelocity = 0) {
  const available = Math.max(0, (quantityOnHand || 0) - (quantityReserved || 0));
  if (!dailyVelocity || dailyVelocity <= 0) {
    return available > 0 ? 999.0 : 0.0;
  }
  return Math.round((available / dailyVelocity) * 10) / 10;
}

/**
 * Calculates Reorder Point.
 * Formula: (Daily Velocity * Lead Time) + (Daily Velocity * Safety Stock Days)
 * @param {number} dailyVelocity
 * @param {number} leadTimeDays
 * @param {number} [safetyStockDays=3]
 * @returns {number}
 */
export function calculateReorderPoint(dailyVelocity = 0, leadTimeDays = 14, safetyStockDays = 3) {
  const velocity = Math.max(0, dailyVelocity || 0);
  const leadTime = Math.max(1, leadTimeDays || 14);
  const safety = Math.max(0, safetyStockDays || 0);
  return Math.ceil(velocity * (leadTime + safety));
}

/**
 * Determines stockout risk classification.
 * @param {number} daysOfCover
 * @param {number} leadTimeDays
 * @returns {'CRITICAL' | 'REORDER_SOON' | 'HEALTHY'}
 */
export function determineRiskLevel(daysOfCover, leadTimeDays = 14) {
  if (daysOfCover <= leadTimeDays) {
    return 'CRITICAL';
  } else if (daysOfCover <= leadTimeDays * 1.5) {
    return 'REORDER_SOON';
  }
  return 'HEALTHY';
}
