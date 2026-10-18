/**
 * @description Inbound REST Webhook endpoint receiving deterministic inventory forecasting events
 *              and stockout triggers from shopify-ai-forecast-app.
 * @group Shopify AI Forecast Bridge
 */
@RestResource(urlMapping='/shopify/v1/forecast-alert/*')
global with sharing class ShopifyForecastReceiver {

    public class ForecastPayload {
        public String shopDomain;
        public String sku;
        public String productTitle;
        public String shopifyProductId;
        public String shopifyVariantId;
        public String locationName;
        public String locationId;
        public Decimal quantityOnHand;
        public Decimal quantityReserved;
        public Decimal dailyVelocityWMA;
        public Decimal daysOfCover;
        public Decimal leadTimeDays;
        public Decimal reorderPoint;
        public Decimal recommendedReorderQty;
        public String stockoutRiskLevel;
        public String supplierName;
    }

    public class ResponseWrapper {
        public String status;
        public String message;
        public Id snapshotId;
        public Id alertId;
        public Id taskId;
    }

    /**
     * @description Inbound webhook handler.
     */
    @HttpPost
    global static void handleInboundForecastAlert() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        ResponseWrapper responseObj = new ResponseWrapper();

        try {
            if (req == null || req.requestBody == null) {
                res.statusCode = 400;
                responseObj.status = 'ERROR';
                responseObj.message = 'Missing request body.';
                res.responseBody = Blob.valueOf(JSON.serialize(responseObj));
                return;
            }

            String bodyStr = req.requestBody.toString();
            if (String.isBlank(bodyStr)) {
                res.statusCode = 400;
                responseObj.status = 'ERROR';
                responseObj.message = 'Empty request body.';
                res.responseBody = Blob.valueOf(JSON.serialize(responseObj));
                return;
            }

            // Verify HMAC signature if configured
            Shopify_Forecast_Setting__c setting = Shopify_Forecast_Setting__c.getInstance();
            if (setting != null && String.isNotBlank(setting.Webhook_Secret__c)) {
                String signature = req.headers.get('X-Shopify-Forecast-Signature');
                if (String.isBlank(signature)) {
                    signature = req.headers.get('X-Shopify-Hmac-Sha256');
                }

                if (String.isNotBlank(signature)) {
                    Blob hmac = Crypto.generateMac(
                        'HmacSHA256',
                        Blob.valueOf(bodyStr),
                        Blob.valueOf(setting.Webhook_Secret__c)
                    );
                    String calculatedSig = EncodingUtil.base64Encode(hmac);
                    if (signature != calculatedSig && signature != EncodingUtil.convertToHex(hmac)) {
                        res.statusCode = 401;
                        responseObj.status = 'UNAUTHORIZED';
                        responseObj.message = 'Invalid HMAC signature.';
                        res.responseBody = Blob.valueOf(JSON.serialize(responseObj));
                        return;
                    }
                }
            }

            ForecastPayload payload = (ForecastPayload) JSON.deserialize(bodyStr, ForecastPayload.class);
            if (payload == null || String.isBlank(payload.sku)) {
                res.statusCode = 422;
                responseObj.status = 'ERROR';
                responseObj.message = 'Missing required field: sku.';
                res.responseBody = Blob.valueOf(JSON.serialize(responseObj));
                return;
            }

            // Upsert snapshot
            Shopify_Inventory_Snapshot__c snapshot = ShopifyForecastService.getSnapshotBySku(payload.sku);
            if (snapshot == null) {
                snapshot = new Shopify_Inventory_Snapshot__c(SKU__c = payload.sku);
            }

            snapshot.Product_Title__c = payload.productTitle;
            snapshot.Shopify_Product_Id__c = payload.shopifyProductId;
            snapshot.Shopify_Variant_Id__c = payload.shopifyVariantId;
            snapshot.Location_Name__c = payload.locationName;
            snapshot.Location_Id__c = payload.locationId;
            snapshot.Quantity_On_Hand__c = payload.quantityOnHand != null ? payload.quantityOnHand : 0;
            snapshot.Quantity_Reserved__c = payload.quantityReserved != null ? payload.quantityReserved : 0;
            snapshot.Daily_Velocity_WMA__c = payload.dailyVelocityWMA != null ? payload.dailyVelocityWMA : 0;
            snapshot.Days_Of_Cover__c = payload.daysOfCover != null ? payload.daysOfCover : 0;
            snapshot.Lead_Time_Days__c = payload.leadTimeDays != null ? payload.leadTimeDays : 14;
            snapshot.Reorder_Point__c = payload.reorderPoint != null ? payload.reorderPoint : 0;
            snapshot.Recommended_Reorder_Qty__c = payload.recommendedReorderQty != null ? payload.recommendedReorderQty : 0;
            snapshot.Supplier_Name__c = payload.supplierName;
            snapshot.Last_Forecast_Date__c = Datetime.now();

            // Evaluate risk
            String computedRisk = ShopifyForecastService.calculateStockoutRisk(
                snapshot.Days_Of_Cover__c,
                snapshot.Lead_Time_Days__c
            );
            if (String.isNotBlank(payload.stockoutRiskLevel)) {
                snapshot.Stockout_Risk_Level__c = payload.stockoutRiskLevel;
            } else {
                snapshot.Stockout_Risk_Level__c = computedRisk;
            }

            // Link to Product2 if available
            List<Product2> matchingProducts = [
                SELECT Id FROM Product2
                WHERE StockKeepingUnit = :payload.sku OR ProductCode = :payload.sku
                WITH USER_MODE
                LIMIT 1
            ];
            if (!matchingProducts.isEmpty()) {
                snapshot.Product__c = matchingProducts[0].Id;
            }

            if (Schema.sObjectType.Shopify_Inventory_Snapshot__c.isCreateable() &&
                Schema.sObjectType.Shopify_Inventory_Snapshot__c.isUpdateable()) {
                upsert as user snapshot SKU__c;
            }

            responseObj.snapshotId = snapshot.Id;

            // Trigger Alert & Task if at or below reorder threshold
            if (snapshot.Stockout_Risk_Level__c == 'CRITICAL' ||
                (snapshot.Days_Of_Cover__c <= snapshot.Lead_Time_Days__c)) {
                Shopify_Procurement_Alert__c alert = ShopifyForecastService.createStockoutAlert(snapshot, bodyStr);
                if (alert != null) {
                    responseObj.alertId = alert.Id;
                    responseObj.taskId = alert.Related_Task_Id__c;
                }
            }

            res.statusCode = 200;
            responseObj.status = 'SUCCESS';
            responseObj.message = 'Forecast snapshot processed successfully.';
            res.responseBody = Blob.valueOf(JSON.serialize(responseObj));

        } catch (Exception ex) {
            res.statusCode = 500;
            responseObj.status = 'ERROR';
            responseObj.message = 'Internal server error: ' + ex.getMessage();
            res.responseBody = Blob.valueOf(JSON.serialize(responseObj));
        }
    }
}
