import { LightningElement, track, wire } from 'lwc';
import sendChatMessage from '@salesforce/apex/ShopifyAIChatController.sendChatMessage';
import getSuggestedPrompts from '@salesforce/apex/ShopifyAIChatController.getSuggestedPrompts';

export default class ShopifyForecastChat extends LightningElement {
  @track messages = [];
  @track userInput = '';
  @track isThinking = false;
  @track suggestedPrompts = [];

  connectedCallback() {
    // Initial welcome message
    this.messages.push({
      id: 'welcome-msg',
      sender: 'assistant',
      senderLabel: 'Shopify Inventory AI',
      timeStr: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
      content:
        '👋 Welcome! I am your **Shopify Inventory & Forecast Intelligence Assistant**.\n\n' +
        'I am grounded in your live snapshot data, Weighted Moving Average (WMA) velocities, and days-of-cover calculations with **zero hallucination**.\n\n' +
        'Try asking: *"Which products will run out before Black Friday?"* or *"Forecast for SKU-AIR-01"*.',
      formattedContent:
        '<p>👋 Welcome! I am your <strong>Shopify Inventory &amp; Forecast Intelligence Assistant</strong>.</p>' +
        '<p>I am grounded in your live snapshot data, Weighted Moving Average (WMA) velocities, and days-of-cover calculations with <strong>zero hallucination</strong>.</p>' +
        '<p>Try asking: <em>"Which products will run out before Black Friday?"</em> or <em>"Forecast for SKU-AIR-01"</em>.</p>',
      containerClass: 'message-row assistant-row',
      bubbleClass: 'message-bubble assistant-bubble'
    });
  }

  @wire(getSuggestedPrompts)
  wiredPrompts({ data }) {
    if (data) {
      this.suggestedPrompts = data;
    }
  }

  get isSendDisabled() {
    return !this.userInput || this.userInput.trim().length === 0 || this.isThinking;
  }

  handleInputChange(event) {
    this.userInput = event.target.value;
  }

  handleKeyUp(event) {
    if (event.key === 'Enter' && !this.isSendDisabled) {
      this.handleSendMessage();
    }
  }

  handleSelectChip(event) {
    const prompt = event.currentTarget.dataset.prompt;
    if (prompt) {
      this.userInput = prompt;
      this.handleSendMessage();
    }
  }

  handleSendMessage() {
    const text = this.userInput.trim();
    if (!text) return;

    // Add user message
    const userMsg = {
      id: 'user-' + Date.now(),
      sender: 'user',
      senderLabel: 'You',
      timeStr: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
      content: text,
      formattedContent: `<p>${this.escapeHtml(text)}</p>`,
      containerClass: 'message-row user-row',
      bubbleClass: 'message-bubble user-bubble'
    };

    this.messages.push(userMsg);
    this.userInput = '';
    this.isThinking = true;

    this.scrollToBottom();

    sendChatMessage({ userMessage: text })
      .then((res) => {
        const assistantMsg = {
          id: res.id || 'ai-' + Date.now(),
          sender: 'assistant',
          senderLabel: 'Shopify Inventory AI',
          timeStr: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
          content: res.content,
          formattedContent: this.parseMarkdownToHtml(res.content),
          containerClass: 'message-row assistant-row',
          bubbleClass: 'message-bubble assistant-bubble'
        };
        this.messages.push(assistantMsg);
      })
      .catch((err) => {
        const errorContent = err.body ? err.body.message : err.message;
        this.messages.push({
          id: 'err-' + Date.now(),
          sender: 'assistant',
          senderLabel: 'Shopify Inventory AI',
          timeStr: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
          content: 'Error: ' + errorContent,
          formattedContent: `<p class="slds-text-color_error">⚠️ Error communicating with forecast agent: ${this.escapeHtml(errorContent)}</p>`,
          containerClass: 'message-row assistant-row',
          bubbleClass: 'message-bubble assistant-bubble'
        });
      })
      .finally(() => {
        this.isThinking = false;
        this.scrollToBottom();
      });
  }

  handleClearChat() {
    this.messages = [];
    this.connectedCallback();
  }

  scrollToBottom() {
    setTimeout(() => {
      const viewport = this.template.querySelector('.messages-viewport');
      if (viewport) {
        viewport.scrollTop = viewport.scrollHeight;
      }
    }, 100);
  }

  escapeHtml(str) {
    return str
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }

  parseMarkdownToHtml(md) {
    if (!md) return '';
    let html = md;

    // Convert Markdown headers
    html = html.replace(
      /^### (.*$)/gim,
      '<h4 class="slds-text-heading_small slds-m-bottom_xx-small"><strong>$1</strong></h4>'
    );
    html = html.replace(
      /^## (.*$)/gim,
      '<h3 class="slds-text-heading_medium slds-m-bottom_x-small"><strong>$1</strong></h3>'
    );

    // Bold & Italics
    html = html.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>');
    html = html.replace(/\*(.*?)\*/g, '<em>$1</em>');

    // Inline code
    html = html.replace(/`([^`]+)`/g, '<code class="chat-code">$1</code>');

    // Simple markdown table parser
    if (html.includes('|')) {
      const lines = html.split('\n');
      let inTable = false;
      let tableHtml =
        '<table class="slds-table slds-table_cell-buffer slds-table_bordered slds-m-vertical_x-small"><tbody>';
      let newLines = [];

      for (let i = 0; i < lines.length; i++) {
        let line = lines[i].trim();
        if (line.startsWith('|') && line.endsWith('|')) {
          if (line.includes('---')) {
            continue; // Header delimiter
          }
          if (!inTable) {
            inTable = true;
          }
          const cells = line.split('|').filter((_, idx, arr) => idx > 0 && idx < arr.length - 1);
          tableHtml += '<tr>';
          cells.forEach((cell) => {
            tableHtml += `<td class="slds-p-around_xx-small">${cell.trim()}</td>`;
          });
          tableHtml += '</tr>';
        } else {
          if (inTable) {
            tableHtml += '</tbody></table>';
            newLines.push(tableHtml);
            inTable = false;
            tableHtml =
              '<table class="slds-table slds-table_cell-buffer slds-table_bordered slds-m-vertical_x-small"><tbody>';
          }
          newLines.push(line);
        }
      }
      if (inTable) {
        tableHtml += '</tbody></table>';
        newLines.push(tableHtml);
      }
      html = newLines.join('\n');
    }

    // Paragraph line breaks
    html = html.replace(/\n\n+/g, '</p><p>');
    html = html.replace(/\n/g, '<br/>');

    return `<div class="chat-markdown"><p>${html}</p></div>`;
  }
}
