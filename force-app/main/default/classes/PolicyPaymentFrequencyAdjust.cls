public class PolicyPaymentFrequencyAdjust {
    
    
    // Define an Invocable method
    @InvocableMethod(label='INS Update Billing Frequency' description='Updates billing frequency and processes true-up amounts for policies.')
    
    
    public static list<string> updateFrequency(list<string> updateRequests) {
        //sample (PaymentChangeRequest:[message=Quarterly, policyId=0YTHr000000pd90OAA, trueUpAmount=116.67], PaymentChangeRequest:[message=Quarterly, policyId=0YTHr000000peHBOAY, trueUpAmount=0.00])
        
        list<string> responses = new List<string>();
        string jsonRequests = updateRequests[0];
        list<InsurancePolicy> listIP = new list<InsurancePolicy>();
        map<string,PaymentChangeRequest> policyidToPaymentChangeRequest = new map<string,PaymentChangeRequest>();
        list<Response> listresponse = new list<Response>();
        
        // Parse the JSON data
        list<PaymentChangeRequest>  listPCR = (List<PaymentChangeRequest>) JSON.deserialize(jsonRequests, list<PaymentChangeRequest>.class);
        For(PaymentChangeRequest pcr : listPCR){
            policyidToPaymentChangeRequest.put(pcr.policyId,pcr);
            listIP.add(New InsurancePolicy(id = pcr.policyId, PremiumFrequency = pcr.message));     
        }
        system.debug(listPCR);   
        
        Database.SaveResult[] results = Database.update(listIP, false);
        // iterate over the list of returned results
        for(Database.SaveResult result : results) {
            if(result.isSuccess()) {
                system.debug('Successfully inserted Accounts : ' + result.getId());
                PaymentChangeRequest  thisPCR = policyidToPaymentChangeRequest.get(result.getId());
                Response r = new  Response();
                r.policyId = result.getId();
                r.message =  'This Policy was sucessfully updated to ' + thisPCR.message + ' ';
                If(thisPCR.trueUpAmount <> NULL || thisPCR.trueUpAmount <> 0){
                    r.message += 'The true up amount of $' + thisPCR.trueUpAmount + ' is due in the next 10 days';
                }
                listresponse.add(r);
                    
                
            } else {
                PaymentChangeRequest  thisPCR = policyidToPaymentChangeRequest.get(result.getId());
                Response r = new  Response();
                r.policyId = result.getId();
                r.message =  'Uh oh, something went horribly wrong while trying to change your billing frequency. 🚨\n' +
                    'But fear not! A battalion of highly-trained technicians (armed with coffee and a sense of duty) have been paged, ' +
                    'and they are on the case! 🛠️\nRest assured, they are working tirelessly to get things sorted, and we’ll be reaching out soon ' +
                    'to help you finalize your billing frequency change. 📞 Stay tuned!';
                // iterate over the failed ones
                for(Database.Error error : result.getErrors()) {
                    System.debug('Error Status : ' + error.getStatusCode() + ' : ' + 'Error Fields : ' + error.getFields());
                }
               
            }
        }
        // Handle the true-up amount, if any (you can modify this logic based on how true-up amounts are processed)
        
        //System.debug('Message: ' + message);
        responses.add(JSON.Serialize(listresponse));
        
        return responses;
    }
    
    public class Response {
        @InvocableVariable
        public String policyId;
        @InvocableVariable
        public String message;
    }
    
    
    // Input class for each policy
    public class PaymentChangeRequest {
        @InvocableVariable
        public String policyId;
        @InvocableVariable
        public Decimal trueUpAmount;
        @InvocableVariable
        public String message;
    }
    
    
}