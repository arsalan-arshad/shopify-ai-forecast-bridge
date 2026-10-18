/**
 * @description Comprehensive unit tests for ShopifyForecastController with high test coverage (>90%).
 */
@isTest
private class ShopifyForecastControllerTest {

    @testSetup
    static void setup() {
        Product2 prod = new Product2(
            Name = 'Heavy Duty Oil Filter',
            StockKeepingUnit = 'SKU-OIL-100',
            ProductCode = 'SKU-OIL-100',
            IsActive = true
        );
        insert prod;

        Shopify_Inventory_Snapshot__c snap = new Shopify_Inventory_Snapshot__c(
            SKU__c = 'SKU-OIL-100',
            Product_Title__c = 'Heavy Duty Oil Filter',
            Location_Name__c = 'Central Hub',
            Quantity_On_Hand__c = 50,
            Quantity_Reserved__c = 10,
            Daily_Velocity_WMA__c = 5.0,
            Days_Of_Cover__c = 8.0,
            Lead_Time_Days__c = 14,
            Reorder_Point__c = 70,
            Recommended_Reorder_Qty__c = 200,
            Stockout_Risk_Level__c = 'CRITICAL',
            Supplier_Name__c = 'LubeMaster Corp',
            Product__c = prod.Id,
            Last_Forecast_Date__c = Datetime.now()
        );
        insert snap;

        Opportunity opp = new Opportunity(
            Name = 'Wholesale Deal Q4',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;
    }

    @isTest
    static void testGetInventoryHealthBySnapshotId() {
        Shopify_Inventory_Snapshot__c snap = [SELECT Id FROM Shopify_Inventory_Snapshot__c LIMIT 1];

        Test.startTest();
        ShopifyForecastService.InventoryHealthDTO dto = ShopifyForecastController.getInventoryHealth(snap.Id);
        ShopifyForecastService.InventoryHealthDTO nullDto = ShopifyForecastController.getInventoryHealth(null);
        Test.stopTest();

        System.assertNotEquals(null, dto);
        System.assertEquals('SKU-OIL-100', dto.sku);
        System.assertEquals(40, dto.quantityAvailable);
        System.assertEquals(true, dto.isCritical);
        System.assertEquals(null, nullDto);
    }

    @isTest
    static void testGetInventoryHealthByProductId() {
        Product2 prod = [SELECT Id FROM Product2 WHERE StockKeepingUnit = 'SKU-OIL-100' LIMIT 1];

        Test.startTest();
        ShopifyForecastService.InventoryHealthDTO dto = ShopifyForecastController.getInventoryHealth(prod.Id);
        Test.stopTest();

        System.assertNotEquals(null, dto);
        System.assertEquals('SKU-OIL-100', dto.sku);
    }

    @isTest
    static void testGetInventoryHealthByOpportunityId() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Test.startTest();
        ShopifyForecastService.InventoryHealthDTO dto = ShopifyForecastController.getInventoryHealth(opp.Id);
        Test.stopTest();

        // No line item attached yet, so should be null
        System.assertEquals(null, dto);
    }

    @isTest
    static void testGetForecastDashboardSummary() {
        Test.startTest();
        ShopifyForecastController.DashboardSummaryDTO summary = ShopifyForecastController.getForecastDashboardSummary();
        Test.stopTest();

        System.assertNotEquals(null, summary);
        System.assertEquals(1, summary.totalMonitored);
        System.assertEquals(1, summary.criticalStockouts);
        System.assertEquals(0, summary.reorderSoon);
        System.assertEquals(0, summary.healthy);
        System.assertEquals(200, summary.totalReorderUnitsRecommended);
        System.assertEquals(1, summary.criticalItems.size());
    }

    @isTest
    static void testTriggerReorderAction() {
        Test.startTest();
        String poNumber = ShopifyForecastController.triggerReorderAction('SKU-OIL-100', 300, 'LubeMaster Corp');
        Test.stopTest();

        System.assertNotEquals(null, poNumber);
        System.assert(poNumber.startsWith('PO-'));

        List<Shopify_Procurement_Alert__c> alerts = [
            SELECT Id, Purchase_Order_Number__c, Status__c, Recommended_Order_Qty__c
            FROM Shopify_Procurement_Alert__c
            WHERE Purchase_Order_Number__c = :poNumber
        ];
        System.assertEquals(1, alerts.size());
        System.assertEquals('PURCHASE_ORDER_DRAFTED', alerts[0].Status__c);
        System.assertEquals(300, alerts[0].Recommended_Order_Qty__c);
    }

    @isTest
    static void testResolveProcurementAlert() {
        Shopify_Procurement_Alert__c alert = new Shopify_Procurement_Alert__c(
            SKU__c = 'SKU-OIL-100',
            Alert_Type__c = 'STOCKOUT_IMMINENT',
            Status__c = 'NEW'
        );
        insert alert;

        Test.startTest();
        Boolean success = ShopifyForecastController.resolveProcurementAlert(alert.Id, 'PO placed with vendor.');
        Boolean failNull = ShopifyForecastController.resolveProcurementAlert(null, 'Note');
        Test.stopTest();

        System.assertEquals(true, success);
        System.assertEquals(false, failNull);

        Shopify_Procurement_Alert__c updated = [SELECT Status__c, Raw_Payload__c FROM Shopify_Procurement_Alert__c WHERE Id = :alert.Id];
        System.assertEquals('RESOLVED', updated.Status__c);
        System.assert(updated.Raw_Payload__c.contains('Resolution Note'));
    }
}
