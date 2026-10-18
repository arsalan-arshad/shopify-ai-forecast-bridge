## 📋 Pull Request Description

### Summary of Changes

<!-- Describe the specific feature, bug fix, or enhancement introduced by this PR. -->

### Related Issue

<!-- Link any relevant GitHub issues or discussions (e.g. Closes #12). -->

---

## 🛠️ Verification Checklist

- [ ] **Tests Added / Updated:**
  - [ ] Apex test classes updated with assertions and $\ge 85\%$ test coverage.
  - [ ] Node.js unit tests passing (`npm test`).
- [ ] **Code Standards & Security:**
  - [ ] Apex classes enforce `with sharing` and `WITH USER_MODE`.
  - [ ] Webhook payloads verified with cryptographic timing-safe HMAC validation.
  - [ ] LWC adheres strictly to SLDS design tokens.
- [ ] **Formatting & Linting:**
  - [ ] `npm run lint` passes without errors.
  - [ ] `npm run prettier:check` passes without formatting diffs.
- [ ] **Documentation:**
  - [ ] `README.md` or relevant guides updated if behavior or configuration changed.
