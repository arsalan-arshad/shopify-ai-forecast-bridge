/**
 * @description Comprehensive unit tests for ShopifyAIChatController & ShopifyAIChatService (>90% coverage).
 */
@isTest
private class ShopifyAIChatControllerTest {

    @testSetup
    static void setup() {
        Shopify_Inventory_Snapshot__c snap1 = new Shopify_Inventory_Snapshot__c(
            SKU__c = 'SKU-AIR-01',
            Product_Title__c = 'Industrial Carbon Air Filter',
            Quantity_On_Hand__c = 30,
            Quantity_Reserved__c = 10,
            Daily_Velocity_WMA__c = 4.0,
            Days_Of_Cover__c = 5.0,
            Lead_Time_Days__c = 14,
            Reorder_Point__c = 56,
            Recommended_Reorder_Qty__c = 120,
            Stockout_Risk_Level__c = 'CRITICAL',
            Supplier_Name__c = 'Apex Filtration Co'
        );

        Shopify_Inventory_Snapshot__c snap2 = new Shopify_Inventory_Snapshot__c(
            SKU__c = 'SKU-SAFE-02',
            Product_Title__c = 'Standard Cabin Filter',
            Quantity_On_Hand__c = 200,
            Quantity_Reserved__c = 20,
            Daily_Velocity_WMA__c = 2.0,
            Days_Of_Cover__c = 90.0,
            Lead_Time_Days__c = 14,
            Reorder_Point__c = 28,
            Recommended_Reorder_Qty__c = 50,
            Stockout_Risk_Level__c = 'HEALTHY',
            Supplier_Name__c = 'CleanAir International'
        );

        insert new List<Shopify_Inventory_Snapshot__c>{ snap1, snap2 };
    }

    @isTest
    static void testSpecificSkuInquiry() {
        Test.startTest();
        ShopifyAIChatService.ChatMessageDTO res = ShopifyAIChatController.sendChatMessage('Tell me about SKU-AIR-01');
        Test.stopTest();

        System.assertNotEquals(null, res);
        System.assertEquals('assistant', res.sender);
        System.assertEquals(true, res.isGrounded);
        System.assert(res.content.contains('SKU-AIR-01'));
        System.assert(res.content.contains('Industrial Carbon Air Filter'));
        System.assert(res.content.contains('CRITICAL'));
        System.assertEquals(1, res.citedSkus.size());
        System.assertEquals('SKU-AIR-01', res.citedSkus[0]);
    }

    @isTest
    static void testStockoutInquiry() {
        Test.startTest();
        ShopifyAIChatService.ChatMessageDTO res = ShopifyAIChatController.sendChatMessage('Which products will run out before Black Friday?');
        Test.stopTest();

        System.assertNotEquals(null, res);
        System.assert(res.content.contains('Imminent Stockout Risk Analysis'));
        System.assert(res.content.contains('SKU-AIR-01'));
        System.assert(!res.citedSkus.isEmpty());
    }

    @isTest
    static void testSupplierInquiry() {
        Test.startTest();
        ShopifyAIChatService.ChatMessageDTO res = ShopifyAIChatController.sendChatMessage('Show vendor and supplier breakdown');
        Test.stopTest();

        System.assertNotEquals(null, res);
        System.assert(res.content.contains('Supplier Restock & Allocation Summary'));
        System.assert(res.content.contains('Apex Filtration Co'));
        System.assert(res.content.contains('CleanAir International'));
    }

    @isTest
    static void testGeneralInquiryAndEmptyQuery() {
        Test.startTest();
        ShopifyAIChatService.ChatMessageDTO generalRes = ShopifyAIChatController.sendChatMessage('How is our inventory overall?');
        ShopifyAIChatService.ChatMessageDTO emptyRes = ShopifyAIChatController.sendChatMessage('');
        Test.stopTest();

        System.assert(generalRes.content.contains('Overall Inventory Intelligence Summary'));
        System.assert(emptyRes.content.contains('Please enter an inventory or restock question'));
    }

    @isTest
    static void testGetSuggestedPrompts() {
        Test.startTest();
        List<String> prompts = ShopifyAIChatController.getSuggestedPrompts();
        Test.stopTest();

        System.assertNotEquals(null, prompts);
        System.assert(prompts.size() >= 3);
    }
}
