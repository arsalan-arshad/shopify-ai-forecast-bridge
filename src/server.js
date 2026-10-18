import express from 'express';
import dotenv from 'dotenv';
import { fileURLToPath } from 'node:url';
import {
  verifyShopifyHmac,
  calculateWMA,
  calculateDaysOfCover,
  calculateReorderPoint,
  determineRiskLevel
} from './services/forecastBridge.js';
import { generateGroundedResponse } from './services/aiGroundedService.js';
import { SalesforceBridge } from './services/salesforceBridge.js';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3005;

// In-memory snapshot cache for fast retrieval and simulation
let inMemorySnapshots = [
  {
    sku: 'SKU-AIR-01',
    productTitle: 'Industrial Carbon Air Filter',
    locationName: 'North Warehouse',
    quantityOnHand: 45,
    quantityReserved: 10,
    dailyVelocityWMA: 4.5,
    daysOfCover: 7.7,
    leadTimeDays: 14,
    reorderPoint: 77,
    recommendedReorderQty: 150,
    stockoutRiskLevel: 'CRITICAL',
    supplierName: 'Apex Filtration Co'
  },
  {
    sku: 'SKU-VALVE-04',
    productTitle: 'Brass Pressure Relief Valve',
    locationName: 'East Distribution Hub',
    quantityOnHand: 90,
    quantityReserved: 15,
    dailyVelocityWMA: 4.2,
    daysOfCover: 17.8,
    leadTimeDays: 14,
    reorderPoint: 72,
    recommendedReorderQty: 100,
    stockoutRiskLevel: 'REORDER_SOON',
    supplierName: 'FluidFlow Dynamics'
  },
  {
    sku: 'SKU-HOSE-10',
    productTitle: 'Reinforced Hydraulic Hose 50ft',
    locationName: 'North Warehouse',
    quantityOnHand: 320,
    quantityReserved: 20,
    dailyVelocityWMA: 3.1,
    daysOfCover: 96.7,
    leadTimeDays: 14,
    reorderPoint: 53,
    recommendedReorderQty: 80,
    stockoutRiskLevel: 'HEALTHY',
    supplierName: 'Apex Filtration Co'
  }
];

// Capture raw body for HMAC verification
app.use(
  express.json({
    verify: (req, _res, buf) => {
      req.rawBody = buf.toString('utf8');
    }
  })
);

// Health check endpoint
app.get('/health', (_req, res) => {
  res.json({
    status: 'UP',
    service: 'shopify-ai-forecast-bridge',
    version: '0.1.0',
    timestamp: new Date().toISOString()
  });
});

// Inbound webhook from shopify-ai-forecast-app
app.post('/api/forecast/webhook', async (req, res) => {
  const secret = process.env.SHOPIFY_WEBHOOK_SECRET;
  const signature = req.get('x-shopify-forecast-signature') || req.get('x-shopify-hmac-sha256');

  if (secret && signature) {
    const isValid = verifyShopifyHmac(req.rawBody || JSON.stringify(req.body), signature, secret);
    if (!isValid) {
      return res.status(401).json({ error: 'Unauthorized: Invalid HMAC signature' });
    }
  }

  const {
    sku,
    productTitle,
    locationName,
    quantityOnHand,
    quantityReserved,
    dailyUsageHistory,
    leadTimeDays = 14,
    supplierName
  } = req.body;

  if (!sku) {
    return res.status(422).json({ error: 'Missing required field: sku' });
  }

  // Calculate deterministic forecast parameters if raw history is provided
  let dailyVelocityWMA = req.body.dailyVelocityWMA;
  if (dailyVelocityWMA === undefined && Array.isArray(dailyUsageHistory)) {
    dailyVelocityWMA = calculateWMA(dailyUsageHistory);
  } else if (dailyVelocityWMA === undefined) {
    dailyVelocityWMA = 3.5;
  }

  const daysOfCover = calculateDaysOfCover(quantityOnHand, quantityReserved, dailyVelocityWMA);
  const reorderPoint = calculateReorderPoint(dailyVelocityWMA, leadTimeDays);
  const stockoutRiskLevel = determineRiskLevel(daysOfCover, leadTimeDays);
  const recommendedReorderQty = Math.ceil(dailyVelocityWMA * leadTimeDays * 2);

  const snapshot = {
    sku,
    productTitle: productTitle || `Product ${sku}`,
    locationName: locationName || 'Primary Facility',
    quantityOnHand: Number(quantityOnHand) || 0,
    quantityReserved: Number(quantityReserved) || 0,
    dailyVelocityWMA,
    daysOfCover,
    leadTimeDays,
    reorderPoint,
    recommendedReorderQty,
    stockoutRiskLevel,
    supplierName: supplierName || 'Global Supplier'
  };

  // Update in-memory cache
  const idx = inMemorySnapshots.findIndex((s) => s.sku === sku);
  if (idx >= 0) {
    inMemorySnapshots[idx] = snapshot;
  } else {
    inMemorySnapshots.push(snapshot);
  }

  // Push to Salesforce if credentials exist
  let sfResult = null;
  if (process.env.SALESFORCE_USERNAME && process.env.SALESFORCE_PASSWORD) {
    try {
      const sfBridge = new SalesforceBridge();
      sfResult = await sfBridge.upsertSnapshot(snapshot);
    } catch (err) {
      console.warn('Salesforce sync skipped or failed:', err.message);
    }
  }

  return res.status(200).json({
    status: 'SUCCESS',
    snapshot,
    salesforceSynced: !!sfResult
  });
});

// Calculate Weighted Moving Average standalone endpoint
app.post('/api/forecast/calculate-wma', (req, res) => {
  const { dailyUsage, weights } = req.body;
  if (!Array.isArray(dailyUsage)) {
    return res.status(400).json({ error: 'dailyUsage must be an array of numbers' });
  }

  const wma = calculateWMA(dailyUsage, weights);
  return res.json({ wma });
});

// Grounded Conversational AI Endpoint
app.post('/api/forecast/chat', (req, res) => {
  const { query } = req.body;
  if (!query) {
    return res.status(400).json({ error: 'Missing query parameter' });
  }

  const response = generateGroundedResponse(query, inMemorySnapshots);
  return res.json(response);
});

// Retrieve inventory snapshots
app.get('/api/forecast/inventory', (_req, res) => {
  return res.json({
    count: inMemorySnapshots.length,
    snapshots: inMemorySnapshots
  });
});

// Only listen when directly executed from CLI
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  app.listen(PORT, () => {
    console.log(`🚀 Shopify AI Forecast Bridge listening on port ${PORT}`);
  });
}

export default app;
