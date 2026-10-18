/**
 * @description Controller for the in-Salesforce Conversational AI Chat widget (shopifyForecastChat).
 * @group Shopify AI Forecast Bridge
 */
public with sharing class ShopifyAIChatController {

    /**
     * @description Processes a conversational query and returns grounded inventory insights.
     */
    @AuraEnabled
    public static ShopifyAIChatService.ChatMessageDTO sendChatMessage(String userMessage) {
        return ShopifyAIChatService.processUserQuery(userMessage);
    }

    /**
     * @description Provides preset prompt chips for fast 1-click exploration.
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getSuggestedPrompts() {
        return new List<String>{
            'Which products will run out before Black Friday?',
            'What is our overall inventory health?',
            'Summarize stockouts by supplier',
            'Forecast for SKU-AIR-01'
        };
    }
}
