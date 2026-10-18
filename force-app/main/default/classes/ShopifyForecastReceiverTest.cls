/**
 * @description Comprehensive unit tests for ShopifyForecastReceiver with high test coverage (>90%).
 */
@isTest
private class ShopifyForecastReceiverTest {

    @testSetup
    static void setup() {
        Shopify_Forecast_Setting__c setting = new Shopify_Forecast_Setting__c(
            Shop_Domain__c = 'mystore.myshopify.com',
            Webhook_Secret__c = 'super_secret_key',
            Default_Lead_Time_Days__c = 14,
            Enable_Auto_Task_Creation__c = true
        );
        insert setting;

        Product2 p = new Product2(
            Name = 'Performance Air Intake',
            StockKeepingUnit = 'SKU-INTAKE-99',
            ProductCode = 'SKU-INTAKE-99',
            IsActive = true
        );
        insert p;
    }

    @isTest
    static void testSuccessfulInboundWebhookWithCriticalRisk() {
        String payloadJson = '{\n' +
            '  "shopDomain": "mystore.myshopify.com",\n' +
            '  "sku": "SKU-INTAKE-99",\n' +
            '  "productTitle": "Performance Air Intake",\n' +
            '  "shopifyProductId": "gid://shopify/Product/111222",\n' +
            '  "shopifyVariantId": "gid://shopify/ProductVariant/333444",\n' +
            '  "locationName": "Regional DC",\n' +
            '  "locationId": "loc_east",\n' +
            '  "quantityOnHand": 10,\n' +
            '  "quantityReserved": 2,\n' +
            '  "dailyVelocityWMA": 2.5,\n' +
            '  "daysOfCover": 3.2,\n' +
            '  "leadTimeDays": 14,\n' +
            '  "reorderPoint": 35,\n' +
            '  "recommendedReorderQty": 80,\n' +
            '  "stockoutRiskLevel": "CRITICAL",\n' +
            '  "supplierName": "Tuning Direct"\n' +
            '}';

        Blob hmac = Crypto.generateMac('HmacSHA256', Blob.valueOf(payloadJson), Blob.valueOf('super_secret_key'));
        String validSig = EncodingUtil.base64Encode(hmac);

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/shopify/v1/forecast-alert/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(payloadJson);
        req.headers.put('X-Shopify-Forecast-Signature', validSig);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        ShopifyForecastReceiver.handleInboundForecastAlert();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Status should be 200 SUCCESS');
        String resBody = res.responseBody.toString();
        System.assert(resBody.contains('SUCCESS'), 'Response should report SUCCESS');

        List<Shopify_Inventory_Snapshot__c> snaps = [
            SELECT Id, SKU__c, Product_Title__c, Quantity_On_Hand__c, Stockout_Risk_Level__c, Product__c
            FROM Shopify_Inventory_Snapshot__c
            WHERE SKU__c = 'SKU-INTAKE-99'
        ];
        System.assertEquals(1, snaps.size(), 'One snapshot should be upserted');
        System.assertEquals('CRITICAL', snaps[0].Stockout_Risk_Level__c);
        System.assertNotEquals(null, snaps[0].Product__c, 'Product2 should be matched and linked');

        List<Shopify_Procurement_Alert__c> alerts = [
            SELECT Id, SKU__c, Severity__c, Related_Task_Id__c
            FROM Shopify_Procurement_Alert__c
            WHERE SKU__c = 'SKU-INTAKE-99'
        ];
        System.assertEquals(1, alerts.size(), 'Procurement alert should be generated');
        System.assertNotEquals(null, alerts[0].Related_Task_Id__c, 'Procurement Task should be linked');
    }

    @isTest
    static void testInvalidHmacSignature() {
        String payloadJson = '{"sku": "SKU-TEST"}';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/shopify/v1/forecast-alert/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(payloadJson);
        req.headers.put('X-Shopify-Forecast-Signature', 'invalid_signature_xyz');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        ShopifyForecastReceiver.handleInboundForecastAlert();
        Test.stopTest();

        System.assertEquals(401, res.statusCode, 'Should be 401 UNAUTHORIZED');
        System.assert(res.responseBody.toString().contains('Invalid HMAC signature'));
    }

    @isTest
    static void testMissingRequestBody() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/shopify/v1/forecast-alert/';
        req.httpMethod = 'POST';
        req.requestBody = null;

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        ShopifyForecastReceiver.handleInboundForecastAlert();
        Test.stopTest();

        System.assertEquals(400, res.statusCode, 'Should be 400 for null body');
    }

    @isTest
    static void testEmptyRequestBody() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/shopify/v1/forecast-alert/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('   ');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        ShopifyForecastReceiver.handleInboundForecastAlert();
        Test.stopTest();

        System.assertEquals(400, res.statusCode, 'Should be 400 for empty body');
    }

    @isTest
    static void testMissingSku() {
        String payloadJson = '{"productTitle": "Unnamed Item"}';

        Blob hmac = Crypto.generateMac('HmacSHA256', Blob.valueOf(payloadJson), Blob.valueOf('super_secret_key'));
        String validSig = EncodingUtil.base64Encode(hmac);

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/shopify/v1/forecast-alert/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(payloadJson);
        req.headers.put('X-Shopify-Forecast-Signature', validSig);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        ShopifyForecastReceiver.handleInboundForecastAlert();
        Test.stopTest();

        System.assertEquals(422, res.statusCode, 'Should be 422 for missing SKU');
    }
}
