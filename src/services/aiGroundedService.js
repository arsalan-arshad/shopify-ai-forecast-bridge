/**
 * Grounded Conversational AI Service for Inventory Inquiries.
 * Strictly grounds prompts and outputs on deterministic numbers to eliminate hallucination.
 */
export function generateGroundedResponse(userQuery, snapshots = []) {
  if (!userQuery || typeof userQuery !== 'string') {
    return {
      sender: 'assistant',
      content: 'Please provide an inventory query to analyze.',
      isGrounded: true,
      citedSkus: []
    };
  }

  const query = userQuery.toLowerCase().trim();
  const citedSkus = [];

  // Match specific SKU
  const matched = snapshots.filter((s) => s.sku && query.includes(s.sku.toLowerCase()));
  if (matched.length > 0) {
    const target = matched[0];
    citedSkus.push(target.sku);
    const available = Math.max(0, (target.quantityOnHand || 0) - (target.quantityReserved || 0));

    return {
      sender: 'assistant',
      content:
        `### 📦 Inventory Forecast for \`${target.sku}\`\n\n` +
        `**Product:** ${target.productTitle}\n` +
        `**Status:** ${target.stockoutRiskLevel}\n\n` +
        `- **Available Units:** ${available} (${target.quantityOnHand} on hand, ${target.quantityReserved} reserved)\n` +
        `- **Daily Consumption (WMA):** ${target.dailyVelocityWMA} units/day\n` +
        `- **Days of Cover Remaining:** ${target.daysOfCover} days\n` +
        `- **Supplier Lead Time:** ${target.leadTimeDays} days\n` +
        `- **Recommended Reorder:** **${target.recommendedReorderQty} units** from ${target.supplierName}`,
      isGrounded: true,
      citedSkus
    };
  }

  // Stockout / Run out queries
  if (
    query.includes('run out') ||
    query.includes('stockout') ||
    query.includes('critical') ||
    query.includes('black friday')
  ) {
    const critical = snapshots.filter((s) => s.stockoutRiskLevel === 'CRITICAL' || s.daysOfCover <= 14);
    critical.forEach((s) => citedSkus.push(s.sku));

    if (critical.length === 0) {
      return {
        sender: 'assistant',
        content:
          '### ✅ No Critical Stockouts\n\nAll monitored inventory items currently have sufficient days of cover.',
        isGrounded: true,
        citedSkus: []
      };
    }

    const rows = critical
      .map(
        (c) =>
          `| \`${c.sku}\` | ${c.productTitle} | **${c.daysOfCover}d** | ${c.leadTimeDays}d | **${c.recommendedReorderQty}** | ${c.supplierName} |`
      )
      .join('\n');

    return {
      sender: 'assistant',
      content:
        `### ⚠️ Imminent Stockout Risk (${critical.length} SKUs)\n\n` +
        `The following items will deplete before replenishment delivery arrives:\n\n` +
        `| SKU | Product | Days of Cover | Lead Time | Recommended Order | Supplier |\n` +
        `| :--- | :--- | :--- | :--- | :--- | :--- |\n` +
        rows,
      isGrounded: true,
      citedSkus
    };
  }

  // Supplier inquiry
  if (query.includes('supplier') || query.includes('vendor')) {
    const suppliers = {};
    snapshots.forEach((s) => {
      const name = s.supplierName || 'General Supplier';
      if (!suppliers[name]) {
        suppliers[name] = { count: 0, units: 0 };
      }
      suppliers[name].count += 1;
      suppliers[name].units += s.recommendedReorderQty || 0;
    });

    const rows = Object.entries(suppliers)
      .map(([name, data]) => `| **${name}** | ${data.count} | **${data.units} units** |`)
      .join('\n');

    return {
      sender: 'assistant',
      content:
        `### 🏭 Supplier Restock Demand\n\n` +
        `| Supplier | SKUs Monitored | Total Reorder Units |\n` +
        `| :--- | :--- | :--- |\n` +
        rows,
      isGrounded: true,
      citedSkus: []
    };
  }

  // General summary
  const total = snapshots.length;
  const criticalCount = snapshots.filter((s) => s.stockoutRiskLevel === 'CRITICAL').length;
  const reorderCount = snapshots.filter((s) => s.stockoutRiskLevel === 'REORDER_SOON').length;
  const healthyCount = snapshots.filter((s) => s.stockoutRiskLevel === 'HEALTHY').length;

  return {
    sender: 'assistant',
    content:
      `### 📊 Inventory Intelligence Summary\n\n` +
      `- **Total Catalog SKUs:** ${total}\n` +
      `- **🔴 Critical Stockout Risk:** ${criticalCount}\n` +
      `- **🟡 Reorder Approaching:** ${reorderCount}\n` +
      `- **🟢 Healthy Stock:** ${healthyCount}\n\n` +
      `Ask me about any specific SKU or imminent stockouts for detailed recommendations.`,
    isGrounded: true,
    citedSkus: []
  };
}
