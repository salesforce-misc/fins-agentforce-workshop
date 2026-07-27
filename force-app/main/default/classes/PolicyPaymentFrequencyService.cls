public with sharing class PolicyPaymentFrequencyService {
    
    // Define the input class for the invocable method
    public class PaymentChangeRequest {
        @InvocableVariable(required=true)
        public String policyId;  // Policy ID
        @InvocableVariable(required=true)
        public String newFrequency;  // Desired payment frequency (Annual, Semi-Annual, Quarterly, Monthly, Semi-Monthly)
        @InvocableVariable(required=true)
        public Date requestDate;  // Date of the request
    }
    
    // Define the output class for each policy
    public class PaymentChangeResponse {
        @InvocableVariable
        public String policyId;
        @InvocableVariable
        public Date paymentDueDate;
        @InvocableVariable
        public Decimal trueUpAmount;
        @InvocableVariable
        public String message;
    }
    
    
    @InvocableMethod(label='Aux Method PMT Frequency & Due Dates & True Up amounts ')
    public static List<PaymentChangeResponse> updatePaymentFrequency(List<List<PaymentChangeRequest>> requests) {
        // Get the first list from the List<List<PaymentChangeRequest>> input
        List<PaymentChangeRequest> paymentChangeRequests = requests.size() > 0 ? requests[0] : new List<PaymentChangeRequest>();
        
        // List to hold results
        List<PaymentChangeResponse> responses = new List<PaymentChangeResponse>();
        
        if (paymentChangeRequests.isEmpty()) {
            return responses;
        }
        
        // Map to hold policyId to newFrequency and requestDate
        Map<String, String> policyIdToNewFrequency = new Map<String, String>();
        Map<String, Date> policyIdToRequestDate = new Map<String, Date>();
        
        for (PaymentChangeRequest pcr : paymentChangeRequests) {
            policyIdToNewFrequency.put(pcr.policyId, pcr.newFrequency);
            policyIdToRequestDate.put(pcr.policyId, pcr.requestDate);
        }
        
        // Query the policy data based on policyId in the map
        List<InsurancePolicy> policies = [
            SELECT Id, EffectiveDate, PaidToDate,ExpirationDate, PremiumAmount, PremiumFrequency, GrossWrittenPremium, StandardFeeAmount, StandardTaxAmount, TaxesSurcharges
            FROM InsurancePolicy
            WHERE Id IN :policyIdToNewFrequency.keySet()
        ];
        
        // Process each policy and calculate the new payment details
        for (InsurancePolicy policy : policies) {
            String newFrequency = policyIdToNewFrequency.get(policy.Id);
            Date requestDate = policyIdToRequestDate.get(policy.Id);
            
            // Create a response object
            PaymentChangeResponse response = new PaymentChangeResponse();
            response.policyId = policy.Id;
            
            // Calculate payment due date based on new frequency and request date
            response = calculatePaymentDueDatesForPolicies(policy, newFrequency, requestDate, response);
            System.debug('Line 64. ' + response);
            
            
            // Set message for annual frequency
            String message = '';
            if (newFrequency == 'Annual') {
                message = 'You cannot select annual payments for a policy already in effect';
                response.message = message;
                
            }
            
            
            // Calculate true-up amount
            // Decimal trueUpAmount = calculateTrueUpAmount(policy, paymentDueDate);
            // response.trueUpAmount = trueUpAmount;
           System.debug('Line 79. ' + response);
            responses.add(response);
        }
        
        return responses;
    }
    
    //////////////
    
    ///////////////
    
    // Method to calculate payment due date based on frequency and request date
    // Method to calculate payment due date based on frequency and request date
    public static PaymentChangeResponse calculatePaymentDueDatesForPolicies(InsurancePolicy policy, String newFrequency, Date requestDate, PaymentChangeResponse response) {
        Datetime effectiveDate = policy.EffectiveDate;
        Date paidToDate = policy.PaidToDate;
        Date paymentDueDate;
        Datetime policyEndDate = policy.ExpirationDate; 
         System.debug(paymentDueDate + '   '  +  paidToDate + '   ' + effectiveDate + '     '+ newFrequency);
        if (newFrequency == 'Monthly') {
            // Monthly payment logic
            if (paidToDate <= requestDate) {
                Date nextMonth = paidToDate.addMonths(1);
                paymentDueDate = Date.newInstance(nextMonth.year(), nextMonth.month(), 15);
            } else {
                // Fallback logic to ensure paymentDueDate is set
                paymentDueDate = paidToDate.addMonths(1);  // Default to 1 month after paid date if no clear due date
            }
            response.paymentDueDate = paymentDueDate;
            response.message = 'Your payment frequency can be updated to Monthly. Please check the true-up amount.';
            
        } else if (newFrequency == 'Quarterly') {
            // Check if there are at least 3 months left
            if (requestDate.addMonths(3) > policyEndDate) {
                system.debug( 'Monthly  111');
                response.message = 'Your policy does not have enough time left to switch to Quarterly payments. You need at least 3 months remaining.';
                return response;
                
                
            } else {
                 system.debug( 'Monthly  114');

                Integer monthsFromStart = Math.mod(requestDate.month() - effectiveDate.month(), 3);
                Datetime nextQuarterDate = effectiveDate.addMonths(monthsFromStart).addMonths(3);
                paymentDueDate = Date.newInstance(nextQuarterDate.year(), nextQuarterDate.month(), 15);
            }
            response.paymentDueDate = paymentDueDate;
            response.message = 'Your payment frequency has been updated to Quarterly. Please check the true-up amount.';
            
        } else if (newFrequency == 'Semi-Annual') {
            // Check if there are at least 6 months left
            if (requestDate.addMonths(6) > policyEndDate) {
                response.message = 'Your policy does not have enough time left to switch to Semi-Annual payments. You need at least 6 months remaining.';
                return response;
            } else {
                Integer monthsFromStart = Math.mod(requestDate.month() - effectiveDate.month(), 6);
                Datetime nextSemiAnnualDate = effectiveDate.addMonths(monthsFromStart).addMonths(6);
                paymentDueDate = Date.newInstance(nextSemiAnnualDate.year(), nextSemiAnnualDate.month(), 15);
            }
            response.paymentDueDate = paymentDueDate;
            response.message = 'Your payment frequency has been updated to Semi-Annual. Please check the true-up amount.';
            
        } else if (newFrequency == 'Semi-Monthly') {
            // Semi-Monthly logic
            if (requestDate.day() <= 2) {
                paymentDueDate = Date.newInstance(requestDate.year(), requestDate.month(), 5); // 1st payment grace period
            } else {
                paymentDueDate = Date.newInstance(requestDate.year(), requestDate.month(), 18); // 15th payment grace period
            }
            response.paymentDueDate = paymentDueDate;
            response.message = 'Your payment frequency has been updated to Semi-Monthly.';
            
        } else {
            // Unsupported frequency or invalid transition
            response.message = 'Sorry, the requested payment frequency is not supported or invalid.';
        }
        
        // Ensure the true-up amount calculation is done only if a paymentDueDate was calculated
        if (paymentDueDate != null) {
            response.trueUpAmount = calculateTrueUpAmount(policy, paymentDueDate);
        } else {
            response.trueUpAmount = 0;  // Default to 0 if no due date was calculated
        }
        
        return response;
    }
    
    
    // Method to calculate true-up amount
    public static Decimal calculateTrueUpAmount(InsurancePolicy policy, date paymentDueDate) {
        Decimal totalPolicyCost = policy.GrossWrittenPremium + policy.StandardFeeAmount + policy.StandardTaxAmount + policy.TaxesSurcharges;
        Decimal trueUpAmount = 0;
        
        if (policy.PaidToDate < paymentDueDate) {
            Integer monthsDifference = Math.abs(paymentDueDate.month() - policy.PaidToDate.month());
            trueUpAmount = ((totalPolicyCost / 12) * monthsDifference).setScale(2, RoundingMode.HALF_UP);
        }
        return trueUpAmount;
    }
    
    
    
    public static void runQuickTest() {
        List<PaymentChangeRequest> testRequests = new List<PaymentChangeRequest>();
        
        PaymentChangeRequest request1 = new PaymentChangeRequest();
        request1.policyId = '0YTHu000000M8vnOAC';
        request1.newFrequency = 'Quarterly';
        request1.requestDate = Date.today();
        testRequests.add(request1);
        
        PaymentChangeRequest request2 = new PaymentChangeRequest();
        request2.policyId = '0YTHu000000M8voOAC';
        request2.newFrequency = 'Semi-Monthly';
        request2.requestDate = Date.today();
        testRequests.add(request2);
        
        List<List<PaymentChangeRequest>> inputRequests = new List<List<PaymentChangeRequest>>();
        inputRequests.add(testRequests);
        
        List<PaymentChangeResponse> responses = updatePaymentFrequency(inputRequests);
        
        for (PaymentChangeResponse response : responses) {
            System.debug('Policy ID: ' + response.policyId);
            System.debug('Payment Due Date: ' + response.paymentDueDate);
            System.debug('True-Up Amount: ' + response.trueUpAmount);
            System.debug('Message: ' + response.message);
        }
    }
}