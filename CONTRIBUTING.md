# Contributing to Shopify AI Forecast Bridge

Thank you for contributing to the open-source bridge connecting Shopify demand forecasting with Salesforce CRM!

## Local Development Workflow
1. Clone the repository and install dependencies:
   ```bash
   npm install
   ```
2. Copy environment template:
   ```bash
   cp .env.example .env
   ```
3. Run the development server:
   ```bash
   npm run dev
   ```

## PR Requirements
- Maintain compatibility with `shopify-ai-forecast-app`'s forecast snapshot data format.
- Ensure the LWC widget handles loading and error states cleanly.
- Keep AI prompts deterministic and strictly grounded in the calculated numbers.
