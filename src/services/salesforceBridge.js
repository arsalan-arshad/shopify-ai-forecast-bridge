import jsforce from 'jsforce';

/**
 * Salesforce connection client and synchronization dispatcher.
 */
export class SalesforceBridge {
  constructor(config = {}) {
    this.loginUrl = config.loginUrl || process.env.SALESFORCE_LOGIN_URL || 'https://login.salesforce.com';
    this.username = config.username || process.env.SALESFORCE_USERNAME;
    this.password = config.password || process.env.SALESFORCE_PASSWORD;
    this.securityToken = config.securityToken || process.env.SALESFORCE_SECURITY_TOKEN || '';
    this.conn = null;
  }

  async connect() {
    if (this.conn && this.conn.accessToken) {
      return this.conn;
    }

    this.conn = new jsforce.Connection({
      loginUrl: this.loginUrl
    });

    if (this.username && this.password) {
      await this.conn.login(this.username, this.password + this.securityToken);
    }
    return this.conn;
  }

  /**
   * Pushes a forecast snapshot record to Salesforce.
   */
  async upsertSnapshot(snapshotData) {
    const conn = await this.connect();
    return conn.sobject('Shopify_Inventory_Snapshot__c').upsert(
      {
        SKU__c: snapshotData.sku,
        Product_Title__c: snapshotData.productTitle,
        Location_Name__c: snapshotData.locationName,
        Quantity_On_Hand__c: snapshotData.quantityOnHand,
        Quantity_Reserved__c: snapshotData.quantityReserved,
        Daily_Velocity_WMA__c: snapshotData.dailyVelocityWMA,
        Days_Of_Cover__c: snapshotData.daysOfCover,
        Lead_Time_Days__c: snapshotData.leadTimeDays,
        Reorder_Point__c: snapshotData.reorderPoint,
        Recommended_Reorder_Qty__c: snapshotData.recommendedReorderQty,
        Stockout_Risk_Level__c: snapshotData.stockoutRiskLevel,
        Supplier_Name__c: snapshotData.supplierName,
        Last_Forecast_Date__c: new Date().toISOString()
      },
      'SKU__c'
    );
  }

  /**
   * Queries existing inventory snapshots.
   */
  async querySnapshots(limit = 100) {
    const conn = await this.connect();
    return conn.sobject('Shopify_Inventory_Snapshot__c').find().limit(limit).execute();
  }
}
