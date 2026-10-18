/**
 * @description Comprehensive unit tests for ShopifyForecastService with high test coverage (>90%).
 */
@isTest
private class ShopifyForecastServiceTest {

    @testSetup
    static void setupTestData() {
        Shopify_Forecast_Setting__c settings = new Shopify_Forecast_Setting__c(
            Shop_Domain__c = 'test-store.myshopify.com',
            Webhook_Secret__c = 'test_secret_123',
            Default_Lead_Time_Days__c = 14,
            Enable_Auto_Task_Creation__c = true,
            Enable_Opportunity_Validation__c = true
        );
        insert settings;

        Shopify_Inventory_Snapshot__c snap = new Shopify_Inventory_Snapshot__c(
            SKU__c = 'SKU-TEST-001',
            Product_Title__c = 'High Flow Air Filter',
            Location_Name__c = 'Main Warehouse',
            Quantity_On_Hand__c = 20,
            Quantity_Reserved__c = 5,
            Daily_Velocity_WMA__c = 3.0,
            Days_Of_Cover__c = 5.0,
            Lead_Time_Days__c = 14,
            Reorder_Point__c = 42,
            Recommended_Reorder_Qty__c = 100,
            Stockout_Risk_Level__c = 'CRITICAL',
            Supplier_Name__c = 'AeroParts Global',
            Last_Forecast_Date__c = Datetime.now()
        );
        insert snap;
    }

    @isTest
    static void testCalculateStockoutRisk() {
        System.assertEquals('CRITICAL', ShopifyForecastService.calculateStockoutRisk(5, 14), 'Should be CRITICAL');
        System.assertEquals('CRITICAL', ShopifyForecastService.calculateStockoutRisk(14, 14), 'Should be CRITICAL at boundary');
        System.assertEquals('REORDER_SOON', ShopifyForecastService.calculateStockoutRisk(18, 14), 'Should be REORDER_SOON');
        System.assertEquals('HEALTHY', ShopifyForecastService.calculateStockoutRisk(30, 14), 'Should be HEALTHY');
        System.assertEquals('HEALTHY', ShopifyForecastService.calculateStockoutRisk(null, 14), 'Null should return HEALTHY');
        System.assertEquals('HEALTHY', ShopifyForecastService.calculateStockoutRisk(10, null), 'Null lead time should return HEALTHY');
    }

    @isTest
    static void testGetSnapshotBySku() {
        Test.startTest();
        Shopify_Inventory_Snapshot__c found = ShopifyForecastService.getSnapshotBySku('SKU-TEST-001');
        Shopify_Inventory_Snapshot__c notFound = ShopifyForecastService.getSnapshotBySku('SKU-NON-EXISTENT');
        Shopify_Inventory_Snapshot__c blank = ShopifyForecastService.getSnapshotBySku('');
        Test.stopTest();

        System.assertNotEquals(null, found, 'Snapshot should be found');
        System.assertEquals('SKU-TEST-001', found.SKU__c);
        System.assertEquals(null, notFound, 'Non-existent should return null');
        System.assertEquals(null, blank, 'Blank SKU should return null');
    }

    @isTest
    static void testBuildHealthDTO() {
        Shopify_Inventory_Snapshot__c snap = ShopifyForecastService.getSnapshotBySku('SKU-TEST-001');

        Test.startTest();
        ShopifyForecastService.InventoryHealthDTO dto = ShopifyForecastService.buildHealthDTO(snap);
        ShopifyForecastService.InventoryHealthDTO nullDto = ShopifyForecastService.buildHealthDTO(null);
        Test.stopTest();

        System.assertNotEquals(null, dto);
        System.assertEquals('SKU-TEST-001', dto.sku);
        System.assertEquals(15, dto.quantityAvailable);
        System.assertEquals(true, dto.isCritical);
        System.assertEquals('slds-theme_error', dto.statusBadgeTheme);
        System.assertEquals(null, nullDto);

        // Test warning and healthy themes
        snap.Stockout_Risk_Level__c = 'REORDER_SOON';
        ShopifyForecastService.InventoryHealthDTO warningDto = ShopifyForecastService.buildHealthDTO(snap);
        System.assertEquals(true, warningDto.isReorderSoon);
        System.assertEquals('slds-theme_warning', warningDto.statusBadgeTheme);

        snap.Stockout_Risk_Level__c = 'HEALTHY';
        ShopifyForecastService.InventoryHealthDTO healthyDto = ShopifyForecastService.buildHealthDTO(snap);
        System.assertEquals(false, healthyDto.isCritical);
        System.assertEquals(false, healthyDto.isReorderSoon);
        System.assertEquals('slds-theme_success', healthyDto.statusBadgeTheme);
    }

    @isTest
    static void testCreateStockoutAlertAndTask() {
        Shopify_Inventory_Snapshot__c snap = ShopifyForecastService.getSnapshotBySku('SKU-TEST-001');

        Test.startTest();
        Shopify_Procurement_Alert__c alert = ShopifyForecastService.createStockoutAlert(snap, '{"test":true}');
        Test.stopTest();

        System.assertNotEquals(null, alert, 'Alert record should be created');
        System.assertEquals('SKU-TEST-001', alert.SKU__c);
        System.assertEquals('CRITICAL', alert.Severity__c);
        System.assertNotEquals(null, alert.Related_Task_Id__c, 'Task should have been created');

        List<Task> createdTasks = [SELECT Id, Subject, Priority FROM Task WHERE Id = :alert.Related_Task_Id__c];
        System.assertEquals(1, createdTasks.size(), 'One Task should exist');
        System.assertEquals('High', createdTasks[0].Priority);
    }

    @isTest
    static void testDraftPurchaseOrder() {
        Test.startTest();
        Shopify_Procurement_Alert__c poAlert = ShopifyForecastService.draftPurchaseOrder('SKU-TEST-001', 250, 'AeroParts Global');
        Test.stopTest();

        System.assertNotEquals(null, poAlert);
        System.assertEquals('PURCHASE_ORDER_DRAFTED', poAlert.Status__c);
        System.assert(poAlert.Purchase_Order_Number__c.startsWith('PO-'), 'PO Number should start with PO-');
        System.assertEquals(250, poAlert.Recommended_Order_Qty__c);

        try {
            ShopifyForecastService.draftPurchaseOrder('', 100, 'Vendor');
            System.assert(false, 'Should have thrown exception for blank SKU');
        } catch (ShopifyForecastService.ForecastException ex) {
            System.assert(ex.getMessage().contains('SKU is required'));
        }
    }
}
