import { LightningElement, api, wire, track } from 'lwc';
import getInventoryHealth from '@salesforce/apex/ShopifyForecastController.getInventoryHealth';
import triggerReorderAction from '@salesforce/apex/ShopifyForecastController.triggerReorderAction';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

export default class ShopifyForecastIntelligence extends LightningElement {
  @api recordId;

  @track inventoryData;
  @track isLoading = true;
  @track errorMessage;
  @track isModalOpen = false;
  @track reorderQtyInput;

  wiredForecastResult;

  @wire(getInventoryHealth, { recordId: '$recordId' })
  wiredForecast(result) {
    this.wiredForecastResult = result;
    const { data, error } = result;
    this.isLoading = false;

    if (data) {
      this.inventoryData = data;
      this.reorderQtyInput = data.recommendedReorderQty || 100;
      this.errorMessage = null;
    } else if (error) {
      this.errorMessage = error.body ? error.body.message : 'Failed to retrieve forecast snapshot.';
      this.inventoryData = null;
    }
  }

  get hasData() {
    return !!this.inventoryData;
  }

  get isActionDisabled() {
    return !this.hasData || this.isLoading;
  }

  get badgeClass() {
    if (!this.inventoryData) return '';
    if (this.inventoryData.isCritical) {
      return 'badge-critical';
    } else if (this.inventoryData.isReorderSoon) {
      return 'badge-warning';
    }
    return 'badge-healthy';
  }

  get formattedLastForecast() {
    if (!this.inventoryData || !this.inventoryData.lastForecastDate) return 'N/A';
    return new Date(this.inventoryData.lastForecastDate).toLocaleString();
  }

  handleRefresh() {
    this.isLoading = true;
    refreshApex(this.wiredForecastResult).finally(() => {
      this.isLoading = false;
    });
  }

  handleOpenReorderModal() {
    if (this.inventoryData) {
      this.reorderQtyInput = this.inventoryData.recommendedReorderQty;
      this.isModalOpen = true;
    }
  }

  handleCloseReorderModal() {
    this.isModalOpen = false;
  }

  handleQtyChange(event) {
    this.reorderQtyInput = Number(event.target.value);
  }

  handleSubmitReorder() {
    if (!this.reorderQtyInput || this.reorderQtyInput <= 0) {
      this.showToast('Invalid Quantity', 'Please specify a valid order quantity greater than zero.', 'error');
      return;
    }

    this.isLoading = true;
    this.isModalOpen = false;

    triggerReorderAction({
      sku: this.inventoryData.sku,
      quantity: this.reorderQtyInput,
      supplierName: this.inventoryData.supplierName
    })
      .then((poNumber) => {
        this.showToast(
          'Purchase Order Drafted',
          `Successfully created draft Purchase Order ${poNumber} for ${this.reorderQtyInput} units.`,
          'success'
        );
        return refreshApex(this.wiredForecastResult);
      })
      .catch((err) => {
        const msg = err.body ? err.body.message : err.message;
        this.showToast('Reorder Error', `Failed to draft Purchase Order: ${msg}`, 'error');
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant
      })
    );
  }
}
