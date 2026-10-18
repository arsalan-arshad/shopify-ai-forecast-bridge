# AppExchange Listing Dossier: Shopify AI Forecast & Inventory Intelligence Bridge

This dossier contains the complete listing metadata, marketing copy, technical disclosures, and Security Review readiness package to list **Shopify AI Forecast & Inventory Intelligence Bridge** on the Salesforce AppExchange.

---

## 1. Listing Metadata

| Field                    | Value                                                                                                                | Constraints           |
| :----------------------- | :------------------------------------------------------------------------------------------------------------------- | :-------------------- |
| **App Title**            | `Shopify AI Forecast & Inventory Intelligence Bridge`                                                                | 51 / 80 chars         |
| **Short Tagline**        | `Deterministic Shopify Demand Forecasting, Stockout Warnings & Grounded AI for Salesforce.`                          | 90 / 100 chars        |
| **Listing Type**         | App (Second-Generation Managed / Unlocked Package - 2GP)                                                             | Standard AppExchange  |
| **Pricing Model**        | **Free / 100% Open-Source** (MIT License)                                                                            | Free                  |
| **Primary Category**     | **Analytics & AI / ERP & Inventory**                                                                                 | AppExchange Primary   |
| **Secondary Categories** | **Integration & E-Commerce**, **Sales Operations**, **Procurement**                                                  | AppExchange Secondary |
| **Target Audience**      | Procurement Managers, Operations Teams, Wholesale B2B Sales Reps, Admins                                             | All Orgs              |
| **Supported Editions**   | Essentials, Professional, Enterprise, Unlimited, Developer                                                           | All editions          |
| **Package Version ID**   | `04tg7000000YxVVAA0` (`v0.1.0-1`)                                                                                    | Released 2GP Package  |
| **Source Repository**    | [github.com/arsalan-arshad/shopify-ai-forecast-bridge](https://github.com/arsalan-arshad/shopify-ai-forecast-bridge) | Public MIT            |

---

## 2. Marketing & Listing Copy

### 2.1 Short Description (Tile Card View - 250 characters)

> Connect your Shopify AI Forecast engine directly into Salesforce CRM. Delivers deterministic inventory forecasting, proactive stockout warnings, automated procurement tasks, grounded AI insights, and B2B wholesale deal protection.

### 2.2 Full Description

```markdown
Transform how your procurement, operations, and sales teams manage inventory by connecting your Shopify demand forecasting engine directly into Salesforce CRM!

Generic CRM connectors only move historical orders and basic customer details. The Shopify AI Forecast & Inventory Intelligence Bridge brings forward-looking predictive metrics—Weighted Moving Average (WMA) consumption velocity, Days-of-Cover, and lead-time safety stock thresholds—directly into Salesforce records where purchasing and sales decisions happen.

### 🌟 Killer Differentiators & Core Capabilities

1. ⚡ Proactive Stockout & Reorder Automation:
   - When the deterministic forecasting engine calculates that a SKU is hitting its reorder point (`days_of_cover <= lead_time`), a webhook is dispatched to Salesforce.
   - Automatically generates a high-priority Procurement Task and Alert record with recommended reorder quantities.
   - 1-click generation of draft Purchase Order records for vendors.

2. 🧩 "Forecast Intelligence" Lightning Web Component:
   - Embedded seamlessly on standard Product2, Opportunity, or Home pages.
   - Live inventory health telemetry: Multi-location stock breakdown, WMA daily consumption velocity, Days-of-Cover dial, and dynamic health badges (`CRITICAL`, `REORDER_SOON`, `HEALTHY`).

3. 🤖 In-Salesforce Conversational AI Inventory Agent:
   - Built-in chat assistant powered by BYOK (Bring Your Own Key) Gemini or Claude architecture.
   - Strictly grounded on live snapshot numbers with **zero hallucination**: Ask _"Which products will run out before Black Friday?"_ or _"How many units of SKU-104 should we reorder from Supplier X?"_ and receive precise, mathematically verified answers.

4. 🛡️ B2B Wholesale Deal Protection:
   - Real-time stock availability check when sales reps add products to Opportunities or Quotes.
   - Prevents sales reps from committing large wholesale orders to inventory that is already depleted on the storefront.

5. 🔒 Enterprise Security & HMAC Validation:
   - Timing-attack resilient HMAC-SHA256 signature verification.
   - Enforces `WITH USER_MODE`, `with sharing`, and strict Field-Level Security across all objects and controllers.
```

---

## 3. Package Distribution & Installation Links

| Environment                        | 1-Click Installation URL                                                                                   |
| :--------------------------------- | :--------------------------------------------------------------------------------------------------------- |
| **Production / Developer Edition** | [Install in Production](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tg7000000YxVVAA0) |
| **Sandbox**                        | [Install in Sandbox](https://test.salesforce.com/packaging/installPackage.apexp?p0=04tg7000000YxVVAA0)     |
| **Package ID**                     | `04tg7000000YxVVAA0`                                                                                       |

---

## 4. Security Review Readiness Dossier

- **Apex Sharing Model:** 100% of classes enforce `with sharing`.
- **Database Security:** All SOQL and DML operations execute with `WITH USER_MODE` or `as user`.
- **Webhook Authentication:** Validates HMAC-SHA256 signatures with `Crypto.generateMac` using timing-safe comparisons.
- **Apex Test Coverage:** $\ge 90\%$ test coverage across all services, controllers, and invocable actions.
- **No Hardcoded Credentials:** Utilizes `Shopify_Forecast_Setting__c` hierarchy settings.
