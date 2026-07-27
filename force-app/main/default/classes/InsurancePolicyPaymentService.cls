public with sharing class InsurancePolicyPaymentService {
    
    // Inner class to represent a payment
    public class PaymentDetail {
        @InvocableVariable public String name;
        @InvocableVariable public Decimal fee;
        @InvocableVariable public String institution;
        @InvocableVariable public String insurancePolicyId;
        @InvocableVariable public String owner;
        @InvocableVariable public Decimal paymentAmount;
        @InvocableVariable public Date paymentDate;
        @InvocableVariable public String paymentMethod;
        @InvocableVariable public String paymentStatus;
        @InvocableVariable public String payor;
        @InvocableVariable public Decimal totalPayment;
    }
    
    // Inner class to represent the response for each Insurance Policy
    public class PolicyDetail {
        @InvocableVariable public String policyId;
        @InvocableVariable public String policyName;
        @InvocableVariable public List<PaymentDetail> payments;
    }
    
    // Invocable method to expose this service to flows
    @InvocableMethod(label='Get Insurance Policy Payments' description='Returns payment details for given insurance policies')
    public static List<String> getInsurancePolicyPayments(List<List<String>> listOfPolicyIds) {
        
        // Get the first list from the List<List<String>> input
        List<String> policyIds = listOfPolicyIds.size() > 0 ? listOfPolicyIds[0] : new List<String>();
        
        // List to hold results
        List<PolicyDetail> policyDetails = new List<PolicyDetail>();
        
        if (policyIds.isEmpty()) {
            return new List<String>{ '[]' }; // Return an empty JSON array if no policy IDs provided
        }
        
        // Query InsurancePolicyPayment__c related to Insurance_Policy__c
        List<Insurance_Policy_Payment__c> payments = [
            SELECT Insurance_Policy__c, Name, Fee__c, Institution__c, CreatedById, LastModifiedById, OwnerId,
                   Payment_Amount__c, Payment_Date__c, Payment_Method__c, Payment_Status__c, Payor__c, Total_Payment__c
            FROM Insurance_Policy_Payment__c 
            WHERE Insurance_Policy__c IN :policyIds
        ];
        
        // Map to group payments by policyId
        Map<Id, List<Insurance_Policy_Payment__c>> paymentsByPolicy = new Map<Id, List<Insurance_Policy_Payment__c>>();
        
        // Organize payments by policy
        for (Insurance_Policy_Payment__c payment : payments) {
            if (!paymentsByPolicy.containsKey(payment.Insurance_Policy__c)) {
                paymentsByPolicy.put(payment.Insurance_Policy__c, new List<Insurance_Policy_Payment__c>());
            }
            paymentsByPolicy.get(payment.Insurance_Policy__c).add(payment);
        }
        
        // Query InsurancePolicy for details
        List<InsurancePolicy> policies = [SELECT Id, Name FROM InsurancePolicy WHERE Id IN :policyIds];
        
        // Construct the response
        for (InsurancePolicy policy : policies) {
            PolicyDetail policyDetail = new PolicyDetail();
            policyDetail.policyId = policy.Id;
            policyDetail.policyName = policy.Name;
            policyDetail.payments = new List<PaymentDetail>();
            
            if (paymentsByPolicy.containsKey(policy.Id)) {
                for (Insurance_Policy_Payment__c payment : paymentsByPolicy.get(policy.Id)) {
                    PaymentDetail paymentDetail = new PaymentDetail();
                    paymentDetail.name = payment.Name;
                    paymentDetail.fee = payment.Fee__c;
                    paymentDetail.institution = payment.Institution__c;
                    paymentDetail.insurancePolicyId = payment.Insurance_Policy__c;
                    paymentDetail.owner = payment.OwnerId;
                    paymentDetail.paymentAmount = payment.Payment_Amount__c;
                    paymentDetail.paymentDate = payment.Payment_Date__c;
                    paymentDetail.paymentMethod = payment.Payment_Method__c;
                    paymentDetail.paymentStatus = payment.Payment_Status__c;
                    paymentDetail.payor = payment.Payor__c;
                    paymentDetail.totalPayment = payment.Total_Payment__c;
                    
                    policyDetail.payments.add(paymentDetail);
                }
            }
            
            policyDetails.add(policyDetail);
        }
        
        // Convert the result to JSON string and return to flow
        List<String> jsonResponse = new List<String>();
        jsonResponse.add(JSON.serialize(policyDetails));
        System.debug(jsonResponse);
        return jsonResponse;
    }
}


//InvocableGetInsurancePolicyPayments