public with sharing class PolicyPaymentFrequencyProcessor {
    
    // Decorator for an invocable method  the Label is the name that  we will serach for when creating our action
    @InvocableMethod(label='INS Process Payment Frequency Update from JSON String')
    
    //Our action is going to take in a list of String. Invocable methose always recieve a list  to satidfy a bulk pattern but when
    //Used by and action we are only going to have one string in our list ie the value in  List[0]
    //Our  REasoning engine based on user utterances will need to get us the JSON fromat we are looking for.
    public static List<string> processPaymentFrequencyUpdate(List<String> jsonStringList) {
        
        String inputString = jsonStringList.size() > 0 ? jsonStringList[0] : '';
        System.debug(inputString);
        
        //JSON we are hoping gets passsed in or similar
        //Gives [{"policyId": "0YTHu000000M8vnOAC","newFrequency": "Quarterly","requestDate": "2024-10-07"},{"policyId": "0YTHu000000M8voOAC","newFrequency": "Quarterly","requestDate": "2024-10-07"}]
        
        
        // Remove any newline or control characters that might get passed to prevent JSON parsing errors
        inputString = inputString.normalizeSpace();
        inputString = inputString.replaceAll('\n', '');
        inputString = inputString.replaceAll('"\\[', '\\[').replaceAll('\\]"', '\\]');
        
        List<PolicyPaymentFrequencyService.PaymentChangeRequest> paymentChangeRequests =(list<PolicyPaymentFrequencyService.PaymentChangeRequest>)JSON.deserialize(inputString, list<PolicyPaymentFrequencyService.PaymentChangeRequest>.class);
        
        List<List<PolicyPaymentFrequencyService.PaymentChangeRequest>> inputRequests = new List<List<PolicyPaymentFrequencyService.PaymentChangeRequest>>();
        inputRequests.add(paymentChangeRequests);
        List<PolicyPaymentFrequencyService.PaymentChangeResponse> listPCR =   PolicyPaymentFrequencyService.updatePaymentFrequency(inputRequests);
        String  repsonse = JSON.serialize(listPCR);
        
        return new list<string>{repsonse};
            }
    
    
    // Method to convert the JSON input to match the expected format
    public static String convertJsonString(String jsonString) {
        // Remove any newline or control characters to prevent JSON parsing errors
        String normalizedString = jsonString.normalizeSpace();
        normalizedString = jsonString.replaceAll('\n', '');
        normalizedString = jsonString.replaceAll('"\\[', '\\[').replaceAll('\\]"', '\\]');
        
        
        // Deserialize the original JSON to a Map
        Map<String, Object> inputMap = (Map<String, Object>) JSON.deserializeUntyped(normalizedString);
        String jsonStringList = (String) inputMap.get('jsonStringList');
        
        // Deserialize jsonStringList to make modifications
        jsonStringList = jsonStringList.replaceAll('\\"', '"');  // Replace escaped quotes with actual quotes
        List<Map<String, Object>> requestList = (List<Map<String, Object>>) JSON.deserializeUntyped(jsonStringList);
        
        // Modify fields as per the requirement
        for (Map<String, Object> request : requestList) {
            if (request.containsKey('newFrequency')) {
                request.put('newFrequency', request.get('newFrequency').toString().toLowerCase());
            }
            if (request.containsKey('requestDate')) {
                // NOTE HARD CODING A DATE DUE TO WORKSHOP NATURE OF CODE
                request.put('requestDate', '2024-10-09');
            }
        }
        
        // Serialize the modified list back to a JSON string
        String updatedJsonStringList = JSON.serialize(requestList);
        inputMap.put('jsonStringList', updatedJsonStringList);
        
        // Serialize the entire input map back to a JSON string
        return JSON.serialize(inputMap);
    }
}