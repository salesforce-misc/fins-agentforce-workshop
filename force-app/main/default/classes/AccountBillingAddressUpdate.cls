public class AccountBillingAddressUpdate {
    
    @InvocableMethod(label='FINS - Update Account Address')
    public static List<String> updateAccountAddress(List<Request> requests) {
        List<Account> accountsToUpdate = new List<Account>();
        for (Request request : requests) {
            String accountId = request.accountRecordId;
            String addressString = request.addressString;
            if (String.isBlank(accountId) || String.isBlank(addressString)) {
                continue;
            }
            Account acct = [SELECT Id, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry FROM Account where Id = : accountId LIMIT 1];
            Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(addressString);

            acct.BillingStreet = (string)jsonMap.get('Street');
            acct.BillingCity = (string)jsonMap.get('City');
            acct.BillingState = (string)jsonMap.get('State');
            acct.BillingPostalCode = (string)jsonMap.get('ZipCode');
            acct.BillingCountry = (string)jsonMap.get('Country');

            accountsToUpdate.add(acct);
        }
        if (!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
        }
        
        List<String> results = new List<String>();
        
        results.add('Successfully updated address');
        
        return results;
    }
    
    public class Request {
        @InvocableVariable(label='Account Record ID' required=true)
        public String accountRecordId;
        @InvocableVariable(label='Address JSON' required=true)
        public String addressString;
    }
}