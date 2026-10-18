/**
 * @description Invocable action and service that validates inventory availability and stockout risk
 *              for Opportunity products before sales reps commit to large orders.
 * @group Shopify AI Forecast Bridge
 */
public with sharing class ValidateOpportunityStock {

    public class OpportunityStockCheckRequest {
        @InvocableVariable(label='Opportunity ID' required=false)
        public Id opportunityId;

        @InvocableVariable(label='Product2 ID' required=false)
        public Id product2Id;

        @InvocableVariable(label='SKU' required=false)
        public String sku;

        @InvocableVariable(label='Quantity Requested' required=true)
        public Decimal quantityRequested;
    }

    public class OpportunityStockCheckResult {
        @InvocableVariable(label='Is Available')
        public Boolean isAvailable;

        @InvocableVariable(label='Available Stock')
        public Decimal availableStock;

        @InvocableVariable(label='Days of Cover')
        public Decimal daysOfCover;

        @InvocableVariable(label='Risk Level')
        public String riskLevel;

        @InvocableVariable(label='Projected Restock Date')
        public Date projectedRestockDate;

        @InvocableVariable(label='Warning Message')
        public String warningMessage;

        @InvocableVariable(label='Allow Commit')
        public Boolean allowCommit;
    }

    /**
     * @description Invocable method callable from Salesforce Flow, Orchestration, or Apex.
     */
    @InvocableMethod(label='Validate Opportunity Stock' description='Checks current Shopify stock and forecast days-of-cover to protect wholesale commitments.')
    public static List<OpportunityStockCheckResult> checkStockAvailability(List<OpportunityStockCheckRequest> requests) {
        List<OpportunityStockCheckResult> results = new List<OpportunityStockCheckResult>();

        if (requests == null || requests.isEmpty()) {
            return results;
        }

        // Collect SKUs and Product IDs
        Set<String> skus = new Set<String>();
        Set<Id> productIds = new Set<Id>();

        for (OpportunityStockCheckRequest req : requests) {
            if (String.isNotBlank(req.sku)) {
                skus.add(req.sku);
            }
            if (req.product2Id != null) {
                productIds.add(req.product2Id);
            }
        }

        // Map Product2 IDs to SKUs
        Map<Id, String> productIdToSku = new Map<Id, String>();
        if (!productIds.isEmpty()) {
            for (Product2 p : [
                SELECT Id, StockKeepingUnit, ProductCode
                FROM Product2
                WHERE Id IN :productIds
            ]) {
                String code = String.isNotBlank(p.StockKeepingUnit) ? p.StockKeepingUnit : p.ProductCode;
                if (String.isNotBlank(code)) {
                    productIdToSku.put(p.Id, code);
                    skus.add(code);
                }
            }
        }

        // Query Snapshots
        Map<String, Shopify_Inventory_Snapshot__c> snapshotMap = new Map<String, Shopify_Inventory_Snapshot__c>();
        if (!skus.isEmpty()) {
            for (Shopify_Inventory_Snapshot__c s : [
                SELECT Id, SKU__c, Product_Title__c, Quantity_On_Hand__c, Quantity_Reserved__c,
                       Daily_Velocity_WMA__c, Days_Of_Cover__c, Lead_Time_Days__c, Stockout_Risk_Level__c
                FROM Shopify_Inventory_Snapshot__c
                WHERE SKU__c IN :skus
            ]) {
                snapshotMap.put(s.SKU__c, s);
            }
        }

        // Evaluate each request
        for (OpportunityStockCheckRequest req : requests) {
            OpportunityStockCheckResult res = new OpportunityStockCheckResult();
            String targetSku = req.sku;
            if (String.isBlank(targetSku) && req.product2Id != null && productIdToSku.containsKey(req.product2Id)) {
                targetSku = productIdToSku.get(req.product2Id);
            }

            Shopify_Inventory_Snapshot__c snap = String.isNotBlank(targetSku) ? snapshotMap.get(targetSku) : null;

            if (snap == null) {
                // No snapshot data available - permit with informational note
                res.isAvailable = true;
                res.availableStock = 0;
                res.daysOfCover = 999;
                res.riskLevel = 'HEALTHY';
                res.projectedRestockDate = Date.today();
                res.warningMessage = 'No live Shopify forecast snapshot found for SKU: ' + (String.isNotBlank(targetSku) ? targetSku : 'Unknown');
                res.allowCommit = true;
            } else {
                Decimal onHand = snap.Quantity_On_Hand__c != null ? snap.Quantity_On_Hand__c : 0;
                Decimal reserved = snap.Quantity_Reserved__c != null ? snap.Quantity_Reserved__c : 0;
                Decimal available = onHand - reserved;
                Decimal requested = req.quantityRequested != null ? req.quantityRequested : 0;
                Integer leadTime = snap.Lead_Time_Days__c != null ? Integer.valueOf(snap.Lead_Time_Days__c) : 14;

                res.availableStock = available;
                res.daysOfCover = snap.Days_Of_Cover__c != null ? snap.Days_Of_Cover__c : 0;
                res.riskLevel = snap.Stockout_Risk_Level__c;
                res.projectedRestockDate = Date.today().addDays(leadTime);

                if (available < requested) {
                    res.isAvailable = false;
                    res.allowCommit = false;
                    res.warningMessage = '⚠️ Stock Shortage Alert: Requested ' + requested + ' units, but only ' +
                        available + ' units are unallocated in Shopify. Next projected restock delivery is ' +
                        res.projectedRestockDate.format() + '.';
                } else if (snap.Stockout_Risk_Level__c == 'CRITICAL') {
                    res.isAvailable = true;
                    res.allowCommit = false;
                    res.warningMessage = '⚠️ Imminent Stockout Warning: Available stock (' + available + ' units) can fulfill this order, ' +
                        'but storefront velocity is depleting remaining units in ' + snap.Days_Of_Cover__c +
                        ' days (less than supplier lead time of ' + leadTime + ' days). Manager approval recommended.';
                } else {
                    res.isAvailable = true;
                    res.allowCommit = true;
                    res.warningMessage = '✅ Sufficient Shopify inventory available. Healthy cover of ' + snap.Days_Of_Cover__c + ' days.';
                }
            }

            results.add(res);
        }

        return results;
    }
}
