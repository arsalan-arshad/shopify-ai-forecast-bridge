/**
 * @description Core service handling inventory forecasting calculations, health status determinations,
 *              and procurement automation for the Shopify AI Forecast Bridge.
 * @group Shopify AI Forecast Bridge
 */
public with sharing class ShopifyForecastService {

    public class ForecastException extends Exception {}

    /**
     * @description Data Transfer Object representing an inventory health summary.
     */
    public class InventoryHealthDTO {
        @AuraEnabled public Id snapshotId;
        @AuraEnabled public String sku;
        @AuraEnabled public String productTitle;
        @AuraEnabled public String locationName;
        @AuraEnabled public Decimal quantityOnHand;
        @AuraEnabled public Decimal quantityReserved;
        @AuraEnabled public Decimal quantityAvailable;
        @AuraEnabled public Decimal dailyVelocityWMA;
        @AuraEnabled public Decimal daysOfCover;
        @AuraEnabled public Decimal leadTimeDays;
        @AuraEnabled public Decimal reorderPoint;
        @AuraEnabled public Decimal recommendedReorderQty;
        @AuraEnabled public String stockoutRiskLevel;
        @AuraEnabled public String supplierName;
        @AuraEnabled public Datetime lastForecastDate;
        @AuraEnabled public String statusBadgeTheme;
        @AuraEnabled public Boolean isCritical;
        @AuraEnabled public Boolean isReorderSoon;
    }

    /**
     * @description Calculates risk level based on Days of Cover versus Supplier Lead Time.
     * @param daysOfCover Current days of stock remaining
     * @param leadTimeDays Supplier lead time in calendar days
     * @return String 'CRITICAL', 'REORDER_SOON', or 'HEALTHY'
     */
    public static String calculateStockoutRisk(Decimal daysOfCover, Decimal leadTimeDays) {
        if (daysOfCover == null || leadTimeDays == null) {
            return 'HEALTHY';
        }
        if (daysOfCover <= leadTimeDays) {
            return 'CRITICAL';
        } else if (daysOfCover <= (leadTimeDays * 1.5)) {
            return 'REORDER_SOON';
        }
        return 'HEALTHY';
    }

    /**
     * @description Retrieves the snapshot for a given SKU.
     */
    public static Shopify_Inventory_Snapshot__c getSnapshotBySku(String sku) {
        if (String.isBlank(sku)) {
            return null;
        }
        List<Shopify_Inventory_Snapshot__c> snapshots = [
            SELECT Id, Name, SKU__c, Product_Title__c, Shopify_Product_Id__c, Shopify_Variant_Id__c,
                   Location_Name__c, Location_Id__c, Quantity_On_Hand__c, Quantity_Reserved__c,
                   Daily_Velocity_WMA__c, Days_Of_Cover__c, Lead_Time_Days__c, Reorder_Point__c,
                   Recommended_Reorder_Qty__c, Stockout_Risk_Level__c, Supplier_Name__c,
                   Last_Forecast_Date__c, Product__c
            FROM Shopify_Inventory_Snapshot__c
            WHERE SKU__c = :sku
            WITH USER_MODE
            LIMIT 1
        ];
        return snapshots.isEmpty() ? null : snapshots[0];
    }

    /**
     * @description Converts a snapshot record into an InventoryHealthDTO.
     */
    public static InventoryHealthDTO buildHealthDTO(Shopify_Inventory_Snapshot__c snap) {
        if (snap == null) {
            return null;
        }
        InventoryHealthDTO dto = new InventoryHealthDTO();
        dto.snapshotId = snap.Id;
        dto.sku = snap.SKU__c;
        dto.productTitle = snap.Product_Title__c;
        dto.locationName = snap.Location_Name__c;
        dto.quantityOnHand = snap.Quantity_On_Hand__c != null ? snap.Quantity_On_Hand__c : 0;
        dto.quantityReserved = snap.Quantity_Reserved__c != null ? snap.Quantity_Reserved__c : 0;
        dto.quantityAvailable = dto.quantityOnHand - dto.quantityReserved;
        dto.dailyVelocityWMA = snap.Daily_Velocity_WMA__c != null ? snap.Daily_Velocity_WMA__c : 0;
        dto.daysOfCover = snap.Days_Of_Cover__c != null ? snap.Days_Of_Cover__c : 0;
        dto.leadTimeDays = snap.Lead_Time_Days__c != null ? snap.Lead_Time_Days__c : 14;
        dto.reorderPoint = snap.Reorder_Point__c != null ? snap.Reorder_Point__c : 0;
        dto.recommendedReorderQty = snap.Recommended_Reorder_Qty__c != null ? snap.Recommended_Reorder_Qty__c : 0;
        dto.stockoutRiskLevel = String.isNotBlank(snap.Stockout_Risk_Level__c) ? snap.Stockout_Risk_Level__c : 'HEALTHY';
        dto.supplierName = snap.Supplier_Name__c;
        dto.lastForecastDate = snap.Last_Forecast_Date__c;

        if (dto.stockoutRiskLevel == 'CRITICAL') {
            dto.statusBadgeTheme = 'slds-theme_error';
            dto.isCritical = true;
            dto.isReorderSoon = false;
        } else if (dto.stockoutRiskLevel == 'REORDER_SOON') {
            dto.statusBadgeTheme = 'slds-theme_warning';
            dto.isCritical = false;
            dto.isReorderSoon = true;
        } else {
            dto.statusBadgeTheme = 'slds-theme_success';
            dto.isCritical = false;
            dto.isReorderSoon = false;
        }

        return dto;
    }

    /**
     * @description Creates or updates a high-priority Procurement Task and Alert record.
     */
    public static Shopify_Procurement_Alert__c createStockoutAlert(
        Shopify_Inventory_Snapshot__c snapshot,
        String rawPayload
    ) {
        if (snapshot == null) {
            return null;
        }

        Shopify_Forecast_Setting__c settings = Shopify_Forecast_Setting__c.getInstance();
        Boolean enableTasks = (settings != null && settings.Enable_Auto_Task_Creation__c != null)
            ? settings.Enable_Auto_Task_Creation__c
            : true;

        String taskSubject = '⚠️ Urgent Stockout Alert: Restock ' + snapshot.SKU__c + 
            ' (' + snapshot.Days_Of_Cover__c + ' Days of Cover remaining)';

        Task procurementTask = null;
        if (enableTasks) {
            Integer daysOffset = 2;
            if (snapshot.Lead_Time_Days__c != null && snapshot.Lead_Time_Days__c > 0) {
                daysOffset = Math.max(1, Integer.valueOf(snapshot.Lead_Time_Days__c / 2));
            }

            procurementTask = new Task(
                Subject = taskSubject,
                Priority = 'High',
                Status = 'Not Started',
                ActivityDate = Date.today().addDays(daysOffset),
                Description = 'Shopify AI Forecast Engine has detected critical stockout risk.\n\n' +
                    'SKU: ' + snapshot.SKU__c + '\n' +
                    'Product: ' + snapshot.Product_Title__c + '\n' +
                    'Quantity On Hand: ' + snapshot.Quantity_On_Hand__c + '\n' +
                    'Daily Velocity (WMA): ' + snapshot.Daily_Velocity_WMA__c + ' units/day\n' +
                    'Days of Cover: ' + snapshot.Days_Of_Cover__c + ' days\n' +
                    'Supplier Lead Time: ' + snapshot.Lead_Time_Days__c + ' days\n' +
                    'Recommended Reorder Quantity: ' + snapshot.Recommended_Reorder_Qty__c + ' units\n' +
                    'Supplier: ' + snapshot.Supplier_Name__c + '\n' +
                    'Fulfillment Location: ' + snapshot.Location_Name__c
            );

            if (Schema.sObjectType.Task.isCreateable()) {
                insert as user procurementTask;
            }
        }

        Shopify_Procurement_Alert__c alert = new Shopify_Procurement_Alert__c(
            SKU__c = snapshot.SKU__c,
            Product_Title__c = snapshot.Product_Title__c,
            Alert_Type__c = 'STOCKOUT_IMMINENT',
            Severity__c = snapshot.Stockout_Risk_Level__c == 'CRITICAL' ? 'CRITICAL' : 'WARNING',
            Days_Of_Cover__c = snapshot.Days_Of_Cover__c,
            Recommended_Order_Qty__c = snapshot.Recommended_Reorder_Qty__c,
            Status__c = 'NEW',
            Inventory_Snapshot__c = snapshot.Id,
            Related_Task_Id__c = procurementTask != null ? procurementTask.Id : null,
            Raw_Payload__c = rawPayload
        );

        if (Schema.sObjectType.Shopify_Procurement_Alert__c.isCreateable()) {
            insert as user alert;
        }

        return alert;
    }

    /**
     * @description Drafts a Purchase Order for replenishment.
     */
    public static Shopify_Procurement_Alert__c draftPurchaseOrder(String sku, Decimal quantity, String supplierName) {
        if (String.isBlank(sku)) {
            throw new ForecastException('SKU is required to draft a purchase order.');
        }

        Shopify_Inventory_Snapshot__c snap = getSnapshotBySku(sku);
        String poNumber = 'PO-' + Datetime.now().format('yyyyMMdd') + '-' + String.valueOf(Math.abs(Crypto.getRandomInteger())).substring(0, 4);

        Shopify_Procurement_Alert__c alert = new Shopify_Procurement_Alert__c(
            SKU__c = sku,
            Product_Title__c = snap != null ? snap.Product_Title__c : 'Restock: ' + sku,
            Alert_Type__c = 'STOCKOUT_IMMINENT',
            Severity__c = 'INFO',
            Days_Of_Cover__c = snap != null ? snap.Days_Of_Cover__c : 0,
            Recommended_Order_Qty__c = quantity,
            Status__c = 'PURCHASE_ORDER_DRAFTED',
            Purchase_Order_Number__c = poNumber,
            Inventory_Snapshot__c = snap != null ? snap.Id : null
        );

        if (Schema.sObjectType.Shopify_Procurement_Alert__c.isCreateable()) {
            insert as user alert;
        }

        return alert;
    }
}
