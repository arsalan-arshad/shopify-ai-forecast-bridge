/**
 * @description In-Salesforce Conversational AI engine for inventory intelligence queries.
 *              Strictly grounds all responses on deterministic snapshot calculations to prevent hallucinations.
 * @group Shopify AI Forecast Bridge
 */
public with sharing class ShopifyAIChatService {

    public class ChatMessageDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String sender; // 'user' or 'assistant'
        @AuraEnabled public String content;
        @AuraEnabled public Datetime timestamp;
        @AuraEnabled public Boolean isGrounded;
        @AuraEnabled public List<String> citedSkus;
    }

    /**
     * @description Answers a natural language inventory question using deterministic grounding.
     * @param query The user's prompt (e.g. "Which products will run out first?")
     * @return ChatMessageDTO Structured response with citations and formatted Markdown.
     */
    public static ChatMessageDTO processUserQuery(String query) {
        ChatMessageDTO response = new ChatMessageDTO();
        response.id = 'msg-' + Datetime.now().getTime();
        response.sender = 'assistant';
        response.timestamp = Datetime.now();
        response.isGrounded = true;
        response.citedSkus = new List<String>();

        if (String.isBlank(query)) {
            response.content = 'Please enter an inventory or restock question to get started.';
            return response;
        }

        String lowerQuery = query.toLowerCase().trim();

        // Check for specific SKU inquiry (e.g., "SKU-101", "SKU-PRO-01")
        List<Shopify_Inventory_Snapshot__c> matchedSkus = new List<Shopify_Inventory_Snapshot__c>();
        List<Shopify_Inventory_Snapshot__c> allSnapshots = [
            SELECT Id, Name, SKU__c, Product_Title__c, Location_Name__c, Quantity_On_Hand__c,
                   Quantity_Reserved__c, Daily_Velocity_WMA__c, Days_Of_Cover__c, Lead_Time_Days__c,
                   Reorder_Point__c, Recommended_Reorder_Qty__c, Stockout_Risk_Level__c, Supplier_Name__c
            FROM Shopify_Inventory_Snapshot__c
            ORDER BY Days_Of_Cover__c ASC
            LIMIT 100
        ];

        for (Shopify_Inventory_Snapshot__c snap : allSnapshots) {
            if (String.isNotBlank(snap.SKU__c) && lowerQuery.contains(snap.SKU__c.toLowerCase())) {
                matchedSkus.add(snap);
                response.citedSkus.add(snap.SKU__c);
            }
        }

        // Branch 1: Specific SKU requested
        if (!matchedSkus.isEmpty()) {
            Shopify_Inventory_Snapshot__c target = matchedSkus[0];
            Decimal available = (target.Quantity_On_Hand__c != null ? target.Quantity_On_Hand__c : 0) -
                                (target.Quantity_Reserved__c != null ? target.Quantity_Reserved__c : 0);

            String statusIcon = target.Stockout_Risk_Level__c == 'CRITICAL' ? '🔴 CRITICAL' :
                                (target.Stockout_Risk_Level__c == 'REORDER_SOON' ? '🟡 REORDER SOON' : '🟢 HEALTHY');

            response.content = '### 📦 Inventory Forecast for `' + target.SKU__c + '`\n\n' +
                '**Product:** ' + target.Product_Title__c + '\n' +
                '**Current Health Status:** ' + statusIcon + '\n\n' +
                '| Metric | Value |\n' +
                '| :--- | :--- |\n' +
                '| **Quantity On Hand** | ' + target.Quantity_On_Hand__c + ' units |\n' +
                '| **Reserved / Allocated** | ' + target.Quantity_Reserved__c + ' units |\n' +
                '| **Available Stock** | ' + available + ' units |\n' +
                '| **Daily Consumption (WMA)** | ' + target.Daily_Velocity_WMA__c + ' units/day |\n' +
                '| **Days of Cover Remaining** | ' + target.Days_Of_Cover__c + ' days |\n' +
                '| **Supplier Lead Time** | ' + target.Lead_Time_Days__c + ' days |\n' +
                '| **Reorder Point Trigger** | ' + target.Reorder_Point__c + ' units |\n' +
                '| **Recommended Order Qty** | **' + target.Recommended_Reorder_Qty__c + ' units** |\n' +
                '| **Preferred Supplier** | ' + target.Supplier_Name__c + ' |\n\n' +
                '💡 **Recommendation:** ' +
                (target.Stockout_Risk_Level__c == 'CRITICAL'
                    ? 'Place an urgent replenishment order for **' + target.Recommended_Reorder_Qty__c + ' units** immediately to prevent stockout before supplier delivery window closes.'
                    : 'Inventory is currently within safe operational thresholds. Monitor velocity leading into peak demand.');

            return response;
        }

        // Branch 2: Imminent Stockouts or "run out" / "black friday" / "holiday" inquiry
        if (lowerQuery.contains('run out') || lowerQuery.contains('stockout') || lowerQuery.contains('critical') ||
            lowerQuery.contains('black friday') || lowerQuery.contains('holiday') || lowerQuery.contains('urgent')) {

            List<Shopify_Inventory_Snapshot__c> criticalList = new List<Shopify_Inventory_Snapshot__c>();
            for (Shopify_Inventory_Snapshot__c s : allSnapshots) {
                if (s.Stockout_Risk_Level__c == 'CRITICAL' || s.Days_Of_Cover__c <= 14) {
                    criticalList.add(s);
                    response.citedSkus.add(s.SKU__c);
                }
            }

            if (criticalList.isEmpty()) {
                response.content = '### ✅ Zero Imminent Stockouts Detected\n\n' +
                    'All monitored SKUs currently have days-of-cover exceeding their supplier lead times. No SKUs are in critical risk of running out.';
                return response;
            }

            String md = '### ⚠️ Imminent Stockout Risk Analysis\n\n' +
                'Based on current Weighted Moving Average (WMA) velocity and supplier fulfillment cycles, **' +
                criticalList.size() + ' SKUs** are at immediate risk of depleting before replenishment arrives:\n\n' +
                '| SKU | Product | Days of Cover | Lead Time | Reorder Qty | Supplier |\n' +
                '| :--- | :--- | :--- | :--- | :--- | :--- |\n';

            for (Shopify_Inventory_Snapshot__c c : criticalList) {
                md += '| `' + c.SKU__c + '` | ' + c.Product_Title__c + ' | **' + c.Days_Of_Cover__c + ' d** | ' +
                    c.Lead_Time_Days__c + ' d | **' + c.Recommended_Reorder_Qty__c + '** | ' + c.Supplier_Name__c + ' |\n';
            }

            md += '\n👉 *Action required:* Draft purchase orders for these items to avoid lost sales revenue.';
            response.content = md;
            return response;
        }

        // Branch 3: Supplier / Vendor inquiry
        if (lowerQuery.contains('supplier') || lowerQuery.contains('vendor')) {
            Map<String, Integer> supplierCounts = new Map<String, Integer>();
            Map<String, Decimal> supplierReorderUnits = new Map<String, Decimal>();

            for (Shopify_Inventory_Snapshot__c s : allSnapshots) {
                String supp = String.isNotBlank(s.Supplier_Name__c) ? s.Supplier_Name__c : 'Unassigned';
                Integer count = supplierCounts.containsKey(supp) ? supplierCounts.get(supp) + 1 : 1;
                supplierCounts.put(supp, count);

                Decimal units = s.Recommended_Reorder_Qty__c != null ? s.Recommended_Reorder_Qty__c : 0;
                Decimal currUnits = supplierReorderUnits.containsKey(supp) ? supplierReorderUnits.get(supp) + units : units;
                supplierReorderUnits.put(supp, currUnits);
            }

            String md = '### 🏭 Supplier Restock & Allocation Summary\n\n' +
                'Breakdown of SKUs and replenishment demand across primary suppliers:\n\n' +
                '| Supplier Name | Total SKUs Monitored | Recommended Reorder Units |\n' +
                '| :--- | :--- | :--- |\n';

            for (String supp : supplierCounts.keySet()) {
                md += '| **' + supp + '** | ' + supplierCounts.get(supp) + ' | ' + supplierReorderUnits.get(supp) + ' units |\n';
            }

            response.content = md;
            return response;
        }

        // Branch 4: General Inventory Health Overview
        Integer criticalCount = 0;
        Integer reorderCount = 0;
        Integer healthyCount = 0;
        Decimal totalReorderQty = 0;

        for (Shopify_Inventory_Snapshot__c s : allSnapshots) {
            if (s.Stockout_Risk_Level__c == 'CRITICAL') {
                criticalCount++;
            } else if (s.Stockout_Risk_Level__c == 'REORDER_SOON') {
                reorderCount++;
            } else {
                healthyCount++;
            }
            if (s.Recommended_Reorder_Qty__c != null) {
                totalReorderQty += s.Recommended_Reorder_Qty__c;
            }
        }

        response.content = '### 📊 Overall Inventory Intelligence Summary\n\n' +
            '- **Monitored Catalog SKUs:** ' + allSnapshots.size() + '\n' +
            '- **🔴 Critical Stockout Risk:** ' + criticalCount + ' SKUs\n' +
            '- **🟡 Reorder Point Approaching:** ' + reorderCount + ' SKUs\n' +
            '- **🟢 Healthy Inventory Levels:** ' + healthyCount + ' SKUs\n' +
            '- **📦 Total Recommended Reorder Volume:** ' + totalReorderQty + ' units\n\n' +
            '💡 *Tip:* Ask me about a specific SKU (e.g., *"Forecast for SKU-AIR-01"*), supplier restock summaries, or imminent stockouts.';

        return response;
    }
}
