/**
 * @description Lightning Web Component Apex Controller providing reactive access to inventory telemetry,
 *              health status cards, and procurement reordering actions.
 * @group Shopify AI Forecast Bridge
 */
public with sharing class ShopifyForecastController {

    public class DashboardSummaryDTO {
        @AuraEnabled public Integer totalMonitored;
        @AuraEnabled public Integer criticalStockouts;
        @AuraEnabled public Integer reorderSoon;
        @AuraEnabled public Integer healthy;
        @AuraEnabled public Decimal totalReorderUnitsRecommended;
        @AuraEnabled public List<ShopifyForecastService.InventoryHealthDTO> criticalItems;
    }

    /**
     * @description Fetches inventory health telemetry for a given record.
     * @param recordId Can be an Id for Shopify_Inventory_Snapshot__c, Product2, or Opportunity.
     */
    @AuraEnabled(cacheable=true)
    public static ShopifyForecastService.InventoryHealthDTO getInventoryHealth(Id recordId) {
        if (recordId == null) {
            return null;
        }

        String sObjName = recordId.getSObjectType().getDescribe().getName();
        Shopify_Inventory_Snapshot__c snap = null;

        if (sObjName == 'Shopify_Inventory_Snapshot__c') {
            List<Shopify_Inventory_Snapshot__c> listSnap = [
                SELECT Id, Name, SKU__c, Product_Title__c, Shopify_Product_Id__c, Shopify_Variant_Id__c,
                       Location_Name__c, Location_Id__c, Quantity_On_Hand__c, Quantity_Reserved__c,
                       Daily_Velocity_WMA__c, Days_Of_Cover__c, Lead_Time_Days__c, Reorder_Point__c,
                       Recommended_Reorder_Qty__c, Stockout_Risk_Level__c, Supplier_Name__c,
                       Last_Forecast_Date__c, Product__c
                FROM Shopify_Inventory_Snapshot__c
                WHERE Id = :recordId
                WITH USER_MODE
                LIMIT 1
            ];
            if (!listSnap.isEmpty()) {
                snap = listSnap[0];
            }
        } else if (sObjName == 'Product2') {
            List<Product2> prods = [
                SELECT Id, StockKeepingUnit, ProductCode
                FROM Product2
                WHERE Id = :recordId
                WITH USER_MODE
                LIMIT 1
            ];
            if (!prods.isEmpty()) {
                String code = String.isNotBlank(prods[0].StockKeepingUnit) ? prods[0].StockKeepingUnit : prods[0].ProductCode;
                snap = ShopifyForecastService.getSnapshotBySku(code);
            }
        } else if (sObjName == 'Opportunity') {
            // Find first line item with a snapshot
            List<OpportunityLineItem> lines = [
                SELECT Product2.StockKeepingUnit, Product2.ProductCode
                FROM OpportunityLineItem
                WHERE OpportunityId = :recordId
                WITH USER_MODE
                LIMIT 5
            ];
            for (OpportunityLineItem oli : lines) {
                String code = String.isNotBlank(oli.Product2.StockKeepingUnit) ? oli.Product2.StockKeepingUnit : oli.Product2.ProductCode;
                snap = ShopifyForecastService.getSnapshotBySku(code);
                if (snap != null) {
                    break;
                }
            }
        }

        return ShopifyForecastService.buildHealthDTO(snap);
    }

    /**
     * @description Returns roll-up metrics for the executive inventory health dashboard.
     */
    @AuraEnabled(cacheable=true)
    public static DashboardSummaryDTO getForecastDashboardSummary() {
        DashboardSummaryDTO summary = new DashboardSummaryDTO();
        summary.totalMonitored = 0;
        summary.criticalStockouts = 0;
        summary.reorderSoon = 0;
        summary.healthy = 0;
        summary.totalReorderUnitsRecommended = 0;
        summary.criticalItems = new List<ShopifyForecastService.InventoryHealthDTO>();

        List<Shopify_Inventory_Snapshot__c> allSnapshots = [
            SELECT Id, Name, SKU__c, Product_Title__c, Shopify_Product_Id__c, Shopify_Variant_Id__c,
                   Location_Name__c, Location_Id__c, Quantity_On_Hand__c, Quantity_Reserved__c,
                   Daily_Velocity_WMA__c, Days_Of_Cover__c, Lead_Time_Days__c, Reorder_Point__c,
                   Recommended_Reorder_Qty__c, Stockout_Risk_Level__c, Supplier_Name__c,
                   Last_Forecast_Date__c, Product__c
            FROM Shopify_Inventory_Snapshot__c
            WITH USER_MODE
            ORDER BY Days_Of_Cover__c ASC
            LIMIT 200
        ];

        summary.totalMonitored = allSnapshots.size();

        for (Shopify_Inventory_Snapshot__c snap : allSnapshots) {
            if (snap.Stockout_Risk_Level__c == 'CRITICAL') {
                summary.criticalStockouts++;
                if (summary.criticalItems.size() < 10) {
                    summary.criticalItems.add(ShopifyForecastService.buildHealthDTO(snap));
                }
            } else if (snap.Stockout_Risk_Level__c == 'REORDER_SOON') {
                summary.reorderSoon++;
            } else {
                summary.healthy++;
            }

            if (snap.Recommended_Reorder_Qty__c != null) {
                summary.totalReorderUnitsRecommended += snap.Recommended_Reorder_Qty__c;
            }
        }

        return summary;
    }

    /**
     * @description Drafts a purchase order directly from the LWC button action.
     */
    @AuraEnabled
    public static String triggerReorderAction(String sku, Decimal quantity, String supplierName) {
        Shopify_Procurement_Alert__c alert = ShopifyForecastService.draftPurchaseOrder(sku, quantity, supplierName);
        return alert != null ? alert.Purchase_Order_Number__c : null;
    }

    /**
     * @description Resolves an active procurement alert.
     */
    @AuraEnabled
    public static Boolean resolveProcurementAlert(Id alertId, String resolutionNotes) {
        if (alertId == null) {
            return false;
        }

        List<Shopify_Procurement_Alert__c> alerts = [
            SELECT Id, Status__c, Raw_Payload__c
            FROM Shopify_Procurement_Alert__c
            WHERE Id = :alertId
            WITH USER_MODE
            LIMIT 1
        ];

        if (alerts.isEmpty()) {
            return false;
        }

        alerts[0].Status__c = 'RESOLVED';
        if (String.isNotBlank(resolutionNotes)) {
            alerts[0].Raw_Payload__c = (alerts[0].Raw_Payload__c != null ? alerts[0].Raw_Payload__c + '\n\n' : '') +
                'Resolution Note (' + Datetime.now().format() + '): ' + resolutionNotes;
        }

        if (Schema.sObjectType.Shopify_Procurement_Alert__c.isUpdateable()) {
            update as user alerts[0];
            return true;
        }

        return false;
    }
}
