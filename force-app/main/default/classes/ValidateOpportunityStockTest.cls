/**
 * @description Comprehensive unit tests for ValidateOpportunityStock invocable action (>90% coverage).
 */
@isTest
private class ValidateOpportunityStockTest {

    @testSetup
    static void setup() {
        Product2 p1 = new Product2(
            Name = 'Commercial Spark Plug Box',
            StockKeepingUnit = 'SKU-PLUG-10',
            ProductCode = 'SKU-PLUG-10',
            IsActive = true
        );
        Product2 p2 = new Product2(
            Name = 'Standard Ignition Wire',
            StockKeepingUnit = 'SKU-WIRE-20',
            ProductCode = 'SKU-WIRE-20',
            IsActive = true
        );
        insert new List<Product2>{ p1, p2 };

        Shopify_Inventory_Snapshot__c s1 = new Shopify_Inventory_Snapshot__c(
            SKU__c = 'SKU-PLUG-10',
            Product_Title__c = 'Commercial Spark Plug Box',
            Quantity_On_Hand__c = 100,
            Quantity_Reserved__c = 10,
            Daily_Velocity_WMA__c = 2.0,
            Days_Of_Cover__c = 45.0,
            Lead_Time_Days__c = 14,
            Stockout_Risk_Level__c = 'HEALTHY'
        );

        Shopify_Inventory_Snapshot__c s2 = new Shopify_Inventory_Snapshot__c(
            SKU__c = 'SKU-WIRE-20',
            Product_Title__c = 'Standard Ignition Wire',
            Quantity_On_Hand__c = 20,
            Quantity_Reserved__c = 5,
            Daily_Velocity_WMA__c = 3.0,
            Days_Of_Cover__c = 5.0,
            Lead_Time_Days__c = 14,
            Stockout_Risk_Level__c = 'CRITICAL'
        );

        insert new List<Shopify_Inventory_Snapshot__c>{ s1, s2 };
    }

    @isTest
    static void testHealthyStockAvailability() {
        ValidateOpportunityStock.OpportunityStockCheckRequest req = new ValidateOpportunityStock.OpportunityStockCheckRequest();
        req.sku = 'SKU-PLUG-10';
        req.quantityRequested = 30;

        Test.startTest();
        List<ValidateOpportunityStock.OpportunityStockCheckResult> results =
            ValidateOpportunityStock.checkStockAvailability(new List<ValidateOpportunityStock.OpportunityStockCheckRequest>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size());
        ValidateOpportunityStock.OpportunityStockCheckResult res = results[0];
        System.assertEquals(true, res.isAvailable);
        System.assertEquals(true, res.allowCommit);
        System.assertEquals(90, res.availableStock);
        System.assert(res.warningMessage.contains('Sufficient Shopify inventory'));
    }

    @isTest
    static void testShortageExceedingAvailableStock() {
        ValidateOpportunityStock.OpportunityStockCheckRequest req = new ValidateOpportunityStock.OpportunityStockCheckRequest();
        req.sku = 'SKU-PLUG-10';
        req.quantityRequested = 150; // Only 90 available

        Test.startTest();
        List<ValidateOpportunityStock.OpportunityStockCheckResult> results =
            ValidateOpportunityStock.checkStockAvailability(new List<ValidateOpportunityStock.OpportunityStockCheckRequest>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size());
        ValidateOpportunityStock.OpportunityStockCheckResult res = results[0];
        System.assertEquals(false, res.isAvailable);
        System.assertEquals(false, res.allowCommit);
        System.assert(res.warningMessage.contains('Stock Shortage Alert'));
    }

    @isTest
    static void testCriticalStockoutWarningWithAvailableStock() {
        Product2 p2 = [SELECT Id FROM Product2 WHERE StockKeepingUnit = 'SKU-WIRE-20' LIMIT 1];
        ValidateOpportunityStock.OpportunityStockCheckRequest req = new ValidateOpportunityStock.OpportunityStockCheckRequest();
        req.product2Id = p2.Id;
        req.quantityRequested = 10; // 15 available, but days of cover is critical (5 days <= 14 lead time)

        Test.startTest();
        List<ValidateOpportunityStock.OpportunityStockCheckResult> results =
            ValidateOpportunityStock.checkStockAvailability(new List<ValidateOpportunityStock.OpportunityStockCheckRequest>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size());
        ValidateOpportunityStock.OpportunityStockCheckResult res = results[0];
        System.assertEquals(true, res.isAvailable);
        System.assertEquals(false, res.allowCommit, 'Should caution commit due to critical storefront depletion');
        System.assert(res.warningMessage.contains('Imminent Stockout Warning'));
    }

    @isTest
    static void testNoSnapshotFoundAndEmptyList() {
        ValidateOpportunityStock.OpportunityStockCheckRequest req = new ValidateOpportunityStock.OpportunityStockCheckRequest();
        req.sku = 'SKU-UNKNOWN-999';
        req.quantityRequested = 10;

        Test.startTest();
        List<ValidateOpportunityStock.OpportunityStockCheckResult> results =
            ValidateOpportunityStock.checkStockAvailability(new List<ValidateOpportunityStock.OpportunityStockCheckRequest>{ req });
        List<ValidateOpportunityStock.OpportunityStockCheckResult> emptyRes =
            ValidateOpportunityStock.checkStockAvailability(new List<ValidateOpportunityStock.OpportunityStockCheckRequest>());
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].allowCommit);
        System.assert(results[0].warningMessage.contains('No live Shopify forecast snapshot found'));
        System.assertEquals(0, emptyRes.size());
    }
}
