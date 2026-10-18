# Contributing to Shopify AI Forecast Bridge

Thank you for contributing to the open-source companion bridge connecting Shopify demand forecasting with Salesforce CRM!

Whether you are fixing a bug, adding new forecasting algorithms, enhancing the LWC interface, or improving documentation, your input is deeply appreciated.

---

## 🛠️ Developer Setup & Workflow

### 1. Prerequisites

- [Node.js](https://nodejs.org/) (v20+ or v22+ LTS recommended).
- [Salesforce CLI (`sf`)](https://developer.salesforce.com/tools/salesforce-cli) installed.
- A free [Salesforce Developer Edition Org](https://developer.salesforce.com/signup) or Dev Hub.

### 2. Local Environment Setup

1. **Clone the repository:**

   ```bash
   git clone https://github.com/arsalan-arshad/shopify-ai-forecast-bridge.git
   cd shopify-ai-forecast-bridge
   ```

2. **Install Node.js dependencies:**

   ```bash
   npm install
   ```

3. **Configure environment variables:**

   ```bash
   cp .env.example .env
   ```

4. **Run the local bridge server:**

   ```bash
   npm run dev
   ```

5. **Run test and lint suites:**
   ```bash
   npm test
   npm run lint
   npm run prettier:check
   ```

---

## ☁️ Salesforce Scratch Org & Deployment

1. **Authorize your Dev Hub or Developer Org:**

   ```bash
   sf org login web -d -a my-dev-org
   ```

2. **Spin up a Scratch Org:**

   ```bash
   sf org create scratch -f config/project-scratch-def.json -a forecast-scratch -d 7
   ```

3. **Deploy the source metadata:**

   ```bash
   sf project deploy start --target-org forecast-scratch
   ```

4. **Assign the Permission Set:**

   ```bash
   sf org assign permset --name Shopify_Forecast_Admin --target-org forecast-scratch
   ```

5. **Run Apex unit tests:**
   ```bash
   sf apex run test --test-level RunLocalTests --code-coverage --result-format human --target-org forecast-scratch
   ```

---

## 📋 Pull Request (PR) Guidelines & Ruleset

All contributions must pass through GitHub Pull Requests targeting the `main` branch:

1. **Enforce Branch Ruleset:**
   - Direct pushes to `main` are blocked.
   - All PRs require at least 1 approving review.
   - Linear git history is enforced (squash-merge or rebase).
   - Strict status checks must pass:
     - `Lint, Prettier & Node Unit Tests`
     - `Validate Salesforce Deployment & Apex Tests`

2. **Quality & Security Checklist:**
   - Apex code must include unit tests with meaningful assertions ($\ge 85\%$ code coverage required; target 90%+).
   - Always enforce `with sharing` and `WITH USER_MODE` on database operations.
   - Webhook ingress endpoints must strictly validate HMAC signatures using timing-safe comparisons.
   - Maintain compatibility with `shopify-ai-forecast-app` snapshot payload schemas.
   - Ground all conversational AI prompts strictly on deterministic inventory metrics (no hallucinations).

---

## 🏷️ Release Management

We adhere strictly to [Semantic Versioning 2.0.0](https://semver.org/). Version bumps in `package.json` and `sfdx-project.json` trigger automated 2GP package creation and GitHub Releases upon tagging `v*`. See [`.github/RULESETS.md`](.github/RULESETS.md) for full details.
